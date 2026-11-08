import SwiftUI
import Speech
import AVFoundation

@MainActor @Observable
final class SpeechPrompter {
    var script = """
    So, if I were making a movie about a deadly pandemic, I think I'd choose the bubonic plague over the Spanish flu.
    
    And the main reason is just how terrifying the whole situation was, especially considering the time period.
    
    Like, imagine living in the 1300s, and all of a sudden, people around you are getting sick and dying, but nobody really understands what's causing it or how to stop it.
    
    I think that alone would make for a pretty interesting movie.
    
    I'd probably focus on a small village or town and show how the plague slowly affects everyone living there.
    
    At first, maybe it's just a few people getting sick, and nobody thinks much of it. But then more and more people start dying, and suddenly everyone's panicking.
    
    And I think one of the most interesting parts would be showing how people reacted to the disease.
    
    Because back then, people didn't understand bacteria or how diseases spread the way we do today. So you'd have people blaming religion, other people, or just assuming it was some kind of punishment.
    
    I'd also want to show how the plague affected society as a whole. Like, families being separated, businesses shutting down, and people becoming afraid of even interacting with each other.
    
    And obviously, I'd include the plague doctors with those creepy bird masks, although those are more associated with later plague outbreaks.
    
    I think what would make the movie interesting isn't necessarily just the disease itself, but how quickly society can fall apart when people are scared and don't know what's happening.
    
    And that's why I'd choose the bubonic plague. I feel like there's just so much potential for a really intense and emotional story.
    """
    var passages: [String] = []
    var index = 0
    var location = 0
    var cue = false
    var cueLocation = 0
    var running = false
    var status = "Ready"
    var transcript = ""
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var transition: Task<Void, Never>?
    private var hasTap = false
    private var generation = UUID()
    private var matchedEnd = -1
    private var lastMatch = -1
    var current: String { passages.indices.contains(index) ? passages[index] : "" }

    /// Preserve every word while favoring punctuation and short spoken clauses.
    static func splitPassages(_ script: String) -> [String] {
        var result: [String] = []
        var phrase: [String] = []
        for word in script.split(whereSeparator: { $0.isWhitespace }) {
            phrase.append(String(word))
            let punctuation = word.last.map { ",;:.!?".contains($0) } ?? false
            if (punctuation && phrase.count >= 4) || phrase.count >= 8 {
                result.append(phrase.joined(separator: " "))
                phrase.removeAll(keepingCapacity: true)
            }
        }
        if !phrase.isEmpty {
            result.append(phrase.joined(separator: " "))
        }
        return result
    }

    func prepare() {
        stop()
        passages = Self.splitPassages(script)
        index = 0; location = 0; matchedEnd = -1; lastMatch = -1
        status = "Ready"
    }
    func start() async {
        guard !running else { return }
        status = "Requesting microphone access…"
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        guard microphone else {
            status = "Microphone access denied. Enable ComfyPrompter in System Settings → Privacy & Security → Microphone."
            return
        }
        status = "Requesting speech recognition access…"
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard authorization == .authorized else { status = "Enable speech recognition for ComfyPrompter in System Settings → Privacy & Security → Speech Recognition."; return }
        guard recognizer?.isAvailable == true else { status = "Speech recognition is unavailable."; return }
        do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            let token = UUID(); generation = token
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: engine.inputNode.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }
            hasTap = true
            engine.prepare(); try engine.start()
            running = true; status = "Listening"
            recognition = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = result?.isFinal == true
                let message = error?.localizedDescription
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if let text { self.transcript = text; self.match(text) }
                    if finished || message != nil {
                        self.stop()
                        self.status = message ?? "Listening ended. Resume to continue."
                    }
                }
            }
        } catch { stop(); status = error.localizedDescription }
    }
    func stop() {
        generation = UUID(); engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); recognition?.cancel(); recognition = nil; request = nil
        transition?.cancel(); transition = nil; cue = false; running = false
    }
    private func words(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
    private func match(_ text: String) {
        let heard = Array(words(text).suffix(8))
        guard heard.count >= 3 else { return }
        let scriptWords = passages.flatMap { words($0) }
        var best: (end: Int, length: Int)?
        for length in stride(from: min(heard.count, 6), through: 3, by: -1) {
            let suffix = Array(heard.suffix(length))
            guard scriptWords.count >= length else { continue }
            for start in 0...(scriptWords.count - length) where Array(scriptWords[start..<(start + length)]) == suffix {
                let end = start + length
                if best == nil || abs(end - matchedEnd) < abs(best!.end - matchedEnd) { best = (end, length) }
            }
            if best != nil { break }
        }
        guard let best else { status = "Holding your place — return to the script"; return }
        guard best.end != lastMatch else { return }
        lastMatch = best.end; matchedEnd = best.end; status = "Following"
        var count = 0
        for (passage, content) in passages.enumerated() {
            count += words(content).count
            if best.end <= count {
                if passage > index { schedule(passage) }
                else if passage == index && best.end == count && index + 1 < passages.count { schedule(index + 1) }
                else if index == passages.count - 1 && best.end == count { status = "Complete" }
                break
            }
        }
    }
    func advance() { schedule(index + 1) }
    private func schedule(_ target: Int) {
        guard passages.indices.contains(target), transition == nil else { return }
        cueLocation = target % 3
        cue = true
        let storedDelay = UserDefaults.standard.object(forKey: "prompterCueDelayV2") as? Double ?? 0
        let cueDelay = storedDelay.isFinite ? min(max(storedDelay, 0), 3) : 0
        if cueDelay == 0 {
            index = target
            location = cueLocation
        }
        transition = Task { [weak self] in
            if cueDelay > 0 {
                do { try await Task.sleep(for: .seconds(cueDelay)) } catch { return }
                guard let self else { return }
                self.index = target
                self.location = self.cueLocation
            }
            // Keep the cue visible briefly at its destination as the text arrives.
            do { try await Task.sleep(for: .seconds(0.15)) } catch { return }
            guard let self else { return }
            self.cue = false
            self.transition = nil
        }
    }
}

