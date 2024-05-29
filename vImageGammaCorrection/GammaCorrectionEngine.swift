//
//  GammaCorrectionEngine.swift
//  vImageGammaCorrection
//
// Adjusting the Brightness and Contrast of an Image
//
//  Created by Mark Lim Pak Mun on 29/05/2024.
//  Copyright © 2024 com.incremental.innovation. All rights reserved.
//

import Accelerate.vImage
import AppKit


// Define Response Curve Presets
struct ResponseCurvePreset {
    let label: String
    let boundary: Pixel_8
    let linearCoefficients: [Float]
    let gamma: Float
}

class GammaCorrectionEngine
{
    /*
     The presets array contains sample presets that apply different adjustments to the sample image.
     */
    static let presets = [
        // The L1 preset returns each pixel unchanged.
        ResponseCurvePreset(label: "L1",
                            boundary: 255,
                            linearCoefficients: [1, 0],
                            gamma: 0),
        // The L2 preset returns a washed out image.
        ResponseCurvePreset(label: "L2",
                            boundary: 255,
                            linearCoefficients: [0.5, 0.5],
                            gamma: 0),
        // The L3 preset returns a an image with a lot of contrast.
        ResponseCurvePreset(label: "L3",
                            boundary: 255,
                            linearCoefficients: [3, -1],
                            gamma: 0),
        // The L4 preset returns a negative version of the image.
        ResponseCurvePreset(label: "L4",
                            boundary: 255,
                            linearCoefficients: [-1, 1],
                            gamma: 0),
        // The E1 preset returns each pixel unchanged
        ResponseCurvePreset(label: "E1",
                            boundary: 0,
                            linearCoefficients: [1, 0],
                            gamma: 1),
        // The E2 preset has an overall darkening effect.
        ResponseCurvePreset(label: "E2",
                            boundary: 0,
                            linearCoefficients: [1, 0],
                            gamma: 2.2),
        // The E3 preset has an overall lightening effect.
        ResponseCurvePreset(label: "E3",
                            boundary: 0,
                            linearCoefficients: [1, 0],
                            gamma: 1 / 2.2)
    ]

    private let image: NSImage!
    var outputImage: CGImage!

    let sourceCGImage: CGImage!

    private var sourceBuffer: vImage_Buffer!

    // Create the RGB version of the source image, by creating a 3-channel, 8-bit format.
    private lazy var rgbFormat: vImage_CGImageFormat = {
        return vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8 * 3,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            renderingIntent: .defaultIntent)!
    }()

    // Create a 3-channel destination buffer using the source buffer’s dimensions and
    // the RGB format’s bitsPerPixel value.
    private lazy var destinationBuffer: vImage_Buffer = {

        guard let destinationBuffer = try? vImage_Buffer(
            width: Int(sourceBuffer.width),
            height: Int(sourceBuffer.height),
            bitsPerPixel: rgbFormat.bitsPerPixel)
        else {
            fatalError("Unable to create destinastion buffer.")
        }
        return destinationBuffer
    }()

    // bitmapInfo: last --> non-premultiplied RGBA
    private var imageFormat = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 8 * 4,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        renderingIntent: .defaultIntent)!

    var responseCurvePreset: ResponseCurvePreset {
        didSet {
            // When the user changes the response curve preset, the app applies the
            // appropriate piecewise gamma values to the source buffer and writes
            // the result to the destination buffer.
            outputImage = getGammaCorrectedImage(
                preset: responseCurvePreset,
                source: sourceBuffer!,
                destination: destinationBuffer,
                imageFormat: imageFormat)
        }
    }

    init(image: NSImage)
    {
        self.image = image

        guard
            let sourceCGImage = image.cgImage(forProposedRect: nil,
                                              context: nil,
                                              hints: nil)
        else {
            fatalError("Unable to parse image.")
        }

        self.sourceCGImage = sourceCGImage

        // Ensure the pixels populating the contents of `sourceBuffer is in RGBA order.
        sourceBuffer = try? vImage_Buffer(
            cgImage: sourceCGImage,
            format: imageFormat)

    /*
        var bytePtr = sourceBuffer.data.assumingMemoryBound(to: UInt8.self)
        for i in 0 ..< 2*imageFormat.componentCount {
            print(bytePtr[i], terminator: " ")
        }
        print()
    */
        // This assignment doesn't trigger a call to the function `getGammaCorrectedImage`
        responseCurvePreset = Self.presets[0]

        // We have to call the function getGammaCorrectedImage since the
        // above assignment does not trigger a call to the function.
        outputImage = getGammaCorrectedImage(
            preset: responseCurvePreset,
            source: sourceBuffer!,
            destination: destinationBuffer,
            imageFormat: imageFormat)
    }

    deinit {
        sourceBuffer.free()
        destinationBuffer.free()
    }

    /// Applies the piecewise gamma values that the preset specifies to the source buffer, writes the result to the
    /// destination buffer, and returns the destination buffer's contents as an image.
    private func getGammaCorrectedImage(preset: ResponseCurvePreset,
                                        source: vImage_Buffer,
                                        destination: vImage_Buffer,
                                        imageFormat: vImage_CGImageFormat) -> CGImage
    {
        var source = source
        var destination = destination
        // Each pixel of the source buffer has 4 channels in RGBA order.
        // Populate the destination with only the color channels, R, G, B.
        // On return, the destination buffer contains the red, green, and blue channels
        // of the source buffer.
        // This call is necessary since the `applyGama` function will modify
        // the contents of the destination buffer.
        vImageConvert_RGBA8888toRGB888(&source,
                                       &destination,
                                       vImage_Flags(kvImageNoFlags))

    /* Debugging:
         let bytePtr = destinationBuffer.data.assumingMemoryBound(to: UInt8.self)
         for i in 0 ..< 2*rgbFormat.componentCount {
            print(bytePtr[i], terminator: " ")
         }
         print()
    */

        let boundary: Pixel_8 = preset.boundary
        let linearCoefficients = preset.linearCoefficients

        let exponentialCoefficients: [Float] = [1, 0, 0]
        let gamma: Float = preset.gamma

        applyGamma(linearParameters: linearCoefficients,
                   exponentialParameters: exponentialCoefficients,
                   boundary: boundary,
                   gamma: gamma,
                   destination: destination)

        if let result = try? destination.createCGImage(format: rgbFormat) {
            return result
        }
        else {
            fatalError("Unable to generate output image.")
        }
    }

    private func applyGamma(linearParameters linearCoefficients: [Float],
                            exponentialParameters exponentialCoefficients: [Float],
                            boundary: Pixel_8,
                            gamma: Float,
                            destination: vImage_Buffer)
    {
        // Prepare the Buffers
        // Create a planar representation of the RGB buffer that is three times its width
        // to pass to the piecewise gamma function.
        // Note: we did not allocate memory to `data` property of planarDestination.
        var planarDestination = vImage_Buffer(
            data: destinationBuffer.data,
            height: destinationBuffer.height,
            width: destinationBuffer.width * 3,
            rowBytes: destinationBuffer.rowBytes)

        // Apply the Adjustment.
        // The contents of `destinationBuffer` are modified by the call below since
        // planarDestination.data and destinationBuffer.data point to the same memory block.
        // We can't release the memory allocated to planarDestination
        vImagePiecewiseGamma_Planar8(&planarDestination,        // src
                                     &planarDestination,        // dest
                                     exponentialCoefficients,
                                     gamma,
                                     linearCoefficients,
                                     boundary,
                                     vImage_Flags(kvImageNoFlags))
    }
}

