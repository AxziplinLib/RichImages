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
    public var  cornered: UIImage! { return makeCornered() }
    /// Craetes an copy of the receiver with critical rounding in points with the given render destination.
    /// Animated image supported.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image rounding processing.
    /// - Returns: Returns an copy of the receiver with critical rounded.
    public func makeCornered(_ option: RichImage.RenderOption = .cpu) -> UIImage! { return round(by: min(size.width, size.height) * 0.5, option: option) }
    /// Creates a copy of this image with rounded corners in points. Animated image supported. Animated image supported.
    ///
    /// - Parameter radius: The width of the corner drawing. The value must not be negative.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image rounding processing.
    ///
    /// - Returns: An image with rounded corners.
    public func round(by radius: CGFloat, option: RichImage.RenderOption = .cpu) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.round(by: radius, option: option) } }), duration: duration) }
        // Early fatal checking.
        guard radius >= 0.0/* && borderWidth >= 0.0 */else { return nil }
        // Scales points to pxiels.
        let scaledRadius = radius * scale
        
        var fallthroughToCpu: Bool = false
        switch option.dest {
        case .auto:
            fallthroughToCpu = true
            fallthrough
        case .gpu(_):
            if let ciImage = _makeCiImage()?.round(by: scaledRadius), let image = type(of: self).make(ciImage, scale: scale, orientation: imageOrientation, option: option) {
                return image
            }
            return fallthroughToCpu ? round(by: radius, option: .cpu(option.quality)) : nil
        default:
            let scaledBorderWidth: CGFloat = /*borderWidth  * scale*/ 0.0
            
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
            if scaledRadius == 0 {
                context.addRect(roundedRect)
            } else {
                context.saveGState()
                context.translateBy(x: roundedRect.minX, y: roundedRect.minY)
                context.scaleBy(x: scaledRadius, y: scaledRadius)
                
                let wr = roundedRect.width  / scaledRadius
                let hr = roundedRect.height / scaledRadius
                
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
    /// Creates a copy of the receiver image by the given angle. Animated image supported.
    ///
    /// - Parameter angle: A float value indicates the angle to rotate by.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image rotating processing.
    ///
    /// - Returns: A new image with the given angle rotated.
    public func rotate(by angle: CGFloat, option: RichImage.RenderOption = .cpu) -> UIImage! {
        return applying(CGAffineTransform(rotationAngle: angle), option: option)
    }
    /// Creates and returns a copy of the receiver image with flipped horizontally with a specific render option.
    /// Animated image supported.
    ///
    /// - Parameter horizontally: True to flip horizontally, otherwise vertically.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image rotating processing.
    ///
    /// - Returns: A copy of the receiver by flipping according to the direction and the given option.
    public func flip(horizontally: Bool, option: RichImage.RenderOption = .cpu) -> UIImage! {
        return applying(CGAffineTransform(scaleX: horizontally ? -1.0 : 1.0, y: horizontally ? 1.0 : -1.0), option: option)
    }
}

extension UIImage {
    /// Creates a copy of the receiver by applying the given transform matrix and render option. Animated image supported.
    ///
    /// The copy image by applying the transform matrix will be rendered into the same bounds as the recevier image.
    ///
    /// - Note: Clients may get the diffrent result between `.cpu` and `gpu` when applying some transform such as 
    ///         translation because of the different principle of the `.cpu` and `.gpu`. So be careful with the
    ///         render option to get the result image.
    /// - scale      : Same results of using `.cpu` or `gpu`.
    /// - rotation   : Same results of using `.cpu` or `gpu`.
    /// - translation: Affect `.cpu` only.
    ///
    /// - Parameter matrix: A value of `CGAffineTransform` to define the transform of the copy of the receiver image.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image render processing.
    ///
    /// - Returns: A copy of the receiver by applying the given tranform matrix.
    public func applying(_ matrix: CGAffineTransform, option: RichImage.RenderOption = .cpu) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.applying(matrix, option: option) } }), duration: duration) }
        
        let rect           = CGRect(origin: .zero, size: size)
        let transformedBox = rect.applying(matrix)
        
        var fallthroughToCpu = false
        switch option.dest {
        case .auto:
            fallthroughToCpu = true
            fallthrough
        case .gpu(_):
            if let image = applying("CIAffineTransform", inputParameters: ["inputTransform": matrix], option: option) {
                return image
            }
            return fallthroughToCpu ? applying(matrix, option: .cpu(option.quality)) : nil
        default:
            // Create the bitmap context.
            UIGraphicsBeginImageContextWithOptions(transformedBox.size, false, scale)
            defer { UIGraphicsEndImageContext() }
            guard let cgImage = self._makeCgImage(), let context = UIGraphicsGetCurrentContext() else { return nil }
            // Move the origin to the middle of the image so we will transform around the center.
            context.translateBy(x: transformedBox.width * 0.5, y: transformedBox.height * 0.5)
            // Change the ctm's position.
            context.scaleBy(x: 1.0, y: -1.0)
            // Transform the image context.
            context.concatenate(matrix)
            // Set the interpolation quality with the value in the option.
            context.interpolationQuality = option.quality
            // Now, draw the rotated/scaled image into the context.
            context.draw(cgImage, in: CGRect(x: -rect.width * 0.5, y: -rect.height * 0.5, width: rect.width, height: rect.height))
            return UIGraphicsGetImageFromCurrentImageContext()
        }
    }
}

