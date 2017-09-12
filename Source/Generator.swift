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

// MARK: - CoreImage.

extension UIImage {
    /// Generates an Aztec code (two-dimensional barcode) from input data.
    ///
    /// Generates an output image representing the input data according to the ISO/IEC 24778:2008 standard. The width and height
    /// of each module (square dot) of the code in the output image is one pixel. To create an Aztec code from a string or URL, 
    /// convert it to an NSData object using the NSISOLatin1StringEncoding string encoding. The output image also includes two 
    /// pixels of padding on each side (for example, a 15 x 15 code creates a 19 x 19 image).
    ///
    /// - Parameter data           : The data to be encoded as an Aztec code. An NSData object whose display name is Message.
    /// - Parameter correctionLevel: The percentage of redundancy to add to the message data in the barcode encoding. 
    ///                              A higher correction level allows a barcode to be correctly read even when partially damaged.
    ///                              The value is  available in [5.0, 95.0]. Using 23.0 as default.
    /// - Parameter layers         : The number of concentric squares (with a width of two pixels each) encoding the barcode data.
    ///                              When this parameter is set to zero, Core Image automatically determines the appropriate number of layers to 
    ///                              encode the message at the specified correction level. The value is available in [1.00, 32.00]. Using 0.00 as
    ///                              default.
    /// - Parameter compactStyle   : A Boolean value that determines whether to use the compact or full-size Aztec barcode format. 
    ///                              The compact format can store up to 44 bytes of message data (including data added for correction) 
    ///                              in up to 4 layers, producing a barcode image sized between 15 x 15 and 27 x 27 pixels. 
    ///                              The full-size format can store up to 1914 bytes of message data (including correction) in up to 32 layers,
    ///                              producing a barcode image sized no larger than 151 x 151 pixels. Using false as default.
    /// - Parameter option         : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                              Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: An Aztec code image object.
    public class func generateAztecCode(_ data: Data, correctionLevel: CGFloat = 23.0, layers: CGFloat = 0.0, compactStyle: Bool = false, option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CIAztecCodeGenerator", inputParameters: ["inputMessage": data, "inputCorrectionLevel": correctionLevel, "inputLayers": layers, "inputCompactStyle": compactStyle], option: option)
    }
    /// Generates a Quick Response code (two-dimensional barcode) from input data.
    ///
    /// Generates an output image representing the input data according to the ISO/IEC 18004:2006 standard. 
    /// The width and height of each module (square dot) of the code in the output image is one point. 
    /// To create a QR code from a string or URL, convert it to an NSData object using the NSISOLatin1StringEncoding string encoding.
    /// The inputCorrectionLevel parameter controls the amount of additional data encoded in the output image to 
    /// provide error correction. Higher levels of error correction result in larger output images but allow larger areas 
    /// of the code to be damaged or obscured without. There are four possible correction modes (with corresponding error resilience levels):
    /// * L: 7%
    /// * M: 15%
    /// * Q: 25%
    /// * H: 30%
    ///
    /// - Note: When you create a qr code image, you may need to resize the image to an expected size to display using:
    ///
    ///         image.resize(fills: expectedSize), option: .cpu(.none))
    ///
    /// - Parameter data           : The data to be encoded as a QR code. An NSData object whose display name is Message.
    /// - Parameter correctionLevel: A single letter specifying the error correction format. An NSString object whose display name is CorrectionLevel.
    ///                              Default value: M
    /// - Parameter option         : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                              Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: An image containing QRCode infos.
    public class func generateQRCode(_ data: Data, correctionLevel: String = "M", option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CIQRCodeGenerator", inputParameters: ["inputMessage": data, "inputCorrectionLevel": correctionLevel], option: option)
    }
    /// Generates a Code 128 one-dimensional barcode from input data.
    ///
    /// Generates an output image representing the input data according to the ISO/IEC 15417:2007 standard.
    /// The width of each module (vertical line) of the barcode in the output image is one pixel. The height of the barcode is 32 pixels. 
    /// To create a barcode from a string or URL, convert it to an NSData object using the NSASCIIStringEncoding string encoding.
    ///
    /// - Note: When you create a qr code image, you may need to resize the image to an expected size to display using:
    ///
    ///         image.resize(fits: expectedSizer, using: .scaleAspectFit, option: .cpu(.none))
    ///
    /// - Parameter data: The data to be encoded as a Code 128 barcode. Must not contain non-ASCII characters.
    ///                   An Data object whose display name is Message.
    /// - Parameter quietSpace: The number of pixels of added white space on each side of the barcode.
    ///                         A CGFloat value whose attribute type is CIAttributeTypeScalar and whose display name is QuietSpace.
    ///                         The value is available in [0.0, 20.0], using 7.0 as default.
    /// - Parameter option    : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                         Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// 
    /// - Returns: An image containing code 128 barcode info.
    public class func generateCode128Barcode(_ data: Data, quietSpace: CGFloat = 7.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CICode128BarcodeGenerator", inputParameters: ["inputMessage": data, "inputQuietSpace": quietSpace], option: option)
    }
    /// Generates a PDF417 code (two-dimensional barcode) from input data.
    ///
    /// Generates an output image representing the input data according to the ISO 15438 standard. 
    /// PDF417 codes are commonly used in postage, package tracking, personal identification documents, 
    /// and coffeeshop membership cards. The width and height of each module (square dot) of the code 
    /// in the output image is one point. To create a PDF417 code from a string or URL, convert it to
    /// an NSData object using the NSISOLatin1StringEncoding string encoding.
    /// 
    /// - Parameter data                   : The data to be encoded as a barcode. An NSData object whose display name is Message.
    /// - Parameter minWidth               : The minimum width of the barcode’s data area, in pixels. A CGFloat value whose display name
    ///                                      is MinWidth. The value is available in [56.0, 583.0]. Using 56.0 as default.
    /// - Parameter maxWidth               : The maximum width of the barcode’s data area, in pixels. A CGFloat value whose display name
    ///                                      is MaxWidth. The value is available in [56.0, 583.0]. Using 56.0 * 2.0 as default.
    /// - Parameter minHeight              : The minimum height of the barcode’s data area, in pixels. A CGFloat value whose display name
    ///                                      is MinHeight. The value is available in [13.00, 283.00]. Using 13.0 as default.
    /// - Parameter maxHeight              : The maximum height of the barcode’s data area, in pixels. A CGFloat value whose display name
    ///                                      is MaxHeight. The value is available in [13.00, 283.00]. Using 13.0 * 2.0 as default.
    /// - Parameter dataColumns            : The number of data columns in the generated code. If zero, the generator uses a number of columns
    ///                                      based on the width, height, and aspect ratio. A CGFloat value whose display name is DataColumns. 
    ///                                      The value is available in [1, 30]. Using 30 as default.
    /// - Parameter rows                   : The number of data rows in the generated code. If zero, the generator uses a number of rows
    ///                                      based on the width, height, and aspect ratio. A CGFloat value whose display name is Rows.
    ///                                      The value is available in [3, 90]. Using 3 as default.
    /// - Parameter preferredAspectRatio   : The preferred ratio of width over height for the generated barcode. The generator approximates
    ///                                      this with an actual aspect ratio based on the data and other parameters you specify. A CGPoint 
    ///                                      value whose display name is PreferredAspectRatio. The value is available in [0.00, 922337203685
    ///                                      4775808.00]. Using 3.0 as default.
    /// - Parameter compactionMode         : An option that determines which method the generator uses to compress data. A CGFloat value
    ///                                      whose display name is CompactionMode. The value is available in [0, 1, 2, 3]. Using 0 as default.
    ///   - 0, Automatic. The generator automatically chooses a compression method. This option is the default.
    ///   - 1, Numeric. Valid only when the message is an ASCII-encoded string of digits, achieving optimal compression for that type of data.
    ///   - 2, Text. Valid only when the message is all ASCII-encoded alphanumeric and punctuation characters, 
    ///     achieving optimal compression for that type of data.
    ///   - 3, Byte. Valid for any data, but least compact.
    /// - Parameter compactStyle           : A Boolean value that determines whether to omit redundant elements to make the generated barcode
    ///                                      more compact. A CGFloat value whose display name is CompactStyle. Using false as default.
    /// - Parameter correctionLevel        : An integer between 0 and 8, inclusive, that determines the amount of redundancy to include
    ///                                      in the barcode’s data to prevent errors when the barcode is read. If unspecified, the generator
    ///                                      chooses a correction level based on the size of the message data. A CGFloat value whose
    ///                                      display name is CorrectionLevel. The value is available in [0, 8]. Using 4 as default.
    /// - Parameter alwaysSpecifyCompaction: A Boolean value that determines whether to include information about the compaction mode 
    ///                                      in the barcode even when such information is redundant. (If a PDF417 barcode does not 
    ///                                      contain compaction mode information, a reader assumes text-based compaction. Some barcodes
    ///                                      include this information even when using text-based compaction.). A CGFloat value whose 
    ///                                      display name is AlwaysSpecifyCompaction. Using false as default.
    /// - Parameter option                 : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                                      Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A PDF417 code (two-dimensional barcode) from input data.
    public class func generatePDF417Barcode(_ data: Data, minWidth: CGFloat = 56.00, maxWidth: CGFloat = 56.00 * 2.0, minHeight: CGFloat = 13.00, maxHeight: CGFloat = 13.00 * 2.0, dataColumns: Int = 30, rows: Int = 3, preferredAspectRatio: CGFloat = 3.0, compactionMode: Int = 0, compactStyle: Bool = false, correctionLevel: Int = 4, alwaysSpecifyCompaction: Bool = false, option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CIPDF417BarcodeGenerator", inputParameters: ["inputMessage": data, "inputMinWidth": minWidth, "inputMaxWidth": maxWidth, "inputMinHeight": minHeight, "inputMaxHeight": maxHeight, "inputDataColumns": dataColumns, "inputRows": rows, "inputPreferredAspectRatio": preferredAspectRatio, "inputCompactionMode": compactionMode, "inputCompactStyle": compactStyle, "inputCorrectionLevel": correctionLevel, "inputAlwaysSpecifyCompaction": alwaysSpecifyCompaction], cropTo: nil, option: option)
    }
}

