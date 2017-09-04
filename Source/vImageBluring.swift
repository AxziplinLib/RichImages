//
//  vImageBluring.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import Accelerate
import CoreGraphics

// MARK: - Blur.

public extension UIImage {
    /// Get the light-blured image from the original image. Nil if blur failed using `vImage`.
    public var lightBlur: UIImage! { return _blur(radius: 40.0, tintColor: UIColor(white: 1.0, alpha: 0.3), saturationDeltaFactor: 1.8, mask: nil) }
    /// Get the extra-light-blured image from the original image. Nil if blur failed using `vImage`.
    public var extraLightBlur: UIImage! { return _blur(radius: 40.0, tintColor: UIColor(white: 0.97, alpha: 0.82), saturationDeltaFactor: 1.8, mask: nil) }
    /// Get the dark-blured image from the original image. Nil if blur failed using `vImage`.
    public var darkBlur: UIImage! { return _blur(radius: 40.0, tintColor: UIColor(white: 0.11, alpha: 0.73), saturationDeltaFactor: 1.8, mask: nil) }
    /// Blur the receive image to an image with the tint color as "mask" using `vImage`.
    ///
    /// - Parameter tintColor: The color used to be the "mask".
    /// - Returns: A color-blured image or nil if blur failed.
    public func blur(tint tintColor: UIColor) -> UIImage! { return _blur(radius: 20.0, tintColor: tintColor.withAlphaComponent(0.6), saturationDeltaFactor: -1.0, mask: nil) }
    /// Blur the receive image to an image with blur radius using `vImage`.
    ///
    /// - Parameter radius: The radius used to blur.
    /// - Returns: A blured image or nil if blur failed.
    public func blur(radius: CGFloat) -> UIImage! { return _blur(radius: radius, tintColor: nil, saturationDeltaFactor: -1.0, mask: nil) }
    /// Create a blured image from the original with parameters using `vImage`.
    ///
    /// - Parameter radius: The blur radius.
    /// - Parameter tintColor: The color used as "mask".
    /// - Parameter saturationDeltaFactor: A value for factor of saturation.
    /// - Parameter mask: The mask image used to mask the blured image.
    ///
    /// - Returns: A blured image from the params or nil if blur failed.
    private func _blur(radius: CGFloat, tintColor: UIColor?, saturationDeltaFactor: CGFloat, mask: UIImage?) -> UIImage? {
        // Check pre-conditions.
        guard size.width >= 1.0 && size.height >= 1.0 else { return nil }
        guard let input = self.cgImage else { return nil }
        
        let hasBlur            : Bool = (radius > CGFloat.ulpOfOne)
        let hasSaturationChange: Bool = (fabs(saturationDeltaFactor - 1.0) > CGFloat.ulpOfOne)
        let rect = CGRect(origin: .zero, size: size)
        // Set up output context.
        // let alp = CGImageAlphaInfo(rawValue: input.bitmapInfo.rawValue | CGBitmapInfo.alphaInfoMask.rawValue)
        // let alps: [CGImageAlphaInfo] = [.none, .noneSkipLast, .noneSkipFirst]
        // let opaque = alps.contains(alp ?? .alphaOnly)
        UIGraphicsBeginImageContextWithOptions(rect.size, !hasAlpha, scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0.0, y: -rect.size.height)
        
        if hasBlur || hasSaturationChange {
            var effectInBuffer: vImage_Buffer = vImage_Buffer()
            var scratchBuffer1: vImage_Buffer = vImage_Buffer()
            var inputBuffer   : vImage_Buffer
            var outputBuffer  : vImage_Buffer
            // (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little)
            //  Requests a BGRA buffer.
            var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: nil, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), version: 0, decode: nil, renderingIntent: .defaultIntent)
            
            let e  = vImageBuffer_InitWithCGImage(&effectInBuffer, &format, nil, input, vImage_Flags(kvImagePrintDiagnosticsToConsole))
            if  e != kvImageNoError { return nil }
            