// MARK: - CoreImage.

extension UIImage {
    /// Produces a high-quality, scaled version of the receiver image.
    ///
    /// Clients typically use this function to scale down an image immediately rather than chainning the filter processings.
    ///
    /// - Parameter scale      : A CGFloat value indicates the scale accuracy of the source image reached from `0.0` to `1.0`.
    /// - Parameter aspectRatio: A CGFloat value indicates the aspect ratio accuracy of the scaling reached from `0.0` to `1.0`.
    ///                          using `1.0` by default.
    /// - Parameter option     : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                          Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A scaled, high-quality copy of the recevier.
    public func scale(to scale: CGFloat, aspectRatio: CGFloat = 1.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        return applying("CILanczosScaleTransform", inputParameters: ["inputScale": scale, "inputAspectRatio": aspectRatio], option: option)
    }
}

extension UIImage {
    /// Applies a perspective correction, transforming an arbitrary quadrilateral region in the source image to a rectangular output image.
    ///
    /// Clients typically use this function to perspective correct an image immediately rather than chainning the filter processings.
    ///
    /// - Parameter topLeft    : The point in the input image to be mapped to the top left corner of the output image.
    ///                          A CIVector object whose attribute type is CIAttributeTypePosition and whose display name is Top Left.
    /// - Parameter topRight   : The point in the input image to be mapped to the top right corner of the output image.
    ///                          A CIVector object whose attribute type is CIAttributeTypePosition and whose display name is Top Right.
    /// - Parameter bottomLeft : The point in the input image to be mapped to the bottom left corner of the output image.
    ///                          A CIVector object whose attribute type is CIAttributeTypePosition and whose display name is Bottom Left.
    /// - Parameter bottomRight: The point in the input image to be mapped to the bottom right corner of the output image.
    ///                          A CIVector object whose attribute type is CIAttributeTypePosition and whose display name is Bottom Right.
    /// - Parameter option     : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                          Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A perspective corrected copy of the recevier.
    public func perspectiveCorrect(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, option: RichImage.RenderOption = .auto) -> UIImage! {
        return applying("CIPerspectiveCorrection", inputParameters: ["inputTopLeft": CIVector(cgPoint: topLeft), "inputTopRight": CIVector(cgPoint: topRight), "inputBottomRight": CIVector(cgPoint: bottomRight), "inputBottomLeft": CIVector(cgPoint: bottomLeft)], option: option)
    }
    /// Alters the geometry of an image to simulate the observer changing viewing position.
    ///
    /// Clients typically use this function to skew an the portion of the image defined by extent immediately 
    /// rather than chainning the filter processings.
    ///
    /// - Parameter topLeft    : A CIVector object whose attribute type is CIAttributeTypePosition and whose display name is Top Left.
    /// - Parameter topRight   : A CIVector object whose attribute type is CIAttributeTypePosition and whose display name is Top Right.
    /// - Parameter bottomLeft : A CIVector object whose attribute type is CIAttributeTypePosition and whose display name is Bottom Left.
    /// - Parameter bottomRight: A CIVector object whose attribute type is CIAttributeTypePosition and whose display name is Bottom Right.
    /// - Parameter extent     : A CIVector object whose whose attribute type is CIAttributeTypeRectangle. If you pass [image extent] 
    ///                          you’ll get the same result as using the CIPerspectiveTransform filter.
    /// - Parameter option     : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                          Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A perspective corrected copy of the recevier.
    public func perspectiveTransform(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, extent: CGRect? = nil, option: RichImage.RenderOption = .auto) -> UIImage! {
        var inputParameters = ["inputTopLeft": CIVector(cgPoint: topLeft), "inputTopRight": CIVector(cgPoint: topRight), "inputBottomRight": CIVector(cgPoint: bottomRight), "inputBottomLeft": CIVector(cgPoint: bottomLeft)]
        if let _ext = extent { inputParameters["inputExtent"] = CIVector(cgRect: _ext) }
        return applying(extent == nil ? "CIPerspectiveTransform" : "CIPerspectiveTransformWithExtent", inputParameters: inputParameters, option: option)
    }
}

extension UIImage {
    /// Rotates the source image by the specified angle in radians.
    ///
    /// The image is scaled and cropped so that the rotated image fits the extent of the input image.
    ///
    /// - Parameter angle : An NSNumber object whose attribute type is CIAttributeTypeScalar and whose display name is Angle.
    ///                     Default value is 0.0.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: An image scaled and cropped to fit the extent of the input image.
    public func straightenRotate(by angle: CGFloat, option: RichImage.RenderOption = .auto) -> UIImage! {
        return applying("CIStraightenFilter", inputParameters: ["inputAngle": angle], option: option)
    }
}
