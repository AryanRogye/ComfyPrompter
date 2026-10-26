//
//  GazeDetection.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

import CoreML
import CoreImage
import Accelerate
import AppKit

enum GazeError: LocalizedError {
    case cantCropImage
    case modelNotLoaded
    case cantGetGazeInfo

    var errorDescription: String? {
        switch self {
        case .cantCropImage:
            "Cant Crop Image"
        case .modelNotLoaded:
            "Model Not Loaded"
        case .cantGetGazeInfo:
            "Cant Get Gaze Info"
        }
    }
}

struct GazeResult {
    let yaw: Double
    let pitch: Double
}

@Observable
@MainActor
final class GazeDetection {

    var model: MLModel?
    

    init() {
    }

    public func loadModel() throws {
        let config = MLModelConfiguration()
        self.model = try MLModel(
            contentsOf: MobileOneS0Gaze.urlOfModelInThisBundle,
            configuration: config
        )
    }

    public func getGaze(from image: CVPixelBuffer, boundingBox: CGRect) throws -> GazeResult {
        guard let model else {
            throw GazeError.modelNotLoaded
        }
        guard let pixelBuffer = ImageHelpers.cropPixelBuffer(image, to: boundingBox) else {
            throw GazeError.cantCropImage
        }

        let input = MobileOneS0GazeInput(face: pixelBuffer)
        let result = try model.prediction(from: input)

        guard
            let yaw = result.featureValue(for: "yaw")?.multiArrayValue?[0].doubleValue,
            let pitch = result.featureValue(for: "pitch")?.multiArrayValue?[0].doubleValue
        else {
            throw GazeError.cantGetGazeInfo
        }

        return .init(yaw: yaw, pitch: pitch)
    }
}
