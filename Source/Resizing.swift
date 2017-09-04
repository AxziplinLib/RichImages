//
//  Resizing.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import ImageIO
import CoreGraphics

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
    public func crop(to rect: CGRect, rendering dest: RenderDestination = .cpu) -> UIImage! {
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
            guard let ciContext = _ciContext(at: dest)                                 else { return fallthroughToCpu ? crop(to:rect, rendering: .cpu) : nil }
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
    public func crop(fits size: CGSize, using mode: ResizingMode = .center, rendering dest: RenderDestination = .cpu) -> UIImage! {
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
