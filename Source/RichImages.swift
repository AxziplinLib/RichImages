//
//  RichImages.swift
//  AxReminder
//
//  Created by devedbox on 2017/8/31.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import ImageIO
import MetalKit
import OpenGLES
import CoreImage
import Accelerate
import Foundation
import CoreGraphics
import AVFoundation

// MARK: - General.

extension UIView {
    /// Creates and render a snapshot of the view hierarchy into the current context. Returns nil if the snapshot is missing image data, an image object if the snapshot is complete.
    public var contents: UIImage! {
        UIGraphicsBeginImageContextWithOptions(bounds.size, isOpaque, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        if #available(iOS 7.0, *) {
            if !drawHierarchy(in: bounds, afterScreenUpdates: false) {
                guard let context = UIGraphicsGetCurrentContext() else { return nil }
                layer.render(in: context)
            }
        } else {
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            layer.render(in: context)
        }
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

extension UIImage {
    public var scaledWidth : CGFloat { return size.width * scale }
    public var scaledHeight: CGFloat { return size.height * scale }
    public var scaledSize  : CGSize  { return CGSize(width: scaledWidth, height: scaledHeight) }
}

extension CGRect { public func scale(by scale: CGFloat) -> CGRect {  return applying(CGAffineTransform(scaleX: scale, y: scale)) } }
extension CGSize { public func scale(by scale: CGFloat) -> CGSize {  return applying(CGAffineTransform(scaleX: scale, y: scale)) } }

// MARK: - Blur.

public extension UIImage {
    /// Get the light-blured image from the original image. Nil if blur failed.
    public var lightBlur: UIImage? { return _blur(radius: 40.0, tintColor: UIColor(white: 1.0, alpha: 0.3), saturationDeltaFactor: 1.8, mask: nil) }
    /// Get the extra-light-blured image from the original image. Nil if blur failed.
    public var extraLightBlur: UIImage? { return _blur(radius: 40.0, tintColor: UIColor(white: 0.97, alpha: 0.82), saturationDeltaFactor: 1.8, mask: nil) }
    /// Get the dark-blured image from the original image. Nil if blur failed.
    public var darkBlur: UIImage? { return _blur(radius: 40.0, tintColor: UIColor(white: 0.11, alpha: 0.73), saturationDeltaFactor: 1.8, mask: nil) }
    /// Blur the receive image to an image with the tint color as "mask".
    ///
    /// - Parameter tintColor: The color used to be the "mask".
    /// - Returns: A color-blured image or nil if blur failed.
    public func blur(tint tintColor: UIColor) -> UIImage? { return _blur(radius: 20.0, tintColor: tintColor.withAlphaComponent(0.6), saturationDeltaFactor: -1.0, mask: nil) }
    /// Blur the receive image to an image with blur radius.
    ///
    /// - Parameter radius: The radius used to blur.
    /// - Returns: A blured image or nil if blur failed.
    public func blur(radius: CGFloat) -> UIImage? { return _blur(radius: radius, tintColor: nil, saturationDeltaFactor: -1.0, mask: nil) }
    /// Create a blured image from the original with parameters.
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
        guard let input = cgImage else { return nil }
        if let _ = mask { guard let _ = mask?._makeCgImage() else { return nil } }
        
        let hasBlur = radius > .ulpOfOne
        let hasSaturationChange = fabs(saturationDeltaFactor - 1.0) > .ulpOfOne
        
        let inputScale = scale
        let inputBitmapInfo = input.bitmapInfo
        let inputAlphaInfo = CGImageAlphaInfo(rawValue: inputBitmapInfo.intersection([.alphaInfoMask]).rawValue)
        
        let outputSizeInPoints = size
        let outputRectInPoints = CGRect(origin: .zero, size: outputSizeInPoints)
        
        // Set up output context.
        var useOpaqueContext: Bool
        if inputAlphaInfo == .none || inputAlphaInfo == .noneSkipLast || inputAlphaInfo == .noneSkipFirst {
            useOpaqueContext = true
        } else {
            useOpaqueContext = false
        }
        UIGraphicsBeginImageContextWithOptions(outputSizeInPoints, useOpaqueContext, inputScale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0.0, y: -outputSizeInPoints.height)
        
        if hasBlur || hasSaturationChange {
            var effectInBuffer: vImage_Buffer = vImage_Buffer()
            var scratchBuffer1: vImage_Buffer = vImage_Buffer()
            var inputBuffer: vImage_Buffer
            var outputBuffer: vImage_Buffer
            
            var format = vImage_CGImageFormat(
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                colorSpace: nil,
                // (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little)
                // requests a BGRA buffer.
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                version: 0,
                decode: nil,
                renderingIntent: .defaultIntent)
            
            let e = vImageBuffer_InitWithCGImage(&effectInBuffer, &format, nil, input, vImage_Flags(kvImagePrintDiagnosticsToConsole))
            if e != kvImageNoError {
                return nil
            }
            
            vImageBuffer_Init(&scratchBuffer1, effectInBuffer.height, effectInBuffer.width, format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
            
            inputBuffer = effectInBuffer
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
                var inputRadius = radius * inputScale
                if inputRadius - 2.0 < .ulpOfOne { inputRadius = 2.0 }
                let _tmpRadius = floor((Double(inputRadius) * 3.0 * sqrt(Double.pi * 2.0) / 4.0 + 0.5) / 2.0)
                let _radius = UInt32(_tmpRadius) | 1 // force radius to be odd so that the three box-blur methodology works.
                
                let tempBufferSize = vImageBoxConvolve_ARGB8888(&inputBuffer, &outputBuffer, nil, 0, 0, _radius, _radius, nil, vImage_Flags(kvImageGetTempBufferSize | kvImageEdgeExtend))
                
                let tempBuffer = malloc(tempBufferSize)
                defer { free(tempBuffer) }
                
                vImageBoxConvolve_ARGB8888(&inputBuffer, &outputBuffer, tempBuffer, 0, 0, _radius, _radius, nil, vImage_Flags(kvImageEdgeExtend))
                vImageBoxConvolve_ARGB8888(&outputBuffer, &inputBuffer, tempBuffer, 0, 0, _radius, _radius, nil, vImage_Flags(kvImageEdgeExtend))
                vImageBoxConvolve_ARGB8888(&inputBuffer, &outputBuffer, tempBuffer, 0, 0, _radius, _radius, nil, vImage_Flags(kvImageEdgeExtend))
                
                let tmpBuffer = inputBuffer
                inputBuffer = outputBuffer
                outputBuffer = tmpBuffer
            }
            
            if hasSaturationChange {
                let s = saturationDeltaFactor
                // These values appear in the W3C Filter Effects spec:
                // https://dvcs.w3.org/hg/FXTF/raw-file/default/filters/index.html#grayscaleEquivalent
                //
                let floatingPointSaturationMatrix: [CGFloat] = [
                    0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0.0,
                    0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0.0,
                    0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0.0,
                    0.0,                  0.0,                  0.0,                  1.0,
                    ]
                let divisor: Int32 = 256
                // let matrixSize = MemoryLayout.size(ofValue: floatingPointSaturationMatrix) / MemoryLayout.size(ofValue: floatingPointSaturationMatrix[0])
                // let matrixSize = floatingPointSaturationMatrix.count
                var saturationMatrix: [Int16] = []
                for /*i in 0 ..< matrixSize*/ floatingPointSaturation in floatingPointSaturationMatrix {
                    saturationMatrix.append(Int16(roundf(Float(/*floatingPointSaturationMatrix[i]*/floatingPointSaturation * CGFloat(divisor)))))
                }
                vImageMatrixMultiply_ARGB8888(&inputBuffer, &outputBuffer, saturationMatrix, divisor, nil, nil, vImage_Flags(kvImageNoFlags))
                
                let tmpBuffer = inputBuffer
                inputBuffer = outputBuffer
                outputBuffer = tmpBuffer
            }
            
            func cleanupBuffer(userData: UnsafeMutableRawPointer?, buf_data: UnsafeMutableRawPointer?) {
                if let buffer = buf_data { free(buffer) }
            }
            var effectCGImage = vImageCreateCGImageFromBuffer(&inputBuffer, &format, cleanupBuffer, nil, vImage_Flags(kvImageNoAllocate), nil)
            if effectCGImage == nil {
                effectCGImage = vImageCreateCGImageFromBuffer(&inputBuffer, &format, nil, nil, vImage_Flags(kvImageNoFlags), nil)
                free(inputBuffer.data)
            }
            
            if mask != nil {
                // Only need to draw the base image if the effect image will be masked.
                context.__draw(in: outputRectInPoints, image: input)
            }
            // draw effect image
            context.saveGState()
            if let maskCGImage = mask?._makeCgImage() {
                context.clip(to: outputRectInPoints, mask: maskCGImage)
            }
            if let _cgImage = effectCGImage?.takeUnretainedValue() {
                context.__draw(in: outputRectInPoints, image: _cgImage)
            }
            context.restoreGState()
            
            // Cleanup
            // CGImageRelease(effectCGImage as! CGImage)
            effectCGImage?.release()
            free(outputBuffer.data)
        } else {
            // draw base image
            context.__draw(in: outputRectInPoints, image: input)
        }
        
        // Add in color tint.
        if tintColor != nil {
            context.saveGState()
            context.setFillColor(tintColor!.cgColor)
            context.fill(outputRectInPoints)
            context.restoreGState()
        }
        // Output image is ready.
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - CMSampleBuffer.

extension UIImage {
    /// Create an image from the core media sample buffer by applying a affine transform.
    ///
    /// - Parameter sampleBuffer: The buffer data representing the original basal image data.
    /// - Parameter applying: The closure to apply affine transform.
    ///
    /// - Returns: An image instance from the sample buffer.
    public class func image(from sampleBuffer: CMSampleBuffer, applying: ((CGSize) -> CGAffineTransform)? = nil) -> UIImage? {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // Get the number of bytes per row for the pixel buffer
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return nil }
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
        // Create a Quartz image from the pixel data in the bitmap graphics context
        guard let _originalImage = context.makeImage() else { return nil }
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        guard let rotateCtx = CGContext(data: nil, width: height, height: width, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {return nil }
        if let transform = applying?(CGSize(width: width, height: height)) {
            rotateCtx.concatenate(transform)
        } else {
            rotateCtx.translateBy(x: 0.0, y: CGFloat(width))
            rotateCtx.rotate(by: -CGFloat.pi * 0.5)
        }
        rotateCtx.draw(_originalImage, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        guard let _image = rotateCtx.makeImage() else { return nil }
        
        // Free up the context and color space
        // CGContextRelease(context);
        // CGColorSpaceRelease(colorSpace);
        
        // Create an image object from the Quartz image
        let image = UIImage(cgImage: _image, scale: UIScreen.main.scale, orientation: .up)
        return image
    }
}

// MARK: - Supported Pixel Formats:
//----------------------------------------------------------------------------------------------------
//| CS   | Pixel format and bitmap information constant                              | Availability  |
//----------------------------------------------------------------------------------------------------
//| Null | 8   bpp, 8  bpc, kCGImageAlphaOnly                                        | Mac OS X, iOS |
//----------------------------------------------------------------------------------------------------
//| Gray | 8   bpp, 8  bpc, kCGImageAlphaNone                                        | Mac OS X, iOS |
//----------------------------------------------------------------------------------------------------
//| Gray | 8   bpp, 8  bpc, kCGImageAlphaOnly                                        | Mac OS X, iOS |
//----------------------------------------------------------------------------------------------------
//| Gray | 16  bpp, 16 bpc, kCGImageAlphaNone                                        | Mac OS X      |
//----------------------------------------------------------------------------------------------------
//| Gray | 32  bpp, 32 bpc, kCGImageAlphaNone|kCGBitmapFloatComponents               | Mac OS X      |
//----------------------------------------------------------------------------------------------------
//| RGB  | 16  bpp, 5  bpc, kCGImageAlphaNoneSkipFirst                               | Mac OS X, iOS |
//----------------------------------------------------------------------------------------------------
//| RGB  | 32  bpp, 8  bpc, kCGImageAlphaNoneSkipFirst                               | Mac OS X, iOS |
//----------------------------------------------------------------------------------------------------
//| RGB  | 32  bpp, 8  bpc, kCGImageAlphaNoneSkipLast                                | Mac OS X, iOS |
//----------------------------------------------------------------------------------------------------
//| RGB  | 32  bpp, 8  bpc, kCGImageAlphaPremultipliedFirst                          | Mac OS X, iOS |
//----------------------------------------------------------------------------------------------------
//| RGB  | 32  bpp, 8  bpc, kCGImageAlphaPremultipliedLast                           | Mac OS X, iOS |
//----------------------------------------------------------------------------------------------------
//| RGB  | 64  bpp, 16 bpc, kCGImageAlphaPremultipliedLast                           | Mac OS X      |
//----------------------------------------------------------------------------------------------------
//| RGB  | 64  bpp, 16 bpc, kCGImageAlphaNoneSkipLast                                | Mac OS X      |
//----------------------------------------------------------------------------------------------------
//| RGB  | 128 bpp, 32 bpc, kCGImageAlphaNoneSkipLast |kCGBitmapFloatComponents      | Mac OS X      |
//----------------------------------------------------------------------------------------------------
//| RGB  | 128 bpp, 32 bpc, kCGImageAlphaPremultipliedLast |kCGBitmapFloatComponents | Mac OS X      |
//----------------------------------------------------------------------------------------------------
//| CMYK | 32  bpp, 8  bpc, kCGImageAlphaNone                                        | Mac OS X      |
//----------------------------------------------------------------------------------------------------
//| CMYK | 64  bpp, 16 bpc, kCGImageAlphaNone                                        | Mac OS X      |
//----------------------------------------------------------------------------------------------------
//| CMYK | 128 bpp, 32 bpc, kCGImageAlphaNone |kCGBitmapFloatComponents              | Mac OS X      |
//----------------------------------------------------------------------------------------------------

fileprivate func _correct(bitmapInfo: CGBitmapInfo, `for` colorSpace: CGColorSpace) -> CGBitmapInfo {
    var bitmap = bitmapInfo
    if colorSpace.model == .rgb {
        if  [CGImageAlphaInfo.first.rawValue, CGImageAlphaInfo.last.rawValue].contains(bitmap.rawValue) {
            bitmap = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo(rawValue: (0 << 12)).rawValue)
        }
        if  bitmap.rawValue == CGImageAlphaInfo.none.rawValue {
            bitmap = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo(rawValue: (0 << 12)).rawValue)
        }
    } else if colorSpace.model == .monochrome {
        if  [CGImageAlphaInfo.noneSkipLast.rawValue, CGImageAlphaInfo.noneSkipFirst.rawValue].contains(bitmap.rawValue) {
            bitmap = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue | CGBitmapInfo(rawValue: (0 << 12)).rawValue)
        }
        if  [CGImageAlphaInfo.premultipliedLast.rawValue, CGImageAlphaInfo.premultipliedFirst.rawValue, CGImageAlphaInfo.last.rawValue, CGImageAlphaInfo.first.rawValue].contains(bitmap.rawValue) {
            bitmap = CGBitmapInfo(rawValue: CGImageAlphaInfo.alphaOnly.rawValue | CGBitmapInfo(rawValue: (0 << 12)).rawValue)
        }
    }
    return bitmap
}

extension UIImage {
    /// A type representing the rendering destination of the image's cropping and other processing.
    public enum RenderDestination {
        /// A type representing the GPU-Based rendering.
        public enum GPU {
            /// Indicates the rendering is based on a `MTLDevice`. The GPU-Based contex for this value
            /// will automatic fallthrough to the OpenGL ES-Based if the Metal device is not available.
            case metal
            /// Indicates the rendering is based on the api of `OpenGL ES`.
            case openGLES
        }
        /// Indicates the rendering using the automatic context in `CoreImage`.
        case auto
        /// Indicates the rendering using the cg context in `CoreGraphics`.
        case cpu
        /// Indicates the rendering using the GPU-Based context in `CoreImage`.
        case gpu(GPU)
    }
}

// MARK: - Alpha.

extension UIImage {
    /// A boolean value indicates whether the image has alpha channel.
    public var hasAlpha: Bool {
        guard let cgImage = _makeCgImage(), let colorSpace = cgImage.colorSpace else { return false }
        let alp = cgImage.alphaInfo
        let alp_ops: [CGImageAlphaInfo] = [.first, .last, .premultipliedFirst, .premultipliedLast]
        return (alp_ops.contains(alp) && colorSpace.model == .rgb) || (colorSpace.model == .monochrome && alp == .alphaOnly)
    }
    /// Returns a copied instance based on the receiver if the receiver image contains no any alpha channels. 
    /// Animated image supported.
    ///
    /// Nil will be returned if the new image context cannot be created or any other errors occured.
    public var alpha: UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.alpha } }), duration: duration) }
        
        guard !hasAlpha else { return self }
        guard let cgImage = _makeCgImage(), let colorSpace = cgImage.colorSpace else { return nil }
        // The bitsPerComponent and bitmapInfo values are hard-coded to prevent an "unsupported parameter combination" error
        guard let context = CGContext(data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace.model == .rgb ? colorSpace : CGColorSpaceCreateDeviceRGB(), bitmapInfo: (CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo(rawValue: (0 << 12)).rawValue)) else { return nil }
        // Draw the image into the context and retrieve the new image, which will now have an alpha layer
        context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: cgImage.width, height: cgImage.height)))
        guard let alp_img = context.makeImage() else { return nil }
        return UIImage(cgImage: alp_img, scale: scale, orientation: imageOrientation)
    }
    /// Creates a copy of the image with a transparent border of the given size added around its edges in points.
    /// Animated image supported.
    ///
    /// If the image has no alpha layer, one will be added to it.
    ///
    /// - Parameter transparentBorderWidth: The arounded border size.
    /// - Returns: A copy of the image with a transparent border of the given size added around its edges.
    public func bordered(_ transparentBorderWidth: CGFloat) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.bordered(transparentBorderWidth) } }), duration: duration) }
        // Scales points to pxiels.
        let scaledTransparentBorderWidth = transparentBorderWidth * scale
        // If the image does not have an alpha layer, add one.
        guard let cgImage = self.alpha._makeCgImage(), let colorSpace = cgImage.colorSpace else { return nil }
        let cgSize  = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let bitmap  = _correct(bitmapInfo: cgImage.bitmapInfo, for: colorSpace)
        var rect    = CGRect(origin: .zero, size: cgSize).insetBy(dx: -scaledTransparentBorderWidth, dy: -scaledTransparentBorderWidth)
        rect.origin = .zero
        // Build a context that's the same dimensions as the new size
        guard let context = CGContext(data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmap.rawValue) else { return nil }
        // Draw the image in the center of the context, leaving a gap around the edges
        let croppingRect = rect.insetBy(dx: scaledTransparentBorderWidth, dy: scaledTransparentBorderWidth)
        context.draw(cgImage, in: croppingRect)
        guard let centeredImg = context.makeImage() else { return nil }
        // Create a mask to make the border transparent, and combine it with the image
        guard let mask = type(of: self)._borderedMask(rect.size, borderWidth: scaledTransparentBorderWidth) else { return nil }
        
        guard let maskedCgImg = centeredImg.masking(mask) else { return nil }
        return UIImage(cgImage: maskedCgImg, scale: scale, orientation: imageOrientation)
    }
    /// Creates a mask that makes the outer edges transparent and everything else opaque.
    ///
    /// The size must include the entire mask (opaque part + transparent border).
    ///
    /// - Parameter size: The outter size of the mask image to drawing.
    /// - Parameter borderWidth: The border width of the transparent part.
    ///
    /// - Returns: An image with inner opaque part and transparent border.
    private class func _borderedMask(_ size: CGSize, borderWidth: CGFloat) -> CGImage! {
        // Early fatal checking.
        guard size.width > borderWidth && size.height > borderWidth && borderWidth >= 0.0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        // Build a context that's the same dimensions as the new size
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: (CGImageAlphaInfo.none.rawValue | CGBitmapInfo(rawValue: (0 << 12)).rawValue)) else { return nil }
        // Start with a mask that's entirely transparent
        let rect = CGRect(origin: .zero, size: size)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(rect)
        // Make the inner part (within the border) opaque
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect.insetBy(dx: borderWidth, dy: borderWidth))
        // Get an image of the context
        guard let mask = context.makeImage() else { return nil }
        return mask
    }
}