struct SpeechPrompterView: View {
    @AppStorage("prompterMoveDurationV2") private var moveDuration = 0.08
    @State private var model = SpeechPrompter()
    @State private var presenting = false
    @State private var recorder = RehearsalRecorder()
    @State private var busy = false
    @State private var recordingError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Anchor the sequence to the top-center camera: below, above, then left.
    private func readingPosition(_ slot: Int, in size: CGSize) -> CGPoint {
        let center = size.width / 2
        switch slot % 3 {
        case 0: return CGPoint(x: center + min(100, size.width * 0.12), y: min(260, size.height - 80))
        case 1: return CGPoint(x: center, y: 85)
        default: return CGPoint(x: center - min(280, size.width * 0.30), y: 170)
        }
    }
    private func verticalPhrase(_ phrase: String) -> String {
        let words = phrase.split(whereSeparator: { $0.isWhitespace })
        return stride(from: 0, to: words.count, by: 2).map { start in
            words[start..<min(start + 2, words.count)].joined(separator: " ")
        }.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 20) {
            if presenting {
                GeometryReader { geometry in
                    ZStack {
                        Color.black
                        // Keep both phrases mounted at their destination. Promotion
                        // changes emphasis without moving the words being read.
                        ForEach(model.index..<min(model.index + 2, model.passages.count), id: \.self) { phraseIndex in
                            let active = phraseIndex == model.index
                            Text(verticalPhrase(model.passages[phraseIndex]))
                                .accessibilityLabel(model.passages[phraseIndex])
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .font(.system(size: 28, weight: .medium, design: .serif))
                                .foregroundStyle(.white.opacity(active ? 1 : 0.65))
                                .frame(width: min(240, geometry.size.width * 0.28))
                                .position(readingPosition(phraseIndex, in: geometry.size))
                                .animation(reduceMotion ? nil : .easeInOut(duration: moveDuration), value: active)
                        }
                        if model.cue {
                            Circle().fill(.green).frame(width: 18, height: 18)
                                .position(x: readingPosition(model.cueLocation, in: geometry.size).x,
                                          y: readingPosition(model.cueLocation, in: geometry.size).y - 65)
                                .accessibilityLabel("Next passage location")
                        }
                    }
                }
                HStack {
                    Button("Finish & edit") {
                        Task {
                            busy = true
                            model.stop()
                            do { _ = try await recorder.finish(); presenting = false }
                            catch { recordingError = error.localizedDescription }
                            busy = false
                        }
                    }.disabled(busy)
                    if recorder.recording { Label("Recording", systemImage: "record.circle.fill").foregroundStyle(.red) }
                    Text(model.status).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.index + 1) / \(model.passages.count)").monospacedDigit()
                    Button(model.running ? "Pause prompting" : "Start / resume") {
                        if model.running { model.stop(); model.status = "Paused" }
                        else { Task {
                            busy = true
                            await model.start()
                            if model.running && !recorder.recording {
                                do {
                                    try await recorder.start()
                                } catch { model.stop(); recordingError = error.localizedDescription }
                            }
                            busy = false
                        } }
                    }
                    .disabled(busy)
                    Button("Next passage") { model.advance() }.disabled(model.index + 1 >= model.passages.count)
                }.padding(.horizontal)
            } else {
                Text("Speak at your own pace").font(.largeTitle.bold())
                Text("Your script is split into short phrases at punctuation. Two phrases stay visible so you can flow straight into the next.").foregroundStyle(.secondary)
                TextEditor(text: $model.script).font(.title3).padding(12).border(.secondary.opacity(0.2))
                if let url = recorder.savedURL {
                    Button("Show saved recording") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                Button("Begin rehearsal") { model.prepare(); presenting = true }.buttonStyle(.borderedProminent)
                    .disabled(model.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 560)
        .alert("Recording", isPresented: Binding(get: { recordingError != nil }, set: { if !$0 { recordingError = nil } })) {
            Button("OK") { recordingError = nil }
        } message: { Text(recordingError ?? "") }
        .onDisappear {
            model.stop()
            Task { _ = try? await recorder.finish() }
        }
    }
}
