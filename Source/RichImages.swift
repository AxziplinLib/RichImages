//
//  RichImages.swift
//  AxReminder
//
//  Created by devedbox on 2017/8/31.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import MetalKit
import OpenGLES
import CoreImage
import CoreGraphics

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

extension UIImage {
    public var scaledWidth : CGFloat { return size.width * scale }
    public var scaledHeight: CGFloat { return size.height * scale }
    public var scaledSize  : CGSize  { return CGSize(width: scaledWidth, height: scaledHeight) }
}

extension CGRect { public func scale(by scale: CGFloat) -> CGRect {  return applying(CGAffineTransform(scaleX: scale, y: scale)) } }
extension CGSize { public func scale(by scale: CGFloat) -> CGSize {  return applying(CGAffineTransform(scaleX: scale, y: scale)) } }

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

internal func _correct(bitmapInfo: CGBitmapInfo, `for` colorSpace: CGColorSpace) -> CGBitmapInfo {
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
            /// Indicates the rendering is based on the default GPU device.
            case `default`
            /// Indicates the rendering is based on a `MTLDevice`. The GPU-Based contex for this value
            /// will automatic fallthrough to the OpenGL ES-Based if the Metal device is not available.
            @available(iOS 9.0, *)
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

extension UIImage.RenderDestination {
    public static var availableGPURelatedDestinations: [UIImage.RenderDestination] {
        if #available(iOS 9.0, *) {
            return [.auto, .gpu(.default), .gpu(.metal), .gpu(.openGLES)]
        } else {
            return [.auto, .gpu(.default), .gpu(.openGLES)]
        }
    }
}

// MARK: - CoreImage.

extension UIImage {
    /// A type representing a core image context using automatic rendering by choosing the appropriate or best available CPU or GPU rendering technology based on the current device.
    fileprivate struct _AutomaticCIContext {
        lazy var context: CIContext! = { () -> CIContext! in
            let context = CIContext()
            return context
        }()
    }
    /// A type representing a core image context using the GPU-Based rendering.
    fileprivate struct _GPUBasedCIContext {
        lazy var context: CIContext! = { () -> CIContext! in
            let context = CIContext(options: [kCIContextUseSoftwareRenderer: false, kCIContextHighQualityDownsample: true])
            return context
        }()
    }
    /// A type representing a core image context using the real-time rendering with Metal.
    @available(iOS 9.0, *)
    fileprivate struct _MetalBasedCIContext {
        lazy var context: CIContext! = { () -> CIContext! in
            guard let device = MTLCreateSystemDefaultDevice() else { return _openGLESCIContext.context }
            return CIContext(mtlDevice: device)
        }()
    }
    /// A type representing a core image context using the real-time rendering with OpenGL ES.
    fileprivate struct _OpenGLESBasedCIContext {
        lazy var context: CIContext! = { () -> CIContext! in
            guard let eaglContext = EAGLContext(api: .openGLES3) else { return nil }
            return CIContext(eaglContext: eaglContext)
        }()
    }
}

private var _autoCIContext     = UIImage._AutomaticCIContext()
private var _gpuCIContext      = UIImage._GPUBasedCIContext()
@available(iOS 9.0, *)
private var _metalCIContext    = UIImage._MetalBasedCIContext()
private var _openGLESCIContext = UIImage._OpenGLESBasedCIContext()


/// Initialize the required core image context for the given render destinations.
///
/// - Parameter dests: A array of value defined in `UIImage.RenderDestination` used
///                    to initialze the corresponding render destination context.
///
public func CIContextInitialize(_ dests: [UIImage.RenderDestination]) { dests.forEach({ _ciContext(at: $0) }) }

/// Get the context of core image with the given render destination.
@discardableResult
internal func _ciContext(at dest: UIImage.RenderDestination) -> CIContext! {
    switch dest {
    case .auto:
        return _autoCIContext.context
    case .gpu(let gpu):
        switch gpu {
        case .metal:
            if #available(iOS 9.0, *) {
                return _metalCIContext.context
            } else { return nil }
        case .openGLES:
            return _openGLESCIContext.context
        case .default:
            return _gpuCIContext.context
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
    internal func _makeCiImage() -> CIImage! {
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
    ///
    /// - Parameter dest: A render destination used by the ci context
    ///                   to generate cg images.
    internal func _makeCgImage(_ dest: UIImage.RenderDestination = .auto) -> CGImage! {
        var cgImage: CGImage! = nil
        if let underlyingCgImage = self.cgImage {
            cgImage = underlyingCgImage
        } else if let ciImage = self.ciImage, let context = _ciContext(at: dest), let renderedCgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            cgImage = renderedCgImage
        } else {
            guard let data = UIImageJPEGRepresentation(self, 1.0) as CFData?, let dataProvider = CGDataProvider(data: data) else { return nil }
            cgImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }
        return cgImage
    }
}
