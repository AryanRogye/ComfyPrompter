//
//  TestGazeCoordinator.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

import AppKit
import SwiftUI

@MainActor
final class TestGazeCoordinator: PanelCoordinator<TestGazeView> {

    let vm = TestGazeViewModel()

    init() {
        super.init(view: TestGazeView(vm: vm))
    }

    public func show(
        topLeft: EyeInfo,
        topRight: EyeInfo,
        bottomLeft: EyeInfo,
        bottomRight: EyeInfo,
        eyeInfo: EyeInfo
    ) {
        print("TL:", topLeft)
        print("TR:", topRight)
        print("BL:", bottomLeft)
        print("BR:", bottomRight)

        vm.topLeft = topLeft
        vm.topRight = topRight
        vm.bottomLeft = bottomLeft
        vm.bottomRight = bottomRight
        vm.currentEyeInfo = eyeInfo
        vm.screen = screen
        vm.determineGazeSize()
        if panel == nil { setupPanel() }
    }

    public func hide() {
        vm.topLeft = nil
        vm.topRight = nil
        vm.bottomLeft = nil
        vm.bottomRight = nil
        vm.currentEyeInfo = nil
        vm.screen = nil
        panel?.orderOut(nil)
    }
}

@Observable
@MainActor
final class TestGazeViewModel {
    var topLeft: EyeInfo?
    var topRight: EyeInfo?
    var bottomLeft: EyeInfo?
    var bottomRight: EyeInfo?
    var currentEyeInfo: EyeInfo?
    var screen: NSScreen?

    var gazeSide: GazeSide = .none
    private let switchThreshold: Double = 0.03

    public func determineGazeSize() {

        guard let topLeft, let topRight, let bottomLeft, let bottomRight, let currentEyeInfo else { return }

        let corners: [(side: GazeSide, eye: EyeInfo)] = [
            (.topLeft, topLeft),
            (.topRight, topRight),
            (.bottomLeft, bottomLeft),
            (.bottomRight, bottomRight)
        ]

        guard let closest = corners.min(by: {
            distance(currentEyeInfo, $0.eye) <
                distance(currentEyeInfo, $1.eye)
        }) else { return }

        guard closest.side != gazeSide else { return }

        // Find the distance to our currently selected corner
        if let current = corners.first(where: { $0.side == gazeSide }) {
            let currentDistance = distance(currentEyeInfo, current.eye)
            let newDistance = distance(currentEyeInfo, closest.eye)

            // Only switch if the new corner is significantly closer
            guard newDistance + switchThreshold < currentDistance else {
                return
            }
        }

        gazeSide = closest.side
    }

    private func distance(_ a: EyeInfo, _ b: EyeInfo) -> Double {
        let pitchDiff = a.pitch - b.pitch
        let yawDiff = a.yaw - b.yaw

        return sqrt(pitchDiff * pitchDiff + yawDiff * yawDiff)
    }
}

struct TestGazeView: View {

    @Bindable var vm: TestGazeViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)

            if let topLeft = vm.topLeft, let topRight = vm.topRight,
               let bottomLeft = vm.bottomLeft, let bottomRight = vm.bottomRight,
               let currentEyeInfo = vm.currentEyeInfo {

                VStack {
                    HStack {
                        Rectangle()
                            .fill(vm.gazeSide == .topLeft ? .green.opacity(0.5) : .clear)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Rectangle()
                            .fill(vm.gazeSide == .topRight ? .green.opacity(0.5) : .clear)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    HStack {
                        Rectangle()
                            .fill(vm.gazeSide == .bottomLeft ? .green.opacity(0.5) : .clear)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Rectangle()
                            .fill(vm.gazeSide == .bottomRight ? .green.opacity(0.5) : .clear)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                VStack {
                    HStack {
                        eyeInfo(topLeft, alignment: .leading)
                        Spacer()
                        eyeInfo(topRight, alignment: .trailing)
                    }
                    Spacer()
                    HStack {
                        eyeInfo(bottomLeft, alignment: .leading)
                        Spacer()
                        eyeInfo(bottomRight, alignment: .trailing)
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding()

                VStack {
                    Spacer()
                    eyeInfo(currentEyeInfo, alignment: .center)
                    Spacer()
                }
                .font(.headline)
                .foregroundStyle(.white)
            }
        }
    }

    private func eyeInfo(_ eyeInfo: EyeInfo, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment) {
            Text("Pitch: \(eyeInfo.pitch)")
            Text("Yaw: \(eyeInfo.yaw)")
        }
    }
}
