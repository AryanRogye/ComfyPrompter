//
//  AppModel.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/25/26.
//

import Foundation
import SnapCore
import CoreImage

enum AppModelError: LocalizedError {
    case CameraPermissionNotEnabled
    case NoCameraFound

    var errorDescription: String? {
        switch self {
        case .CameraPermissionNotEnabled:
            "Camera Permission Not Enabled"
        case .NoCameraFound:
            "No Camera Found"
        }
    }
}

import AVFoundation
import AppKit

struct EyeInfo: Codable {
    let pitch: Double
    let yaw: Double
}
@Observable
@MainActor
final class AppModel {
    let camera = CameraModel()
    let gaze = GazeDetection()

    var lastBoundingBox: CGRect?
    var lastBuffer: CVPixelBuffer?

    var onBeginPreloadGaze: (() -> Void)?
    var onTestingGaze: ((Bool, EyeInfo?) -> Void)?
    var useGazeInfo: Bool = false
    var isTestingGaze: Bool = false

    var topLeft: EyeInfo?
    var topRight: EyeInfo?
    var bottomLeft: EyeInfo?
    var bottomRight: EyeInfo?


    var isGazeReady: Bool {
        return topLeft != nil &&
        topRight != nil &&
        bottomLeft != nil &&
        bottomRight != nil
    }

    init() {
        loadFromDefaults()
        camera.onBoundingBox = { [weak self] boundingBox, buffer in
            guard let self else { return }
            self.lastBoundingBox = boundingBox
            self.lastBuffer = buffer

            if isTestingGaze {
                if let result = try? gaze.getGaze(from: buffer, boundingBox: boundingBox) {
                    onTestingGaze?(true, .init(pitch: result.pitch, yaw: result.yaw))
                }
            } else {
                onTestingGaze?(false, nil)
            }
        }
    }

    public func beginPreloadGaze() {
        onBeginPreloadGaze?()
    }

    public func resetGaze() {
        UserDefaults.standard.removeObject(forKey: "top-left")
        UserDefaults.standard.removeObject(forKey: "top-right")
        UserDefaults.standard.removeObject(forKey: "bottom-left")
        UserDefaults.standard.removeObject(forKey: "bottom-right")
    }

    public func testGaze() {
        isTestingGaze.toggle()
        onTestingGaze?(isTestingGaze, nil)
    }

    public func storeGaze(_ gazeSide: GazeSide) {
        guard let lastBuffer else { return }
        guard let lastBoundingBox else { return }
        do {
            let result = try gaze.getGaze(from: lastBuffer, boundingBox: lastBoundingBox)
            switch gazeSide {
            case .none:
                break
            case .topLeft:
                topLeft = .init(pitch: result.pitch, yaw: result.yaw)
            case .topRight:
                topRight = .init(pitch: result.pitch, yaw: result.yaw)
            case .bottomLeft:
                bottomLeft = .init(pitch: result.pitch, yaw: result.yaw)
            case .bottomRight:
                bottomRight = .init(pitch: result.pitch, yaw: result.yaw)
            }
        } catch {
            print("Error Getting Gaze: \(error.localizedDescription)")
        }

        if let topLeft, let topRight, let bottomLeft, let bottomRight {
            storeIntoDefaults(topLeft, topRight, bottomLeft, bottomRight)
        }
    }

    private func storeIntoDefaults(
        _ topLeft: EyeInfo,
        _ topRight: EyeInfo,
        _ bottomLeft: EyeInfo,
        _ bottomRight: EyeInfo
    ) {
        storeIntoDefaults(topLeft, forKey: "top-left")
        storeIntoDefaults(topRight, forKey: "top-right")
        storeIntoDefaults(bottomLeft, forKey: "bottom-left")
        storeIntoDefaults(bottomRight, forKey: "bottom-right")
    }

    private func loadFromDefaults() {
        topLeft = getFromDefaults(forKey: "top-left")
        topRight = getFromDefaults(forKey: "top-right")
        bottomLeft = getFromDefaults(forKey: "bottom-left")
        bottomRight = getFromDefaults(forKey: "bottom-right")
    }

    private func getFromDefaults(forKey: String) -> EyeInfo? {
        guard let data = UserDefaults.standard.data(forKey: "top-left") else { return nil }
        return try? JSONDecoder().decode(EyeInfo.self, from: data)
    }

    private func storeIntoDefaults(_ eyeInfo: EyeInfo, forKey: String) {
        let data = try? JSONEncoder().encode(eyeInfo)
        UserDefaults.standard.set(data, forKey: forKey)
    }
}
