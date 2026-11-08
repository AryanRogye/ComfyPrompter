import AVFoundation
import Observation

/// Records rehearsal video and microphone audio.
@MainActor @Observable
final class RehearsalRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    var recording = false
    var savedURL: URL?
    private let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private var completion: CheckedContinuation<URL, Error>?

    func start() async throws {
        guard !recording else { return }
        guard await AVCaptureDevice.requestAccess(for: .video),
              await AVCaptureDevice.requestAccess(for: .audio) else {
            throw NSError(domain: "Recording", code: 1, userInfo: [NSLocalizedDescriptionKey: "Allow camera and microphone access in System Settings."])
        }
        session.beginConfiguration()
        session.sessionPreset = .high
        for input in session.inputs { session.removeInput(input) }
        for existing in session.outputs { session.removeOutput(existing) }
        do {
            for media in [AVMediaType.video, .audio] {
                guard let device = AVCaptureDevice.default(for: media) else {
                    throw NSError(domain: "Recording", code: 2, userInfo: [NSLocalizedDescriptionKey: "Camera or microphone is unavailable."])
                }
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { throw NSError(domain: "Recording", code: 3) }
                session.addInput(input)
            }
            guard session.canAddOutput(output) else { throw NSError(domain: "Recording", code: 4) }
            session.addOutput(output)
            session.commitConfiguration()
        } catch { session.commitConfiguration(); throw error }
        session.startRunning()
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appending(path: "ComfyPrompter/Recordings")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "Rehearsal-\(UUID().uuidString).mov")
        output.startRecording(to: url, recordingDelegate: self)
        recording = true; savedURL = nil
    }

    func finish() async throws -> URL? {
        guard recording else { return savedURL }
        return try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            output.stopRecording()
        }
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        let succeeded = error == nil || (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
        Task { @MainActor in
            self.session.stopRunning(); self.recording = false
            if succeeded { self.savedURL = url; self.completion?.resume(returning: url) }
            else { self.completion?.resume(throwing: error!) }
            self.completion = nil
        }
    }
}
