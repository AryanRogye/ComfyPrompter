//
//  ImageHelpers.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

import CoreImage
import AppKit

enum ImageHelpers {

    static let ciContext = CIContext()

    public static func cropPixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        to rect: CGRect
    ) -> CVPixelBuffer? {

        /// Convert Normalized Vision Coordinates to Regular Ones
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let size: CGFloat = 448

        let pixelRect = CGRect(
            x: rect.origin.x * width,
            y: rect.origin.y * height,
            width: rect.width * width,
            height: rect.height * height
        ).integral

        let scale = min(1, size / max(pixelRect.width, pixelRect.height))

        /// Crop The Image
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .cropped(to: pixelRect)

        /// Translate the coordinates to the new cropped image
        let scaled = ciImage
            .transformed(
                by: CGAffineTransform(
                    translationX: -pixelRect.origin.x,
                    y: -pixelRect.origin.y
                )
            )
            .transformed(
                by: CGAffineTransform(
                    scaleX: scale,
                    y: scale
                )
            )


        let x = ((size - scaled.extent.width) / 2).rounded(.down)
        let y = ((size - scaled.extent.height) / 2).rounded(.down)
        let centered = scaled.transformed(by: CGAffineTransform(translationX: x, y: y))

        /// Black square underneath
        let background = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
        let composited = centered.composited(over: background)

        /// Create OutBuffer
        var outBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size), Int(size),
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
            &outBuffer
        )

        guard status == kCVReturnSuccess, let outBuffer else {
            print("CVPixelBufferCreate failed: \(status)")
            return nil
        }

        ciContext.render(composited, to: outBuffer)
        return outBuffer
    }

    public static func writeImageToFile(image buffer: CVPixelBuffer) {

        /// Convert CVPixelBuffer To NSImage
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let image = Self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            print("Cant Convert CVPixelBuffer To CGImage")
            return
        }
        let nsImage = NSImage(cgImage: image, size: .zero)


        let tempDir = FileManager.default.temporaryDirectory
        let folderURL = tempDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = folderURL.appendingPathComponent("\(UUID().uuidString).png")

        guard let tiffData = nsImage.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiffData) else {
            print("Could not process NSImage representation.")
            return
        }

        guard let imageData = bitmap.representation(using: .png, properties: [:]) else {
            print("Could not convert bitmap to JPEG data.")
            return
        }

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try imageData.write(to: fileURL, options: .atomic)
            print("Mac image saved to: \(fileURL.path)")
        } catch {
            print("Error saving Mac image: \(error.localizedDescription)")
        }

        NSWorkspace.shared.open(fileURL)
    }

}