// MARK: - RoundedCorner.

extension UIImage {
    /// Returns an copy of the receiver with critical rounding in pixels. Animated image supported.
    public var cornered: UIImage! { return round(min(scaledWidth, scaledHeight) * 0.5, border: 0.0) }
    /// Creates a copy of this image with rounded corners in points. Animated image supported. Animated image supported.
    ///
    /// If borderWidth is non-zero, a transparent border of the given size will also be added.
    ///
    /// Original author: Björn Sållarp. Used with permission. See: [http://blog.sallarp.com/iphone-uiimage-round-corners/](http://blog.sallarp.com/iphone-uiimage-round-corners/)
    ///
    /// - Parameter cornerWidth: The width of the corner drawing. The value must not be negative.
    /// - Parameter borderWidth: The width of border drawing. The value must not be negative. The value is 0.0 by default.
    ///
    /// - Returns: An image with rounded corners.
    public func round(_ cornerRadius: CGFloat, border borderWidth: CGFloat = 0.0) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.round(cornerRadius, border: borderWidth) } }), duration: duration) }
        
        // Early fatal checking.
        guard cornerRadius >= 0.0 && borderWidth >= 0.0 else { return nil }
        // Scales points to pxiels.
        let scaledCornerRadius = cornerRadius * scale
        let scaledBorderWidth  = borderWidth  * scale
        
        // If the image does not have an alpha layer, add one
        guard let cgImage = self.alpha._makeCgImage(), let colorSpace = cgImage.colorSpace else { return nil }
        let cgSize  = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let bitmap  = _correct(bitmapInfo: cgImage.bitmapInfo, for: colorSpace)
        var rect    = CGRect(origin: .zero, size: cgSize).insetBy(dx: -scaledBorderWidth, dy: -scaledBorderWidth)
        rect.origin = .zero
        // Build a context that's the same dimensions as the new size
        guard let context = CGContext(data: nil, width: Int(rect.width), height: Int(rect.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmap.rawValue) else { return nil }
        // Create a clipping path with rounded corners
        context.beginPath()
        let roundedRect = rect.insetBy(dx: scaledBorderWidth, dy: scaledBorderWidth)
        if scaledCornerRadius == 0 {
            context.addRect(roundedRect)
        } else {
            context.saveGState()
            context.translateBy(x: roundedRect.minX, y: roundedRect.minY)
            context.scaleBy(x: scaledCornerRadius, y: scaledCornerRadius)
            
            let wr = roundedRect.width  / scaledCornerRadius
            let hr = roundedRect.height / scaledCornerRadius
            
            context.move(to: CGPoint(x: wr, y: hr * 0.5))
            context.addArc(tangent1End: CGPoint(x: wr, y: hr), tangent2End: CGPoint(x: wr * 0.5, y: hr), radius: 1.0)
            context.addArc(tangent1End: CGPoint(x: 0.0, y: hr), tangent2End: CGPoint(x: 0.0, y: hr * 0.5), radius: 1.0)
            context.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: wr * 0.5, y: 0.0), radius: 1.0)
            context.addArc(tangent1End: CGPoint(x: wr, y: 0.0), tangent2End: CGPoint(x: wr, y: hr * 0.5), radius: 1.0)
            context.closePath()
            context.restoreGState()
        }
        context.closePath()
        context.clip()
        // Draw the image to the context; the clipping path will make anything outside the rounded rect transparent
        context.draw(cgImage, in: rect)
        // Create a CGImage from the context
        guard let clippedImage = context.makeImage() else { return nil }
        
        // Create a UIImage from the CGImage
        return UIImage(cgImage: clippedImage, scale: scale, orientation: imageOrientation)
    }
}

