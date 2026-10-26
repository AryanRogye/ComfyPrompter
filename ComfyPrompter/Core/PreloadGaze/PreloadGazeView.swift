//
//  PreloadGazeView.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

import SwiftUI

@Observable
@MainActor
class PreloadGazeViewModel {
    var gazeTestBegin: Bool = false
    var gazeSide: GazeSide = .none

    public func beginGazeTest() {
        gazeTestBegin = true
        gazeSide = .none
        gazeSide.next()
    }
}

private enum GazePhase {
    case showStartingPrompt
    case showInstructions
    case showDemo
    case begin
    case done
}

struct PreloadGazeView: View {

    @Bindable var vm: PreloadGazeViewModel

    @State private var phase: GazePhase = .showStartingPrompt

    @State private var instructionsTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)

            VStack {
                HStack {
                    Circle()
                        .fill(vm.gazeSide == .topLeft ? .green : .gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Spacer()
                    Circle()
                        .fill(vm.gazeSide == .topRight ? .green : .gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                }
                Spacer()
                HStack {
                    Circle()
                        .fill(vm.gazeSide == .bottomLeft ? .green : .gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Spacer()
                    Circle()
                        .fill(vm.gazeSide == .bottomRight ? .green : .gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                }
            }

            PreloadGazeInstructions(
                phase: phase,
                gazeSide: vm.gazeSide,
                onRedoInstructions: {
                    startInstructions()
                },
                onStart: {
                    startGettingGaze()
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task {
            startInstructions()
        }
    }

    public func startGettingGaze() {
        phase = .done
        vm.beginGazeTest()
    }

    public func startInstructions() {
        instructionsTask?.cancel()
        instructionsTask = Task {
            /// Start With Instructions
            phase = .showStartingPrompt
            try? await Task.sleep(for: .seconds(2))

            phase = .showInstructions

            /// Then Demo
            try? await Task.sleep(for: .seconds(4))
            if Task.isCancelled { return }
            withAnimation(.spring) {
                phase = .showDemo
            }

            vm.gazeSide.next()
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            vm.gazeSide.next()
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            vm.gazeSide.next()
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            vm.gazeSide.next()
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            vm.gazeSide.next()

            /// Then We Begin
            phase = .begin
        }
    }
}

private struct PreloadGazeInstructions: View {

    let phase: GazePhase
    let gazeSide: GazeSide
    let onRedoInstructions: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack {
            switch phase {
            case .showStartingPrompt:
                Text("Lets Begin By Seeing How Your Eyes Look")
                    .font(
                        .system(
                            size: 50,
                            weight: .bold
                        )
                    )
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal)
            case .showInstructions:
                Text("You Will Look At Each Corner Of Your Screen And When Your Ready You Will Press The Space Button, Once You Have All Four, Your Good To Go!!")
                    .font(
                        .system(
                            size: 50,
                            weight: .bold
                        )
                    )
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal)
            case .showDemo:
                ZStack {
                    VStack {
                        HStack {
                            Circle()
                                .fill(gazeSide == .topLeft ? .green : .gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                            Spacer()
                            Circle()
                                .fill(gazeSide == .topRight ? .green : .gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                        }
                        Spacer()
                        HStack {
                            Circle()
                                .fill(gazeSide == .bottomLeft ? .green : .gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                            Spacer()
                            Circle()
                                .fill(gazeSide == .bottomRight ? .green : .gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                        }
                    }
                }
            case .begin:
                VStack(spacing: 28) {
                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 85, weight: .light))
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 12) {
                        Text("You're All Set!")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Your eye calibration is ready.\nYou can now start tracking your gaze.")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 16) {

                        Button(action: onRedoInstructions) {
                            Label("Redo Instructions", systemImage: "arrow.counterclockwise")
                                .frame(width: 190, height: 48)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)

                        Button(action: onStart) {
                            Label("Start Tracking", systemImage: "arrow.right")
                                .fontWeight(.semibold)
                                .frame(width: 190, height: 48)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .background(.green, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                        .keyboardShortcut(.defaultAction)

                    }
                    .font(.system(size: 16))

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .done:
                EmptyView()
            }
        }
    }
}