extension UIImage {
    /// Generates a checkerboard pattern image.
    ///
    /// You can specify the checkerboard size and colors, and the sharpness of the pattern.
    ///
    /// - Parameter center    : A CGPoint value whose attribute type is CIAttributeTypePosition and whose display name is Center.
    ///                         Default value: [150 150].
    /// - Parameter color0    : A UIColor object whose display name is Color 1.
    /// - Parameter color1    : A UIColor object whose display name is Color 2.
    /// - Parameter inputWidth: A CGFloat value whose attribute type is CIAttributeTypeDistance and whose display name is Width.
    ///                         Default value: 80.00.
    /// - Parameter sharpness : A CGFloat value whose attribute type is CIAttributeTypeScalar and whose display name is Sharpness.
    ///                         Default value: 1.00
    /// - Parameter size      : The size of the generated checkerboard pattern image.
    /// - Parameter option    : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                         Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A checkerboard pattern image.
    public class func generateCheckerboard(center: CGPoint = CGPoint(x: 150.0, y: 150.0), color0: UIColor, color1: UIColor, inputWidth: CGFloat = 80.0, sharpness: CGFloat = 1.0, size: CGSize, option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CICheckerboardGenerator", inputParameters: ["inputCenter": CIVector(cgPoint: center), "inputColor0": CIColor(color: color0), "inputColor1": CIColor(color: color1), "inputWidth": inputWidth, "inputSharpness": sharpness], cropTo: CGRect(origin: CGPoint(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5), size: size), option: option)
    }
    /// Generates a solid color image.
    ///
    /// - Parameter color : A UIColor object whose display name is Color to fill the result image.
    /// - Parameter size  : The size of the image in pxiels.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: An solid color image with the given size.
    public class func generateConstantColor(_ color: UIColor, size: CGSize = CGSize(width: 1.0, height: 1.0), option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CIConstantColorGenerator", inputParameters: ["inputColor": CIColor(color: color)], cropTo: CGRect(origin: .zero, size: size), option: option)
    }
    /// Use this function to simulates a lens flare and creates a lens flare image.
    ///
    /// - Parameter center           : The center of the lens flare. A CGPoint value whose attribute type is
    ///                                CIAttributeTypePosition and whose display name is Center. Default value: [150 150].
    /// - Parameter color            : Controls the proportion of red, green, and blue halos. A UIColor object whose display name is Color.
    /// - Parameter haloRadius       : Controls the size of the lens flare. A CGFloat value whose attribute type is
    ///                                CIAttributeTypeDistance and whose display name is Halo Radius. Default value: 70.00.
    /// - Parameter haloWidth        : Controls the width of the lens flare, that is, the distance between the inner flare and the outer flare.
    ///                                A CGFloat value whose attribute type is CIAttributeTypeDistance and whose display name is Halo Width.
    ///                                Default value: 87.00.
    /// - Parameter haloOverlap      : Controls how much the red, green, and blue halos overlap. A value of 0 means no overlap (a lot of separation).
    ///                                A value of 1 means full overlap (white halos). A CGFloat value whose attribute type is CIAttributeTypeScalar
    ///                                and whose display name is Halo Overlap. Default value: 0.77.
    /// - Parameter striationStrength: Controls the brightness of the rainbow-colored halo area. A CGFloat value whose attribute type is 
    ///                                CIAttributeTypeScalar and whose display name is Striation Strength. Default value: 0.50.
    /// - Parameter striationContrast: Controls the contrast of the rainbow-colored halo area. A CGFloat value whose attribute type is
    ///                                CIAttributeTypeScalar and whose display name is Striation Contrast. Default value: 1.00.
    /// - Parameter time             : Adds a randomness to the lens flare; it causes the flare to "sparkle" as it changes through various 
    ///                                time values. A TimeInterval value whose attribute type is CIAttributeTypeScalar and whose display name
    ///                                is Time. Default value: 0.00.
    /// - Parameter option           : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                                Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A lens flare effects image.
    public class func generateLenticularHalo(center: CGPoint = CGPoint(x: 150.0, y: 150.0), color: UIColor, haloRadius: CGFloat = 70.0, haloWidth: CGFloat = 87.0, haloOverlap: CGFloat = 0.77, striationStrength: CGFloat = 0.50, striationContrast: CGFloat = 1.0, time: TimeInterval = 0.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CILenticularHaloGenerator", inputParameters: ["inputCenter": CIVector(cgPoint: center), "inputColor": CIColor(color: color), "inputHaloRadius": haloRadius, "inputHaloWidth": haloWidth, "inputHaloOverlap": haloOverlap, "inputStriationStrength": striationStrength, "inputStriationContrast": striationContrast, "inputTime": time], option: option)
    }
    /// Generates an image of infinite extent whose pixel values are made up of four independent, uniformly-distributed
    /// random numbers in the 0 to 1 range.
    ///
    /// - Parameter size  : The size of the target image to displat in pxiels.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A random pixels image.
    public class func generateRandom(size: CGSize, option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CIRandomGenerator", inputParameters: nil, cropTo: CGRect(origin: .zero, size: size), option: option)
    }
    /// Generates a starburst pattern that is similar to a supernova; can be used to simulate a lens flare.
    ///
    /// - Parameter center      : The center of the flare. A CGPoint value whose attribute type is CIAttributeTypePosition
    ///                           and whose display name is Center. Default value: [150 150].
    /// - Parameter color       : The color of the flare. A UIColor object whose display name is Color.
    /// - Parameter radius      : Controls the size of the flare. A CGFloat value whose attribute type is CIAttributeTypeDistance
    ///                           and whose display name is Radius. Default value: 50.00.
    /// - Parameter crossScale  : Controls the ratio of the cross flare size relative to the round central flare. A CGPoint
    ///                           value whose attribute type is CIAttributeTypeScalar and whose display name is Cross Scale.
    ///                           Default value: 15.00.
    /// - Parameter crossAngle  : Controls the angle of the flare. A CGFloat value whose attribute type is CIAttributeTypeAngle
    ///                           and whose display name is Cross Angle. Default value: 0.60.
    /// - Parameter crossOpacity: Controls the thickness of the cross flare. A CGFloat value whose attribute type is 
    ///                           CIAttributeTypeScalar and whose display name is Cross Opacity. Default value: -2.00.
    /// - Parameter crossWidth  : Has the same overall effect as the inputCrossOpacity parameter. A CGFloat value whose
    ///                           attribute type is CIAttributeTypeDistance and whose display name is Cross Width. Default value: 2.50
    /// - Parameter epsilon     : A CGFloat value whose attribute type is CIAttributeTypeScalar and whose display name is Epsilon.
    ///                           Default value: -2.00.
    /// - Parameter size        : The size of the generated starburst pattern image.
    /// - Parameter option      : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                           Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A starburst pattern image that is similar to a supernova.
    public class func generateStarShine(center: CGPoint = CGPoint(x: 150.0, y: 150.0), color: UIColor, radius: CGFloat = 50.0, crossScale: CGFloat = 15.0, crossAngle: CGFloat = 0.60, crossOpacity: CGFloat = -2.0, crossWidth: CGFloat = 2.5, epsilon: CGFloat = -2.0, size: CGSize, option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CIStarShineGenerator", inputParameters: ["inputCenter": CIVector(cgPoint: center), "inputColor": CIColor(color: color), "inputRadius": radius, "inputCrossScale": crossScale, "inputCrossAngle": crossAngle, "inputCrossOpacity": crossOpacity, "inputCrossWidth": crossWidth, "inputEpsilon": epsilon], cropTo: CGRect(origin: CGPoint(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5), size: size), option: option)
    }
    /// Generates a stripe pattern.
    ///
    /// You can control the color of the stripes, the spacing, and the contrast.
    ///
    /// - Parameter center   : A CGPoint value whose attribute type is CIAttributeTypePosition and whose display name
    ///                        is Center. Default value: [150 150].
    /// - Parameter color0   : A UIColor object whose display name is Color 1.
    /// - Parameter color1   : A UIColor object whose display name is Color 2.
    /// - Parameter width    : A CGFloat value whose attribute type is CIAttributeTypeDistance and whose display name
    ///                        is Width. Default value: 80.00.
    /// - Parameter sharpness: A CGFloat value whose attribute type is CIAttributeTypeScalar and whose display name
    ///                        is Sharpness. Default value: 1.00.
    /// - Parameter size     : The size of the generated stripe pattern image. Default value [300.0, 300.0].
    /// - Parameter option   : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                        Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// 
    /// - Returns: A stripe pattern image.
    public class func generateStripes(center: CGPoint = CGPoint(x: 150.0, y: 150.0), color0: UIColor, color1: UIColor, width: CGFloat = 80.0, sharpness: CGFloat = 1.0, size: CGSize = CGSize(width: 300.0, height: 300.0), option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CIStripesGenerator", inputParameters: ["inputCenter": CIVector(cgPoint: center), "inputColor0": CIColor(color: color0), "inputColor1": CIColor(color: color1), "inputWidth": width], cropTo: CGRect(origin: CGPoint(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5), size: size), option: option)
    }
    /// Generates a sun effect.
    ///
    /// - Parameter center            : A CGPoint value whose attribute type is CIAttributeTypePosition and whose display name
    ///                                 is Center. Default value: [150 150].
    /// - Parameter color             : A UIColor object whose display name is Color.
    /// - Parameter sunRadius         : A CGFloat value whose attribute type is CIAttributeTypeDistance and whose display name
    ///                                 is Sun Radius. Default value: 40.00.
    /// - Parameter maxStriationRadius: A CGFloat value whose attribute type is CIAttributeTypeScalar and whose display
    ///                                 name is Maximum Striation Radius. Default value: 2.58.
    /// - Parameter striationStrength : A CGFloat value whose attribute type is CIAttributeTypeScalar and whose display
    /// - Parameter striationContrast : A CGFloat value whose attribute type is CIAttributeTypeScalar and whose display
    ///                                 name is Striation Contrast. Default value: 1.38.
    ///                                 name is Striation Strength. Default value: 0.50.
    /// - Parameter time              : A TimeInterval value whose attribute type is CIAttributeTypeScalar and whose display name
    ///                                 is Time. Default value: 0.00.
    /// - Parameter option            : A value of `RichImage.RenderOption` indicates the rendering options of the image scaling processing.
    ///                                 Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A sun effect image.
    public class func generateSunbeams(center: CGPoint = CGPoint(x: 150.0, y: 150.0), color: UIColor, sunRadius: CGFloat = 40.0, maxStriationRadius: CGFloat = 2.58, striationStrength: CGFloat = 0.5, striationContrast: CGFloat = 1.38, time: TimeInterval = 0.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        return generate("CISunbeamsGenerator", inputParameters: ["inputCenter": CIVector(cgPoint: center), "inputColor": CIColor(color: color), "inputSunRadius": sunRadius, "inputMaxStriationRadius": maxStriationRadius, "inputStriationStrength": striationStrength, "inputStriationContrast": striationContrast, "inputTime": time], cropTo: nil, option: option)
    }
}