// MARK: - Resizing.

extension UIImage {
    /// A type reprensting the calculating mode of the image's resizing.
    public enum ResizingMode: Int {
        case scaleToFill
        case scaleAspectFit // contents scaled to fit with fixed aspect. remainder is transparent
        case scaleAspectFill // contents scaled to fill with fixed aspect. some portion of content may be clipped.
        case center // contents remain same size. positioned adjusted.
        case top
        case bottom
        case left
        case right
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    /// Creates a copy of the receiver that is cropped to the given rectangle in points. Animated image supported.
    ///
    /// The bounds will be adjusted using `CGRectIntegral`.
    ///
    /// This method ignores the image's imageOrientation setting.
    ///
    /// - Parameter rect: The rectangle area coordinates in the receiver. The value
    ///                   of the rectangle must not be zero or negative sizing.
    /// - Parameter dest: A value of `RenderDestination` indicates the rendering destination of the image cropping processing.
    ///
    /// - Returns: An copy of the receiver cropped to the given rectangle.
    public func crop(to rect: CGRect, rendering dest: RenderDestination = .gpu(.metal)) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.crop(to: rect, rendering: dest) } }), duration: duration) }
        // Early fatal checking.
        guard rect.width > 0.0 && rect.height > 0.0 else { return nil }
        // Scales points to pxiels.
        let croppingRect = CGRect(origin: rect.origin, size: rect.size).scale(by: scale)
        
        var fallthroughToCpu = false
        switch dest {
        case .auto:
            fallthroughToCpu = true
            fallthrough
        case .gpu(_):
            guard let ciImage = _makeCiImage()?.cropping(to: croppingRect)             else { return fallthroughToCpu ? crop(to:rect, rendering: .cpu) : nil }
            guard let ciContext = _ciContext(of: dest)                                 else { return fallthroughToCpu ? crop(to:rect, rendering: .cpu) : nil }
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return fallthroughToCpu ? crop(to:rect, rendering: .cpu) : nil }
            
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        default:
            guard let cgImage = _makeCgImage()?.cropping(to: croppingRect) else { return nil }
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
    }
    /// Creates a copy of the receiver that is cropped to the given size with a specific resizing mode in pixels. Animated image supported.
    ///
    /// The size will be adjusted using `CGRectIntegral`.
    ///
    /// This method ignores the image's imageOrientation setting.
    ///
    /// - Parameter size: The size you want to crop the image. The values of
    ///                   the size must not be zero or negative.
    /// - Parameter mode: The resizing mode to decide the rectangle to crop.
    ///                   The value will use `.center` by default.
    ///
    /// - Returns: An copy of the receiver cropped to the given size and resizing mode.
    public func crop(fits size: CGSize, using mode: ResizingMode = .center, rendering dest: RenderDestination = .gpu(.metal)) -> UIImage! {
        // Scales points to pxiels.
        var croppingRect = CGRect(origin: .zero, size: size).scale(by: scale)
        switch mode {
        case .scaleToFill:
            return resize(fills: size, quality: .default)
        case .scaleAspectFill: fallthrough
        case .scaleAspectFit :
            return resize(fits: size, using: mode, quality: .default)
        case .center:
            croppingRect.origin.x = (scaledWidth  - croppingRect.width)  * 0.5
            croppingRect.origin.y = (scaledHeight - croppingRect.height) * 0.5
        case .top:
            croppingRect.origin.x = (scaledWidth  - croppingRect.width)  * 0.5
        case .bottom:
            croppingRect.origin.x = (scaledWidth  - croppingRect.width)  * 0.5
            croppingRect.origin.y = (scaledHeight - croppingRect.height)
        case .left:
            croppingRect.origin.y = (scaledHeight - croppingRect.height) * 0.5
        case .right:
            croppingRect.origin.x = (scaledWidth  - croppingRect.width)
            croppingRect.origin.y = (scaledHeight - croppingRect.height) * 0.5
        case .topLeft: break
        case .topRight:
            croppingRect.origin.x = (scaledWidth  - croppingRect.width)
        case .bottomLeft:
            croppingRect.origin.y = (scaledHeight - croppingRect.height)
        case .bottomRight:
            croppingRect.origin.x = (scaledWidth  - croppingRect.width)
            croppingRect.origin.y = (scaledHeight - croppingRect.height)
        }
        
        return crop(to: croppingRect.scale(by: 1.0 / scale), rendering: dest)
    }
    /// Creates a copy of this image that is squared to the thumbnail size using `QuartzCore` redrawing in points. Animated image supported.
    ///
    /// If borderWidth is non-zero, a transparent border of the given size will
    /// be added around the edges of the thumbnail. (Adding a transparent border
    /// of at least one pixel in size has the side-effect of antialiasing the
    /// edges of the image when rotating it using Core Animation.)
    ///
    /// - Parameter sizet       : A size of thumbnail to fit and square to.
    /// - Parameter borderWidth : A value indicates the width of the transparent border. Using 0.0 by default.
    /// - Parameter cornerRadius: A value indicates the radius of rounded corner. Using 0.0 by default.
    /// - Parameter quality     : An instance of `CGInterpolationQuality` indicates the
    ///                           interpolation of the receiver. Defaults to `.default.`
    ///
    /// - Returns: A copy of the receiver that is squared to the thumbnail size.
    public func thumbnail(squaresTo sizet: CGFloat, borderWidth: CGFloat = 0.0, cornerRadius: CGFloat = 0.0, quality: CGInterpolationQuality = .default) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.thumbnail(squaresTo: sizet, borderWidth: borderWidth, cornerRadius: cornerRadius, quality: quality) } }), duration: duration) }
        
        // Resize the original image.
        guard let resizedImage = resize(fits: CGSize(width: sizet, height: sizet), using: .scaleAspectFill, quality: quality) else { return nil }
        // Crop out any part of the image that's larger than the thumbnail size
        // The cropped rect must be centered on the resized image
        // Round the origin points so that the size isn't altered when CGRectIntegral is later invoked
        let croppedRect = CGRect(x: ((resizedImage.size.width - sizet) * 0.5).rounded(), y: ((resizedImage.size.width - sizet) * 0.5).rounded(), width: sizet, height: sizet)
        guard let croppedImage = resizedImage.crop(to: croppedRect) else { return nil }
        var borderedImage = croppedImage
        if borderWidth > 0.0 { borderedImage = croppedImage.bordered(borderWidth) }
        
        return borderedImage.round(cornerRadius, border: borderWidth)
    }
    /// Creates a copy of this image that is scale-aspect-fit to the thumbnail size using `ImageIO` in points.
    /// Animated image supported.
    ///
    /// - Parameter size: A size of thumbnail to scale-aspect-fit to.
    ///
    /// - Returns: A copy of the receiver that is squared to the thumbnail size.
    public func thumbnail(scalesToFit size: CGFloat) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.thumbnail(scalesToFit: size) } }), duration: duration) }
        
        // Package the integer as a  CFNumber object. Using CFTypes allows you
        // to more easily create the options dictionary later.
        var intSize = Int(size * scale)
        guard let thumbnailSize = CFNumberCreate(nil, .intType, &intSize) else { return nil }
        // Set up the thumbnail options.
        let keys  : [CFString]  = [kCGImageSourceCreateThumbnailWithTransform, kCGImageSourceCreateThumbnailFromImageIfAbsent, kCGImageSourceThumbnailMaxPixelSize]
        let values: [CFTypeRef] = [kCFBooleanTrue, kCFBooleanTrue, thumbnailSize]
        let options = NSDictionary(objects: values, forKeys: keys as! [NSCopying]) as CFDictionary
        // Create an image source from CGDataProvider; no options.
        if let dataProvider = _makeCgImage()?.dataProvider, let imageSource = CGImageSourceCreateWithDataProvider(dataProvider, nil), let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
            return UIImage(cgImage: thumbnail, scale: scale, orientation: imageOrientation)
        }
        // Create an image source from NSData; no options.
        guard let data = UIImageJPEGRepresentation(self, 1.0) as CFData?, let imageSource = CGImageSourceCreateWithData(data, nil) else { return nil }
        // Create the thumbnail image using the specified options.
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) else { return nil }
        
        return UIImage(cgImage: thumbnail, scale: scale, orientation: imageOrientation)
    }
    /// Resizes the image according to the given content mode, taking into account the image's orientation in pixels.
    /// Animated image supported.
    ///
    /// - Parameter size        : A value of `CGSize` indicates the size to draw of the image.
    /// - Parameter resizingMode: An instance of `UIImage.ResizingMode` using to decide the size of the resizing.
    /// - Parameter quality     : An instance of `CGInterpolationQuality` indicates the
    ///                           interpolation of the receiver. Defaults to `.default.`
    ///
    /// - Returns: A copy of the receiver resized to the given size.
    public func resize(fits size: CGSize, using resizingMode: ResizingMode, quality: CGInterpolationQuality = .default) -> UIImage! {
        let horizontalRatio = size.width  / self.size.width
        let verticalRatio   = size.height / self.size.width
        var ratio: CGFloat
        
        switch resizingMode {
        case .scaleAspectFill:
            ratio = max(horizontalRatio, verticalRatio)
        case .scaleAspectFit:
            ratio = min(horizontalRatio, verticalRatio)
        default:
            return resize(fills: size, quality: quality)
        }
        
        let newSize = CGSize(width: (self.size.width * ratio).rounded(), height: (self.size.width * ratio).rounded())
        return resize(fills: newSize, quality: quality)
    }
    /// Creates a rescaled copy of the image, taking into account its orientation in points. Animated image supported.
    ///
    /// The image will be scaled disproportionately if necessary to fit the bounds specified by the parameter.
    ///
    /// - Parameter size   : A CGSize object to resize the scaling of the receiver with.
    /// - Parameter quality: An instance of `CGInterpolationQuality` indicates the
    ///                      interpolation of the receiver. Defaults to `.default.`
    ///
    /// - Returns: A rescaled copy of the receiver.
    public func resize(fills size: CGSize, quality: CGInterpolationQuality = .default) -> UIImage! {
        var transposed = false
        switch imageOrientation {
        case .left         : fallthrough
        case .leftMirrored : fallthrough
        case .right        : fallthrough
        case .rightMirrored:
            transposed = true
        default: break
        }
        
        return _resize(fills: size, applying: _transform(forOrientation: size.scale(by: scale)), transposed: transposed, quality: quality)
    }
    /// Returns a copy of the image that has been transformed using the given affine transform and scaled to the new size in points.
    /// Animated image supported.
    ///
    /// The new image's orientation will be UIImageOrientationUp, regardless of the current image's orientation
    ///
    /// If the new size is not integral, it will be rounded up.
    private func _resize(fills newSize: CGSize, applying transform: CGAffineTransform, transposed: Bool, quality: CGInterpolationQuality) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img._resize(fills: newSize, applying: transform, transposed: transposed, quality: quality) } }), duration: duration) }
        // Scales points to pxiels.
        let newRect        = CGRect(origin: .zero, size: newSize).integral.scale(by: scale)
        let transposedRect = CGRect(origin: .zero, size: CGSize(width: newRect.height, height: newRect.width)).integral.scale(by: scale)
        guard let cgImage = _makeCgImage(), let colorSpace = cgImage.colorSpace else { return nil }
        // Build a context that's the same dimensions as the new size
        // FIXME: How to decide the right alpha info of the bitmap.
        let bitmap = _correct(bitmapInfo: cgImage.bitmapInfo, for: colorSpace)
        
        guard let context = CGContext(data: nil, width: Int(newRect.width), height: Int(newRect.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmap.rawValue) else { return nil }
        // Rotate and/or flip the image if required by its orientation
        context.concatenate(transform)
        // Set the quality level to use when rescaling
        context.interpolationQuality = quality
        // Draw into the context, this scales the image
        context.draw(cgImage, in: transposed ? transposedRect : newRect)
        // Get the resized image from the context and a UIImage
        guard let resized_img = context.makeImage() else { return nil }
        return UIImage(cgImage: resized_img, scale: scale, orientation: imageOrientation)
    }
    /// Returns an affine transform that takes into account the image orientation when drawing a scaled image.
    private func _transform(forOrientation size: CGSize) -> CGAffineTransform {
        let transform = CGAffineTransform.identity
        switch imageOrientation {
        case .down: fallthrough  // EXIF = 3
        case .downMirrored:      // EXIF = 4
            transform.translatedBy(x: size.width, y: size.height).rotated(by: CGFloat.pi)
        case .left: fallthrough  // EXIF = 6
        case .leftMirrored:      // EXIF = 5
            transform.translatedBy(x: size.width, y: 0.0).rotated(by: CGFloat.pi * 0.5)
        case .right: fallthrough // EXIF = 8
        case .rightMirrored:     // EXIF = 7
            transform.translatedBy(x: 0.0, y: size.height).rotated(by: -CGFloat.pi * 0.5)
        default: break
        }
        
        switch imageOrientation {
        case .upMirrored: fallthrough   // EXIF = 2
        case .downMirrored:             // EXIF = 4
            transform.translatedBy(x: size.width, y: 0.0).scaledBy(x: -1.0, y: 1.0)
        case .leftMirrored: fallthrough // EXIF = 5
        case .rightMirrored:            // EXIF = 7
            transform.translatedBy(x: size.height, y: 0.0).scaledBy(x: -1.0, y: 1.0)
        default: break
        }
        return transform
    }
}

