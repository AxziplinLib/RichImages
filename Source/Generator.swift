//
//  Generator.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreGraphics
import AVFoundation

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

// MARK: - Color-filled Image.

extension UIImage {
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
}
