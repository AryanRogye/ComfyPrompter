//
//  ComfyPrompterView.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/25/26.
//

import SwiftUI

struct ComfyPrompterView: View {

    @Environment(AppModel.self) var appModel
    @State private var isInspectorShown: Bool = false
    @State private var isConfigureShown: Bool = false

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var isModelLoading: Bool = false

    var body: some View {
        NavigationSplitView {

        } detail: {

        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .inspector(isPresented: $isInspectorShown) {
            Button {
                isConfigureShown = true
            } label: {
                Label("Configure", systemImage: "info")
            }
            Spacer()
            Button {
                Task {
                    do  {
                        if appModel.camera.recordingURL == nil {
                            try await appModel.camera.startRecording()
                        } else {
                            try await appModel.camera.stopRecording()
                        }
                    } catch {
                        self.error = error.localizedDescription
                        self.showError = true
                    }
                }
            } label: {
                Text(appModel.camera.recordingURL == nil ? "Start" : "Stop")
            }
        }
        .sheet(isPresented: $isConfigureShown) {
            ConfigureView()
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isModelLoading) {
            ModelLoading()
                .interactiveDismissDisabled()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isInspectorShown.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .task {
            if isModelLoading { return }

            Task {
                isModelLoading = true
                defer { isModelLoading = false }
                do {
                    print("Loading Model")
                    try appModel.gaze.loadModel()
                    print("Done Loading Model")
                } catch {
                    self.error = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

struct ConfigureView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(AppModel.self) var appModel

    @State private var error: String?
    @State private var showError: Bool = false

    var body: some View {
        @Bindable var appModel = appModel
        VStack {
            if let frame = appModel.camera.frame {
                ZStack {
                    Image(decorative: frame, scale: 1.0)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {

            }
            /// camera here
            HStack {
                Button("Flip Camera") {
                    /// TODO
                }

                if appModel.camera.hasCameraStarted {
                    if appModel.isGazeReady {
                        Toggle("Use Gaze", isOn: $appModel.useGazeInfo)
                        Button("Clear Gaze") {
                            appModel.resetGaze()
                        }
                        Button(appModel.isTestingGaze ? "Stop Testing" : "Test Gaze") {
                            appModel.testGaze()
                        }
                    } else {
                        Button("Configure Gaze") {
                            appModel.beginPreloadGaze()
                        }
                    }
                }

                Spacer()

                Button("Done") {
                    Task {
                        await appModel.camera.stopCamera()
                        dismiss()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: 550, maxHeight: 450)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .task {
            do {
                try await appModel.camera.startCamera()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}

#Preview {
    ComfyPrompterView()
}