            vImageBuffer_Init(&scratchBuffer1, effectInBuffer.height, effectInBuffer.width, format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
            
            inputBuffer  = effectInBuffer
            outputBuffer = scratchBuffer1
            
            if hasBlur {
                // A description of how to compute the box kernel width from the Gaussian
                // radius (aka standard deviation) appears in the SVG spec:
                // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
                //
                // For larger values of 's' (s >= 2.0), an approximation can be used: Three
                // successive box-blurs build a piece-wise quadratic convolution kernel, which
                // approximates the Gaussian kernel to within roughly 3%.
                //
                // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
                //
                // ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
                //
                var inputRadius = radius * scale
                if  inputRadius - 2.0 < CGFloat.ulpOfOne { inputRadius = 2.0 }
                let _tmpRadius = floor((Double(inputRadius) * 3.0 * sqrt(Double.pi * 2.0) / 4.0 + 0.5) / 2.0)
                // Force radius to be odd so that the three box-blur methodology works.
                let _radius = UInt32(_tmpRadius) | 1
                
                let tempBufferSize = vImageBoxConvolve_ARGB8888(&inputBuffer, &outputBuffer, nil, 0, 0, _radius, _radius, nil, vImage_Flags(kvImageGetTempBufferSize | kvImageEdgeExtend))
                
                let tempBuffer = malloc(tempBufferSize)
                defer { free(tempBuffer) }
                
                vImageBoxConvolve_ARGB8888(&inputBuffer,  &outputBuffer, tempBuffer, 0, 0, _radius, _radius, nil, vImage_Flags(kvImageEdgeExtend))
                vImageBoxConvolve_ARGB8888(&outputBuffer, &inputBuffer,  tempBuffer, 0, 0, _radius, _radius, nil, vImage_Flags(kvImageEdgeExtend))
                vImageBoxConvolve_ARGB8888(&inputBuffer,  &outputBuffer, tempBuffer, 0, 0, _radius, _radius, nil, vImage_Flags(kvImageEdgeExtend))
                
                let tmpBuffer = inputBuffer
                inputBuffer   = outputBuffer
                outputBuffer  = tmpBuffer
            }
            
            if hasSaturationChange {
                let s: CGFloat = saturationDeltaFactor
                // These values appear in the W3C Filter Effects spec:
                // https://dvcs.w3.org/hg/FXTF/raw-file/default/filters/index.html#grayscaleEquivalent
                // Avoid the long time of type-check of the compiler.
                /* 0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0.0,
                 0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0.0,
                 0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0.0,
                 0.0,                  0.0,                  0.0,                  1.0
                 */
                var floatingPointSaturationMatrix: [CGFloat] = []
                floatingPointSaturationMatrix.append(0.0722 + 0.9278 * s)
                floatingPointSaturationMatrix.append(0.0722 - 0.0722 * s)
                floatingPointSaturationMatrix.append(0.0722 - 0.0722 * s)
                floatingPointSaturationMatrix.append(0.0)
                floatingPointSaturationMatrix.append(0.7152 - 0.7152 * s)
                floatingPointSaturationMatrix.append(0.7152 + 0.2848 * s)
                floatingPointSaturationMatrix.append(0.7152 - 0.7152 * s)
                floatingPointSaturationMatrix.append(0.0)
                floatingPointSaturationMatrix.append(0.2126 - 0.2126 * s)
                floatingPointSaturationMatrix.append(0.2126 - 0.2126 * s)
                floatingPointSaturationMatrix.append(0.2126 + 0.7873 * s)
                floatingPointSaturationMatrix.append(0.0)
                floatingPointSaturationMatrix.append(0.0)
                floatingPointSaturationMatrix.append(0.0)
                floatingPointSaturationMatrix.append(0.0)
                floatingPointSaturationMatrix.append(1.0)
                let divisor: Int32 = 256
                
                var saturationMatrix: [Int16] = []
                for floatingPointSaturation in floatingPointSaturationMatrix {
                    saturationMatrix.append(Int16(roundf(Float(floatingPointSaturation * CGFloat(divisor)))))
                }
                vImageMatrixMultiply_ARGB8888(&inputBuffer, &outputBuffer, saturationMatrix, divisor, nil, nil, vImage_Flags(kvImageNoFlags))
                
                let tmpBuffer = inputBuffer
                inputBuffer   = outputBuffer
                outputBuffer  = tmpBuffer
            }
            
            func cleanupBuffer(userData: UnsafeMutableRawPointer?, buf_data: UnsafeMutableRawPointer?) {
                if let buffer = buf_data { free(buffer) }
            }
            var effectCgImage = vImageCreateCGImageFromBuffer(&inputBuffer, &format, cleanupBuffer, nil, vImage_Flags(kvImageNoAllocate), nil)
            if  effectCgImage == nil {
                effectCgImage = vImageCreateCGImageFromBuffer(&inputBuffer, &format, nil, nil, vImage_Flags(kvImageNoFlags), nil)
                free(inputBuffer.data)
            }
            
            let maskCgImage = mask?._makeCgImage()
            if  maskCgImage != nil {
                // Only need to draw the base image if the effect image will be masked.
                context.draw(input, in: rect)
            }
            // draw effect image
            context.saveGState()
            if  maskCgImage != nil {
                context.clip(to: rect, mask: maskCgImage!)
            }
            if let _cgImage = effectCgImage?.takeUnretainedValue() {
                context.draw(_cgImage, in: rect)
            }
            context.restoreGState()
            
            // Cleanup
            // CGImageRelease(effectCgImage as! CGImage)
            effectCgImage?.release()
            free(outputBuffer.data)
        } else {
            // Draw base image.
            context.draw(input, in: rect)
        }
        
        // Add in color tint.
        if let tint = tintColor {
            context.saveGState()
            context.setFillColor(tint.cgColor)
            context.fill(rect)
            context.restoreGState()
        }
        // Output image is ready.
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
