//
//  ColorSpace.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreGraphics

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

// MARK : - Private.

internal extension UIColor {
    internal func matchs(_ color: UIColor) -> Bool {
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
