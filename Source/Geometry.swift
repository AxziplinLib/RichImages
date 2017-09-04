//
//  Geometry.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage
import CoreGraphics

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
    public func rotate(by angle: CGFloat, rendering dest: RenderDestination = .cpu) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.rotate(by: angle) } }), duration: duration) }
        
        // Calculate the size of the rotated view's containing box for our drawing space.
        let transform = CGAffineTransform(rotationAngle: -angle)
        let rotatedBox = CGRect(origin: .zero, size: size).applying(transform)
        
        var fallthroughToCpu = false
        switch dest {
        case .auto:
            fallthroughToCpu = true
            fallthrough
        case .gpu(_):
            guard let ciImage = _makeCiImage()?.applying(CGAffineTransform(rotationAngle: angle)) else {
                return fallthroughToCpu ? rotate(by: angle, rendering: dest) : nil
            }
            guard let ciContext = _ciContext(at: dest) else { return fallthroughToCpu ? rotate(by: angle, rendering: dest): nil }
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return fallthroughToCpu ? rotate(by: angle, rendering: dest) : nil }
            
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        default:
            // Create the bitmap context.
            UIGraphicsBeginImageContextWithOptions(rotatedBox.size, false, scale)
            defer { UIGraphicsEndImageContext() }
            guard let cgImage = self._makeCgImage(), let context = UIGraphicsGetCurrentContext() else { return nil }
            // Move the origin to the middle of the image so we will rotate and scale around the center.
            context.translateBy(x: rotatedBox.width * 0.5, y: rotatedBox.height * 0.5)
            // Rotate the image context.
            context.rotate(by: -angle)
            // Now, draw the rotated/scaled image into the context.
            context.scaleBy(x: 1.0, y: -1.0)
            
            context.draw(cgImage, in: CGRect(x: -size.width * 0.5, y: -size.width * 0.5, width: size.width, height: size.width))
            return UIGraphicsGetImageFromCurrentImageContext()
        }
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