// MARK: - Compressing.

extension UIImage {
    /// Creates a data stream of the receiver by compressing to the specific max allowed 
    /// bits length and max allowed width of size using `JPEGRepresentation`.
    ///
    /// - Parameter length: An integer value indicates the max allowed bits length to compress to.
    ///                     The length to compress to can not be negative or zero.
    /// - Parameter width : A float value indicates the max allowed width of the size of the reveiver.
    ///                     The width to compress to can not be negative or zero.
    ///
    /// - Returns: A compressed data stream of the receiver if any.
    public func compress(toBits length: Int, scalesToFit width: CGFloat? = nil) -> Data! {
        guard length > 0 else { return nil }
        // Scales the image to fit the specific size if any.
        var scaled = self
        if let maxSize = width {
            guard maxSize > 0.0 else { return nil }
            scaled = thumbnail(scalesToFit: maxSize)
        }
        // Do compress.
        var compressionQuality: CGFloat = 0.9
        var data              : Data?   = UIImageJPEGRepresentation(scaled, compressionQuality)
        
        while data?.count ?? 0 > length && compressionQuality > 0.01 {
            compressionQuality -= 0.02
            data                = UIImageJPEGRepresentation(scaled, compressionQuality)
        }
        
        return data
    }
}

// MARK: - Merging.

