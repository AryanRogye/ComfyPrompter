//
//  CameraModel.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

import SnapCore
import AppKit
import AVFoundation
import CoreImage

@Observable
@MainActor
final class CameraModel {

    let camera = CameraCaptureService()

    let ciContext = CIContext()
    var frame: CGImage?
    var recordingURL: URL?

    var onBoundingBox: ((CGRect, CVPixelBuffer) -> Void)?
    var hasCameraStarted: Bool = false

    @concurrent
    public func startCamera() async throws {
        try await requestPermission()
        guard await camera.isAuthorized() else {
            throw AppModelError.CameraPermissionNotEnabled
        }

        let devices = await camera.searchSessions()
        guard let device = devices.first else {
            throw AppModelError.NoCameraFound
        }

        await camera.setOnDetailedFaceResult { [weak self] faces, buffer, time in
            guard let self else { return }
            let ciImage = CIImage(cvPixelBuffer: buffer)
            let image = self.ciContext.createCGImage(ciImage, from: ciImage.extent)

            guard let face = faces.first else { return }

            Task {
                await self.onBoundingBox?(face.boundingBox, buffer)
            }
            Task { @MainActor in
                self.frame = image
            }
        }

        try await camera.startCameraWithDetailedFaceTracking(
            with: device,
            fps: .sixty,
            cameraPosition: .front,
            optimize: false
        )
        Task { @MainActor in
            hasCameraStarted = true
        }
    }

    public func stopCamera() async {
        await camera.stopCamera()
        hasCameraStarted = false
    }
}

// MARK: - Recording
extension CameraModel {

    public func startRecording() async throws {
        try await startCamera()
        let url = URL.temporaryDirectory.appending(path: "test-\(UUID().uuidString).mov")
        await camera.startRecording(to: url)
        self.recordingURL = url
    }
    public func stopRecording() async throws {
        await camera.stopRecording()
        await camera.stopCamera()
        if let recordingURL {
            NSWorkspace.shared.open(recordingURL)
        }
        self.recordingURL = nil
    }

}

// MARK: - Permissions
extension CameraModel {
    private func requestPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                throw AppModelError.CameraPermissionNotEnabled
            }
        case .denied:
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
            )
            throw AppModelError.CameraPermissionNotEnabled
        case .restricted:
            throw AppModelError.CameraPermissionNotEnabled
        @unknown default:
            throw AppModelError.CameraPermissionNotEnabled
        }

    }
}
