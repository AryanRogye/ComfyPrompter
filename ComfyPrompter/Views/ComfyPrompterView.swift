import SwiftUI

struct ComfyPrompterView: View {
    @State private var isConfigureShown = false

    var body: some View {
        SpeechPrompterView()
            .sheet(isPresented: $isConfigureShown) { ConfigureView() }
            .toolbar {
                Button("Configure", systemImage: "slider.horizontal.3") {
                    isConfigureShown = true
                }
            }
    }
}

struct ConfigureView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("prompterCueDelayV2") private var cueDelay = 0.0
    @AppStorage("prompterMoveDurationV2") private var moveDuration = 0.08

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Passage timing") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Cue delay")
                        Spacer()
                        Text("\(cueDelay, specifier: "%.2f") s").monospacedDigit()
                    }
                    Slider(value: $cueDelay, in: 0...3, step: 0.05)
                        .accessibilityLabel("Cue delay in seconds")
                    HStack {
                        Text("Movement duration")
                        Spacer()
                        Text("\(moveDuration, specifier: "%.2f") s").monospacedDigit()
                    }
                    Slider(value: $moveDuration, in: 0...1.5, step: 0.02)
                        .accessibilityLabel("Movement duration in seconds")
                    Text("Lower values move faster. Speech controls passage progress; cue delay gives you time to look toward the next position.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

#Preview { ComfyPrompterView() }