extension UIImage {
    /// A type representing the mode of the merging of images. Currently supporting `overlay`, `horizontal` and `vertical`.
    public enum MergingMode {
        /// A type representing the direction on the horizontal.
        public enum Horizontal {
            /// Indicates from-left-to-right direction.
            case leftToRight
            /// Indicates from-right-to-left direction.
            case rightToLeft
        }
        /// A type representing the direction on the vertical.
        public enum Vertical {
            /// Indicates from-top-to-bottom direction.
            case topToBottom
            /// Indicates from-bottom-to-top direction.
            case bottomToTop
        }
        /// Indicates the merged image will over lay on the original image.
        case overlay(ResizingMode)
        /// Indicates the images to merge will lay on the horizontal stack.
        case horizontally(Horizontal, ResizingMode)
        /// Indicates the images to merge will lay on the vertical stack.
        case vertically(Vertical, ResizingMode)
    }
    /// Creates a new instance of UIImage with the given images merged to the receiver by using the merging mode.
    /// The same direction resizing mode of the horizontal or vertical merging mode act just like the overlay mode.
    /// Animated image supported. Each frame of the animated image will merge with the given images if animatable,
    ///
    /// - Parameter images: A collection of instance of UIImage to merge with.
    /// - Parameter mode  : A value defined in the type `MergingMode` used to calculate the rectangle area of the images.
    ///
    /// - Returns: A new image object with all the images merged using the specific merging mode.
    public func merge(with images: [UIImage], using mode: MergingMode) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.merge(with: images, using: mode) } }), duration: duration) }
        
        var resultImage: UIImage = self
        images.forEach { (image) in autoreleasepool{
            var resultRect = CGRect(origin: .zero, size: resultImage.size)
            var pageRect   = CGRect(origin: .zero, size: image.size)
            var imageRect  : CGRect = .zero
            switch mode {
            case .overlay(let resizing):
                imageRect = CGRect(origin: .zero, size: CGSize(width: max(resultRect.width, pageRect.width), height: max(resultRect.height, pageRect.height)))
                switch resizing {
                case .scaleToFill:
                    resultRect = imageRect
                    pageRect   = imageRect
                case .scaleAspectFit:
                    resultRect = _rect(scales: resultRect, toFit: imageRect)
                    pageRect   = _rect(scales: pageRect  , toFit: imageRect)
                case .scaleAspectFill:
                    resultRect = _rect(scales: resultRect, toFill: imageRect)
                    pageRect   = _rect(scales: pageRect  , toFill: imageRect)
                case .center:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 0.5
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 0.5
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 0.5
                case .top:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 0.5
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 0.5
                case .bottom:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 0.5
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 0.5
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 1.0
                case .left:
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 0.5
                case .right:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 1.0
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 0.5
                case .topLeft: break
                case .topRight:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 1.0
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 1.0
                case .bottomLeft:
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 1.0
                case .bottomRight:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 1.0
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 1.0
                }
                resultImage = resultImage._merge(with: image, size: imageRect.size, beginsRect: resultRect, endsRect: pageRect)
            case .horizontally(let horizontal, let resizing):
                imageRect.size.width = resultRect.width + pageRect.width
                if horizontal == .leftToRight { pageRect.origin.x = resultRect.width } else {
                    resultRect.origin.x = pageRect.width
                }
                switch resizing {
                case .scaleToFill:
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.size.height = imageRect.height
                    pageRect.size.height   = imageRect.height
                case .scaleAspectFit : fallthrough
                case .scaleAspectFill:
                    let scalesToFitResult  = _rect(equalHeightScales: horizontal == .leftToRight ? resultRect : pageRect, toFit: horizontal == .leftToRight ? pageRect : resultRect)
                    resultRect             = horizontal == .leftToRight ? scalesToFitResult.0 : scalesToFitResult.1
                    pageRect               = horizontal == .leftToRight ?  scalesToFitResult.1: scalesToFitResult.0
                    imageRect.size.width   = scalesToFitResult.0.width + scalesToFitResult.1.width
                    imageRect.size.height  = max(scalesToFitResult.0.height, scalesToFitResult.1.height)
                case .center:
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 0.5
                case .top:
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                case .bottom:
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 1.0
                case .left:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    if horizontal == .leftToRight { pageRect.origin.x =               0.0 } else {
                       resultRect.origin.x =                                          0.0
                    }
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 0.5
                case .right:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.x    = (imageRect.width - resultRect.width)   * 1.0
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.x      = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 0.5
                case .topLeft:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    if horizontal == .leftToRight { pageRect.origin.x =               0.0 } else {
                       resultRect.origin.x =                                          0.0
                    }
                case .topRight:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.x    = (imageRect.width - resultRect.width)   * 1.0
                    pageRect.origin.x      = (imageRect.width  - pageRect.width )   * 1.0
                case .bottomLeft:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    if horizontal == .leftToRight { pageRect.origin.x =               0.0 } else {
                       resultRect.origin.x =                                          0.0
                    }
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 1.0
                case .bottomRight:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.x    = (imageRect.width - resultRect.width)   * 1.0
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x      = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 1.0
                }
                resultImage = resultImage._merge(with: image, size: imageRect.size, beginsRect: resultRect, endsRect: pageRect)
            case .vertically(let vertical, let resizing):
                imageRect.size.height = resultRect.height + pageRect.height
                if vertical == .topToBottom { pageRect.origin.y = resultRect.height } else {
                    resultRect.origin.y = pageRect.height
                }
                switch resizing {
                case .scaleToFill:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    resultRect.size.width = imageRect.width
                    pageRect.size.width   = imageRect.width
                case .scaleAspectFit : fallthrough
                case .scaleAspectFill:
                    let scalesToFitResult = _rect(equalWidthScales: vertical == .topToBottom ? resultRect : pageRect, toFit: vertical == .topToBottom ? pageRect : resultRect)
                    resultRect            = vertical == .topToBottom ? scalesToFitResult.0 : scalesToFitResult.1
                    pageRect              = vertical == .topToBottom ? scalesToFitResult.1 : scalesToFitResult.0
                    imageRect.size.width  = max(scalesToFitResult.0.width, scalesToFitResult.1.width)
                    imageRect.size.height = scalesToFitResult.0.height + scalesToFitResult.1.height
                case .center:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    resultRect.origin.x   = (imageRect.width - resultRect.width)   * 0.5
                    pageRect.origin.x     = (imageRect.width - pageRect.width  )   * 0.5
                case .top:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.x   = (imageRect.width - resultRect.width)   * 0.5
                    pageRect.origin.x     = (imageRect.width - pageRect.width  )   * 0.5
                    if vertical == .topToBottom { pageRect.origin.y =                0.0 } else {
                       resultRect.origin.y =                                         0.0
                    }
                case .bottom:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.x   = (imageRect.width - resultRect.width  ) * 0.5
                    resultRect.origin.y   = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x     = (imageRect.width - pageRect.width    ) * 0.5
                    pageRect.origin.y     = (imageRect.height - pageRect.height  ) * 1.0
                case .left:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                case .right:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    resultRect.origin.x   = (imageRect.width - resultRect.width )  * 1.0
                    pageRect.origin.x     = (imageRect.width  - pageRect.width  )  * 1.0
                case .topLeft:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    if vertical == .topToBottom { pageRect.origin.y =                0.0 } else {
                       resultRect.origin.y =                                         0.0
                    }
                case .topRight:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.x   = (imageRect.width - resultRect.width)   * 1.0
                    pageRect.origin.x     = (imageRect.width  - pageRect.width )   * 1.0
                    if vertical == .topToBottom { pageRect.origin.y =                0.0 } else {
                       resultRect.origin.y =                                         0.0
                    }
                case .bottomLeft:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.y   = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.y     = (imageRect.height - pageRect.height  ) * 1.0
                case .bottomRight:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.x   = (imageRect.width - resultRect.width)   * 1.0
                    resultRect.origin.y   = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x     = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y     = (imageRect.height - pageRect.height  ) * 1.0
                }
                resultImage = resultImage._merge(with: image, size: imageRect.size, beginsRect: resultRect, endsRect: pageRect)
            }
        } }
        return resultImage
    }
    
    private func _merge(with image: UIImage, size: CGSize, beginsRect: CGRect, endsRect: CGRect) -> UIImage! {
        guard let cgImage = _makeCgImage(), let mergingCgImage = image._makeCgImage() else { return nil }
        var mergedImage: UIImage! = self
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let transform = CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0.0, y: -size.height)
        context.concatenate(transform)
        
        context.draw(cgImage, in: beginsRect.applying(transform))
        context.draw(mergingCgImage, in: endsRect.applying(transform))
        mergedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        return mergedImage
    }
    
    private func _rect(equalHeightScales rect1: CGRect, toFit rect2: CGRect) -> (CGRect, CGRect) {
        var resultRect1 = rect1
        var resultRect2 = rect2
        
        if resultRect1.height >= resultRect2.height {
            let ratio = resultRect1.height / resultRect2.height
            resultRect2.size.width  = resultRect2.width * ratio
            resultRect2.size.height = resultRect1.height
        } else {
            let ratio = resultRect2.height / resultRect1.height
            resultRect1.size.width  = resultRect1.width * ratio
            resultRect1.size.height = resultRect2.height
        }
        resultRect1.origin.y = 0.0
        resultRect2.origin.y = 0.0
        resultRect2.origin.x = resultRect1.width
        
        return (resultRect1, resultRect2)
    }
    
    private func _rect(equalWidthScales rect1: CGRect, toFit rect2: CGRect) -> (CGRect, CGRect) {
        var resultRect1 = rect1
        var resultRect2 = rect2
        
        if resultRect1.width >= resultRect2.width {
            let ratio = resultRect1.width / resultRect2.width
            resultRect2.size.height = resultRect2.height * ratio
            resultRect2.size.width  = resultRect1.width
        } else {
            let ratio = resultRect2.width / resultRect1.width
            resultRect1.size.height = resultRect1.height * ratio
            resultRect1.size.width  = resultRect2.width
        }
        resultRect1.origin.x = 0.0
        resultRect2.origin.x = 0.0
        resultRect2.origin.y = resultRect1.height
        
        return (resultRect1, resultRect2)
    }
    
    private func _rect(scales rect1: CGRect, toFit rect2: CGRect) -> CGRect {
        let maxRect = CGRect(origin: .zero, size: CGSize(width: max(rect1.width, rect2.width), height: max(rect1.height, rect2.height)))
        
        var resultRect = rect1
        
        if resultRect.height >= resultRect.width { // Aspect fit height.
            let ratio = maxRect.height / resultRect.height
            resultRect.size.width  = resultRect.width * ratio
            resultRect.size.height = maxRect.height
            resultRect.origin.x    = (maxRect.width - resultRect.width) * 0.5
        } else {
            let ratio = maxRect.width / resultRect.width
            resultRect.size.height = resultRect.height * ratio
            resultRect.size.width  = maxRect.width
            resultRect.origin.y    = (maxRect.height - resultRect.height) * 0.5
        }
        
        return resultRect
    }
    
    private func _rect(scales rect1: CGRect, toFill rect2: CGRect) -> CGRect {
        let maxRect = CGRect(origin: .zero, size: CGSize(width: max(rect1.width, rect2.width), height: max(rect1.height, rect2.height)))
        
        var resultRect = rect1
        
        if resultRect.height < resultRect.width { // Aspect fill width.
            let ratio = maxRect.height / resultRect.height
            resultRect.size.width  = resultRect.width * ratio
            resultRect.size.height = maxRect.height
            resultRect.origin.x    = (maxRect.width - resultRect.width) * 0.5
        } else {
            let ratio = maxRect.width / resultRect.width
            resultRect.size.height = resultRect.height * ratio
            resultRect.size.width  = maxRect.width
            resultRect.origin.y    = (maxRect.height - resultRect.height) * 0.5
        }
        
        return resultRect
    }
}

// MARK: - Vector.

extension UIImage {
    /// Creates an image from any instances of `String` with the specific font and tint color in points.
    /// The `String` contents' count should not be zero. If so, nil will be returned.
    ///
    /// - Parameter content: An instance of `String` to generate `UIImage` with.
    /// - Parameter font   : The font used to draw image with. Using `.systemFont(ofSize: 17)` by default.
    /// - Parameter color  : The color used to fill image with. Using `.black` by default.
    ///
    /// - Returns: A `String` contents image created with specific font and color.
    public class func image(from content: String, using font: UIFont = .systemFont(ofSize: 17), tint color: UIColor = .black) -> UIImage! {
        let ligature = NSMutableAttributedString(string: content)
        ligature.setAttributes([(kCTLigatureAttributeName as String): 2, (kCTFontAttributeName as String): font], range: NSMakeRange(0, content.lengthOfBytes(using: .utf8)))
        
        var imageSize    = ligature.size()
        imageSize.width  = ceil(imageSize.width)
        imageSize.height = ceil(imageSize.height)
        guard !imageSize.equalTo(.zero) else { return nil }
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        ligature.draw(at: .zero)
        guard let cgImage = UIGraphicsGetImageFromCurrentImageContext()?._makeCgImage() else { return nil }
        
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0.0, y: -imageSize.height)
        let rect = CGRect(origin: .zero, size: imageSize)
        context.clip(to: rect, mask: cgImage)
        color.setFill()
        context.fill(rect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    /// Creates an image from any instances of `CGPDFDocument` with the specific size and tint color in points.
    ///
    /// - Parameter pdf  : An instance of `CGPDFDocument` to generate `UIImage` with.
    /// - Parameter size : The size used to draw image fitting with in points.
    /// - Parameter color: The color used to fill image with. Using nil by default.
    ///
    /// - Returns: A `CGPDFDocument` contents image created with specific size and color.
    public class func image(fromPDFDocument pdf: CGPDFDocument, scalesToFit size: CGSize, pageCountLimits: Int, tint color: UIColor? = nil) -> UIImage! {
        var pageIndex = 1
        var image: UIImage!
        while pageIndex <= min(pdf.numberOfPages, pageCountLimits), let page = pdf.page(at: pageIndex) { autoreleasepool {
            let mediaRect = page.getBoxRect(.cropBox)
            // Calculate the real fits size of the image.
            var imageSize = mediaRect.size
            if  imageSize.height < size.height && size.height != CGFloat.greatestFiniteMagnitude {
                imageSize.width = (size.height / imageSize.height * imageSize.width).rounded()
                imageSize.height = size.height
            }
            if  imageSize.width < size.width && size.width != CGFloat.greatestFiniteMagnitude {
                imageSize.height = (size.width / imageSize.width  * imageSize.height).rounded()
                imageSize.width = size.width
            }
            if  imageSize.height > size.height {
                imageSize.width = (size.height / imageSize.height * imageSize.width).rounded()
                imageSize.height = size.height
            }
            if  imageSize.width > size.width {
                imageSize.height = (size.width / imageSize.width  * imageSize.height).rounded()
                imageSize.width  =  size.width
            }
            // Draw the current page image.
            UIGraphicsBeginImageContextWithOptions(imageSize, false, UIScreen.main.scale)
            guard let context = UIGraphicsGetCurrentContext() else { UIGraphicsEndImageContext(); return }
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0.0, y: -imageSize.height)
            let scale = min(imageSize.width / mediaRect.width, imageSize.height / mediaRect.height)
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(page)
            let currentImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            // Merge the former and current page image.
            if let resultImage = image, let pageImage = currentImage {
                image = resultImage.merge(with: [pageImage], using: .vertically(.topToBottom, .scaleAspectFill))
            } else {
                image = currentImage
            }
            
            pageIndex += 1
        } }
        
        if let tintColor = color, let cgImage = image._makeCgImage() {
            UIGraphicsBeginImageContextWithOptions(image.size, false, UIScreen.main.scale)
            defer { UIGraphicsEndImageContext() }
            guard let context = UIGraphicsGetCurrentContext() else { return image }
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0.0, y: -image.size.height)
            let rect = CGRect(origin: .zero, size: image.size)
            context.clip(to: rect, mask: cgImage)
            tintColor.setFill()
            context.fill(rect)
            image = UIGraphicsGetImageFromCurrentImageContext()
        }
        return image
    }
    public class func image(fromPDFData pdfData: Data, scalesToFit size: CGSize, pageCountLimits: Int = 12, tint color: UIColor? = nil) -> UIImage! {
        // Creates the pdg document from the data.
        guard let dataProvider = CGDataProvider(data: pdfData as CFData) else { return nil }
        guard let pdf = CGPDFDocument(dataProvider) else { return nil }
        
        return image(fromPDFDocument: pdf, scalesToFit: size, pageCountLimits: pageCountLimits, tint: color)
    }
    public class func image(fromPDFUrl pdfUrl: URL, scalesToFit size: CGSize, pageCountLimits: Int = 12, tint color: UIColor? = nil) -> UIImage! {
        // Creates the pdg document from the url.
        guard let pdf = CGPDFDocument(pdfUrl as CFURL) else { return nil }
        
        return image(fromPDFDocument: pdf, scalesToFit: size, pageCountLimits: pageCountLimits, tint: color)
    }
    public class func image(fromPDFAtPath pdfPath: String, scalesToFit size: CGSize, pageCountLimits: Int = 12, tint color: UIColor? = nil) -> UIImage! {
        return image(fromPDFUrl: URL(fileURLWithPath: pdfPath), scalesToFit: size, pageCountLimits: pageCountLimits, tint: color)
    }
    public class func image(fromPDFNamed pdfName: String, scalesToFit size: CGSize, pageCountLimits: Int = 12, tint color: UIColor? = nil) -> UIImage! {
        guard let path = Bundle.main.path(forResource: pdfName, ofType: "pdf") else { return nil }
        
        return image(fromPDFAtPath: path, scalesToFit: size, pageCountLimits: pageCountLimits, tint: color)
    }
}

// MARK: - Orientation.

extension UIImage {
    /// Creates a copy of the receiver image with orientation fixed if the image orientation
    /// is not the `.up`. Animated image supported.
    public var orientationFixed: UIImage! {
        guard imageOrientation != .up else { return self }
        
        let transform: CGAffineTransform = .identity
        switch imageOrientation {
        case .down: fallthrough
        case .downMirrored:
            transform.translatedBy(x: scaledWidth, y: scaledHeight).rotated(by: CGFloat.pi)
        case .left: fallthrough
        case .leftMirrored:
            transform.translatedBy(x: scaledWidth, y: 0.0).rotated(by: CGFloat.pi * 0.5)
        case .right: fallthrough
        case .rightMirrored:
            transform.translatedBy(x: 0.0, y: scaledHeight).rotated(by: -CGFloat.pi * 0.5)
        default: break
        }
        
        switch imageOrientation {
        case .upMirrored: fallthrough
        case .downMirrored:
            transform.translatedBy(x: scaledWidth, y: 0.0).scaledBy(x: -1.0, y: 1.0)
        case .leftMirrored: fallthrough
        case .rightMirrored:
            transform.translatedBy(x: scaledHeight, y: 0.0).scaledBy(x: -1.0, y: 0.0)
        default: break
        }
        
        guard let cgImage = self._makeCgImage(), let colorSpace = cgImage.colorSpace, let context = CGContext(data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: cgImage.bitmapInfo.rawValue) else { return nil }
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left: fallthrough
        case .leftMirrored: fallthrough
        case .right: fallthrough
        case .rightMirrored:
            context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: scaledHeight, height: scaledWidth)))
        default:
            context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: scaledWidth, height: scaledHeight)))
        }
        guard let image = context.makeImage() else { return nil }
        
        return UIImage(cgImage: image, scale: scale, orientation: .up)
    }
    /// Creates and returns a copy of the receiver image with flipped vertically.
    /// Animated image supported.
    public var verticallyFlipped: UIImage! { return _flip(horizontally: false) }
    /// Creates and returns a copy of the receiver image with flipped horizontally.
    /// Animated image supported.
    public var horizontallyFlipped: UIImage! { return _flip(horizontally: true) }
    /// Creates a copy of the receiver image by the given angle. Animated image supported.
    /// 
    /// - Parameter angle: A float value indicates the angle to rotate by.
    ///
    /// - Returns: A new image with the given angle rotated.
    public func rotate(by angle: CGFloat) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.rotate(by: angle) } }), duration: duration) }
        
        // Calculate the size of the rotated view's containing box for our drawing space.
        let transform = CGAffineTransform(rotationAngle: angle)
        let rotatedBox = CGRect(origin: .zero, size: scaledSize).applying(transform)
        // Create the bitmap context.
        UIGraphicsBeginImageContextWithOptions(rotatedBox.size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let cgImage = self._makeCgImage(), let context = UIGraphicsGetCurrentContext() else { return nil }
        // Move the origin to the middle of the image so we will rotate and scale around the center.
        context.translateBy(x: rotatedBox.width * 0.5, y: rotatedBox.height * 0.5)
        // Rotate the image context.
        context.rotate(by: angle)
        // Now, draw the rotated/scaled image into the context.
        context.scaleBy(x: 1.0, y: -1.0)
        
        context.draw(cgImage, in: CGRect(x: -scaledWidth * 0.5, y: -scaledHeight * 0.5, width: scaledWidth, height: scaledHeight))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func _flip(horizontally: Bool) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img._flip(horizontally: horizontally) } }), duration: duration) }
        
        let rect = CGRect(origin: .zero, size: scaledSize)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let cgImage = self._makeCgImage(), let context = UIGraphicsGetCurrentContext() else { return nil }
        context.clip(to: rect)
        if horizontally {
            context.rotate(by: CGFloat.pi)
            context.translateBy(x: -rect.width, y: -rect.height)
        }
        context.draw(cgImage, in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Color.

extension UIImage {
    /// Creates and returns a copy of the receiver image by changing the color space to gray.
    public var grayed: UIImage! {
        guard let cgImage = self._makeCgImage() else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: scaledSize))
        guard let image = context.makeImage() else { return nil }
        
        return UIImage(cgImage: image, scale: scale, orientation: imageOrientation)
    }
    /// Creates a copy of the receiver image with the given color filled same as the system's
    /// temple image with tint color.
    ///
    /// - Parameter color: A color used to fill the opaque feild.
    ///
    /// - Returns: A new image with the given color filled.
    public func tint(with color: UIColor) -> UIImage! {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let cgImage = self._makeCgImage(), let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: 0.0, y: scaledHeight)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setBlendMode(.normal)
        let rect = CGRect(origin: .zero, size: size)
        context.clip(to: rect, mask: cgImage)
        color.setFill()
        context.fill(rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    /// Creates a new image with the given color filled at the specific size.
    ///
    /// - Parameter color: A color used to fill the rectangle.
    /// - Parameter size : A value of `CGSize` indicates the rectangle feild of the image.
    ///
    /// - Returns: A pure-colored image with the specidic size.
    public class func image(filling color: UIColor, size: CGSize = CGSize(width: 1.0, height: 1.0)) -> UIImage! {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        color.setFill()
        context.fill(rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    /// Calculates and fetchs the color space info at a given point laid on the coordinate of the image.
    ///
    /// - Parameter point: The point to calculate color at.
    /// - Parameter scale: A scale value indicates the calculating target in pixel or point.
    ///
    /// - Returns: The color of the image at the specific point or pixel.
    public func color(at point: CGPoint, scale: CGFloat) -> UIColor! {
        let rect = CGRect(origin: .zero, size: size)
        guard let cgImage = self._makeCgImage(), rect.contains(point) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = pow(scale, 2.0)
        let bytesPerRow   = Int(bytesPerPixel) * cgImage.width
        let bitsPerComponent = 8
        guard let context = CGContext(data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        
        context.draw(cgImage, in: rect)
        
        guard let rawData = context.data else { return nil }
        let bytesIndex = bytesPerRow * Int(point.y) + Int(bytesPerPixel) * Int(point.x)
        let red   = Float(rawData.load(fromByteOffset: bytesIndex + 0, as: UInt8.self)) / 255.0
        let green = Float(rawData.load(fromByteOffset: bytesIndex + 1, as: UInt8.self)) / 255.0
        let blue  = Float(rawData.load(fromByteOffset: bytesIndex + 2, as: UInt8.self)) / 255.0
        let alpha = Float(rawData.load(fromByteOffset: bytesIndex + 2, as: UInt8.self)) / 255.0
        
        return UIColor(colorLiteralRed: red, green: green, blue: blue, alpha: alpha)
    }
    /// Calculates and fetchs the major colors of the receiver image with the accuracy length and
    /// a color to ignore with. High accuracy will need high performance of the CPU. Cliens should
    /// be careful with.
    ///
    /// - Parameter length : A float value indicates the scaled size to generate a thumbnail to scales
    ///                      to fit with.
    /// - Parameter ignored: A color to ignored by calculate the HUE mode.
    ///
    /// - Returns: A collection of colors indicates the major colors of the image sorted descending.
    public func majorColors(accuracy length: CGFloat = 12.0, ignored: UIColor = UIColor.clear) -> [UIColor] {
        guard length > 0.0 else { return [] }
        
        let bitmapInfo = CGBitmapInfo(rawValue: (0x0 << 0xc)|CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let thumbnailed  = thumbnail(scalesToFit: length) else { return [] }
        guard let thumbnailedCgImage = thumbnailed._makeCgImage() else { return [] }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: nil, width: thumbnailedCgImage.width, height: thumbnailedCgImage.height, bitsPerComponent: 8, bytesPerRow: thumbnailedCgImage.width*4, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return [] }
        
        let rect = CGRect(origin: .zero, size: thumbnailed.size)
        context.draw(cgImage!, in: rect)
        
        guard let data = context.data else { return [] }
        
        let countedSet = NSCountedSet(capacity: thumbnailedCgImage.width * thumbnailedCgImage.height)
        
        for x in 0x0 ..< thumbnailedCgImage.width {
            for y in 0x0 ..< thumbnailedCgImage.height {
                
                let offset = 0x4 * x * y
                
                let red   = data.load(fromByteOffset: offset+0x0, as: UInt8.self)
                let green = data.load(fromByteOffset: offset+0x1, as: UInt8.self)
                let blue  = data.load(fromByteOffset: offset+0x2, as: UInt8.self)
                let alpha = data.load(fromByteOffset: offset+0x3, as: UInt8.self)
                
                let counted = [red, green, blue, alpha]/*.map{ $0==0xff ? $0/0x2 : $0}*/
                
                countedSet.add(counted)
            }
        }
        
        func _count(_ objectInCountedSet: Any) -> Int { return countedSet.count(for: objectInCountedSet) }
        func _UIColor(_ comp: Any) -> UIColor {
            
            let components = comp as! [AnyObject]
            
            return UIColor(colorLiteralRed: Float((components[0x0] as AnyObject).integerValue)/Float(0xff),
                           green:           Float((components[0x1] as AnyObject).integerValue)/Float(0xff),
                           blue:            Float((components[0x2] as AnyObject).integerValue)/Float(0xff),
                           alpha:           Float((components[0x3] as AnyObject).integerValue)/Float(0xff))
        }
        
        var colors = countedSet.sorted{ _count($0) > _count($1) }.map { _UIColor($0) }
        
        while colors.first?.matchs(ignored) ?? false {
            colors.removeFirst()
        }
        
        return colors
    }
}

// MARK: - AnimatedImage.

extension UIImage {
    /// Indicates whether the image is animated image contains multiple images.
    public var animatable: Bool { return images?.count ?? 0 > 1 }
    /// Creates a `GIF` animated image with the given data by get the frame info of the image source.
    ///
    /// - Parameter data : A data object that image source reading from.
    /// - Parameter scale: The scale factor of the source image.
    ///
    /// - Returns: An instance of animated image contains multiple frame of images.
    public class func gif(_ data: Data, scale: CGFloat = 1.0) -> UIImage! {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let imagesCount = CGImageSourceGetCount(imageSource)
        
        var animatedImage: UIImage!
        if imagesCount > 1 {
            var images  : [UIImage]    = []
            var duration: TimeInterval = 0.0
            for index in 0..<imagesCount {
                guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else { continue }
                images.append(UIImage(cgImage: cgImage, scale: scale, orientation: .up))
                // Calculate durations.
                guard let frameProps = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as NSDictionary? else { continue }
                guard let gifProps   = frameProps[kCGImagePropertyGIFDictionary as String] as? NSDictionary else { continue }
                
                var frameDuration: TimeInterval = 0.1
                if let delayTimeUnclampedProp = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval {
                    frameDuration = delayTimeUnclampedProp
                } else if let delayTimeProp = gifProps[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
                    frameDuration = delayTimeProp
                }
                // Many annoying ads specify a 0 duration to make an image flash as quickly as possible.
                // We follow Firefox's behavior and use a duration of 100 ms for any frames that specify
                // a duration of <= 10 ms. See <rdar://problem/7689300> and <http://webkit.org/b/36082>
                // for more information.
                frameDuration = max(frameDuration, 0.1)
                duration += frameDuration
            }
            
            if duration == 0.0 { duration = 0.1 * Double(imagesCount) }
            
            animatedImage = UIImage.animatedImage(with: images, duration: duration)
        } else {
            animatedImage = UIImage(data: data)
        }
        
        return animatedImage
    }
    /// Creates a `GIF` animated image with the contents of a `URL`.
    ///
    /// - parameter url: The `URL` to read image source data.
    /// - parameter options: Options for the read operation. Default value is `[]`.
    ///
    /// - Returns: An instance of animated image contains multiple frame of images.
    public class func gif(contentsOf url: URL, options: Data.ReadingOptions = [], scale: CGFloat = 1.0) -> UIImage! {
        guard let data = try? Data(contentsOf: url, options: options) else {return nil }
        return gif(data, scale: scale)
    }
    /// Creates a `GIF` animated image with the name path extension in a `Bundle`.
    ///
    /// - parameter name: The name to load data from.
    /// - parameter bundle: The bundle that file data locate in.
    ///
    /// - Returns: An instance of animated image contains multiple frame of images.
    public class func gif(named name: String, `in` bundle: Bundle = .main) -> UIImage! {
        var fileName: String = name; var scale: CGFloat = 1.0
        switch UIScreen.main.scale {
        case 3.0: //@3x
            fileName += "@3x"; scale = 3.0
        case 2.0: //@2x
            fileName += "@2x"; scale = 2.0
        default: // @1x
            fileName += "@1x"; scale = 1.0
        }
        if let path = bundle.path(forResource: fileName, ofType: "gif"), let image = gif(contentsOf: URL(fileURLWithPath: path), scale: scale) {
            return image
        } else {
            guard let path = bundle.path(forResource: name, ofType: "gif") else { return nil }
            return gif(contentsOf: URL(fileURLWithPath: path))
        }
    }
}

// MARK : - Private.

fileprivate extension UIColor {
    fileprivate func matchs(_ color: UIColor) -> Bool {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        var ohue: CGFloat = 0.0
        var osaturation: CGFloat = 0.0
        var obrightness: CGFloat = 0.0
        var oalpha: CGFloat = 0.0
        
        color.getHue(&ohue, saturation: &osaturation, brightness: &obrightness, alpha: &oalpha)
        
        let flag = pow(pow(hue-ohue, 2)+pow(saturation-osaturation, 2)+pow(brightness-obrightness, 2)+pow(alpha-oalpha, 2), 0.5)
        // print(flag)
        
        if flag <= 0.1 {
            return true
        } else {
            return false
        }
    }
}

// MARK: - CoreImage.

extension UIImage {
    /// A type representing a core image context using automatic rendering by choosing the appropriate or best available CPU or GPU rendering technology based on the current device.
    fileprivate struct _AutomaticCIContext {
        lazy var context: CIContext! = { () -> CIContext! in
            let date = Date()
            let context = CIContext()
            print("Context creating cost timing: \(Date().timeIntervalSince(date))")
            return CIContext()
        }()
    }
    /// A type representing a core image context using the real-time rendering with Metal.
    fileprivate struct _MetalBasedCIContext {
        lazy var context: CIContext! = { () -> CIContext! in
            let date = Date()
            guard let device = MTLCreateSystemDefaultDevice() else { return _openGLESCIContext.context }
            print("Context creating cost timing: \(Date().timeIntervalSince(date))")
            return CIContext(mtlDevice: device)
        }()
    }
    /// A type representing a core image context using the real-time rendering with OpenGL ES.
    fileprivate struct _OpenGLESBasedCIContext {
        lazy var context: CIContext! = { () -> CIContext! in
            let date = Date()
            guard let eaglContext = EAGLContext(api: .openGLES3) else { return nil }
            print("Context creating cost timing: \(Date().timeIntervalSince(date))")
            return CIContext(eaglContext: eaglContext)
        }()
    }
}

private var _autoCIContext     = UIImage._AutomaticCIContext()
private var _metalCIContext    = UIImage._MetalBasedCIContext()
private var _openGLESCIContext = UIImage._OpenGLESBasedCIContext()

/// Get the context of core image with the given render destination.
private func _ciContext(of dest: UIImage.RenderDestination) -> CIContext! {
    switch dest {
    case .auto:
        return _autoCIContext.context
    case .gpu(let gpu):
        switch gpu {
        case .metal:
            return _metalCIContext.context
        case .openGLES:
            return _openGLESCIContext.context
        }
    default: return nil
    }
}

extension UIImage {
    /// Returns the underlying ci-image if CoreImage-Based.
    ///
    /// Otherwise returns the ci-image initialized with the bitmap cg-image.
    ///
    /// Otherwise returns the ci-image based on the receiver image.
    fileprivate func _makeCiImage() -> CIImage! {
        var ciImage: CIImage! = nil
        if let underlyingCiImage = self.ciImage {
            ciImage = underlyingCiImage
        } else if let cgImage = self.cgImage {
            ciImage = CIImage(cgImage: cgImage)
        } else if let _ciImage = CIImage(image: self) {
            ciImage = _ciImage
        } else if let data = UIImageJPEGRepresentation(self, 1.0) {
            ciImage = CIImage(data: data)
        }
        return ciImage
    }
    /// Returns the underlying cg-image if CoreGraphics-Based.
    ///
    /// Otherwise returns the cg-image rendered with the ci image.
    /// 
    /// Otherwise returns the cg-image initialized with the jpeg data.
    fileprivate func _makeCgImage() -> CGImage! {
        var cgImage: CGImage! = nil
        if let underlyingCgImage = self.cgImage {
            cgImage = underlyingCgImage
        } else if let ciImage = self.ciImage, let context = _autoCIContext.context, let renderedCgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            cgImage = renderedCgImage
        } else {
            guard let data = UIImageJPEGRepresentation(self, 1.0) as CFData?, let dataProvider = CGDataProvider(data: data) else { return nil }
            cgImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }
        return cgImage
    }
}
