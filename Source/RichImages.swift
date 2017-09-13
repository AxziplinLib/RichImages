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

// MARK: - RichImagable.

/// A type that can processing the UIImage object by resizing, bluring, adjusting color 
/// and generate other UIImage object and so on.
///
/// The `RichImagable` protocol is used to access the complex extensions of UIImage by
/// a simple coding, you can simply apply a core image filter, resize to a target rectangle
/// or generate a qrcode with conformance implement the less-than property `image`.
///
/// To add `RichImagable` conformance to your custom types, define `image` property and 
/// return an UIImage object.
public protocol RichImagable {
    /// The UIImage object to be processed with CoreGraphics or CoreImage.
    var image: UIImage { get }
}
/// Added conformance to UIImage.
extension UIImage: RichImagable {
    public var image: UIImage { return self }
}

// MARK: - RichImage.

/// Rich image module field.
public struct RichImage { /* Rich image module field. */
    /// Storage of `_AutomaticCIContext`.
    fileprivate var _autoCIContext     = _AutomaticCIContext()
    /// Storage of `_GPUBasedCIContext`.
    fileprivate var _gpuCIContext      = _GPUBasedCIContext()
    @available(iOS 9.0, *)
    fileprivate var _metalCIContext:     _MetalBasedCIContext { return _metalCIContextStorage as! _MetalBasedCIContext }
    /// Storage of `_MetalBasedCIContext`.
    fileprivate var _metalCIContextStorage: Any! = { () -> Any? in
        if #available(iOS 9.0, *) {
            return RichImage._MetalBasedCIContext()
        } else {
            return nil
        }
    }()
    /// Storage of `_OpenGLESBasedCIContext`.
    fileprivate var _openGLESCIContext = _OpenGLESBasedCIContext()
    
    /// Returns the default singleton value of the `RichImage`.
    public static var `default`: RichImage = RichImage()
}

extension RichImage {
    /// Initialize the required core image context for the given render destinations.
    ///
    /// - Parameter dests: A array of value defined in `UIImage.RenderDestination` used
    ///                    to initialze the corresponding render destination context.
    ///
    public static func initialize(_ dests: [RichImage.RenderOption.Destination]) { dests.forEach({ self.default.ciContext(at: $0) }) }
    /// Update the cached CIContext with the given context for the specific render destination.
    ///
    /// - Note: This updation will not check the render destination of the given context. So be
    ///         careful with the updating context because the unckecking of the updation.
    ///
    /// - Parameter context: A CIContext for the specific render destination used to update the default context
    /// - Parameter dest   : The render destination whose context need to be updated.
    ///
    /// - Returns: A boolean result indicates whether the updation is successful.
    public mutating func update(_ context: CIContext, `for` dest: RichImage.RenderOption.Destination) -> Bool {
        switch dest {
        case .auto:
            _autoCIContext.context = context
        case .gpu(let gpu):
            switch gpu {
            case .metal:
                if #available(iOS 9.0, *) {
                    var context_ = RichImage._MetalBasedCIContext()
                    context_.context = context
                    _metalCIContextStorage = context_
                } else {
                    return false
                }
            case .openGLES:
                _openGLESCIContext.context = context
            default:
                _gpuCIContext.context = context
            }
        default: return false
        }
        return true
    }
    
    /// Get the context of core image with the given render destination.
    @discardableResult
    public mutating func ciContext(at dest: RichImage.RenderOption.Destination) -> CIContext! {
        switch dest {
        case .auto:
            return _autoCIContext.context
        case .gpu(let gpu):
            switch gpu {
            case .metal:
                if #available(iOS 9.0, *) {
                    var _metal = (_metalCIContextStorage as! _MetalBasedCIContext)
                    return _metal.context
                } else { return nil }
            case .openGLES:
                return _openGLESCIContext.context
            case .default:
                return _gpuCIContext.context
            }
        default: return nil
        }
    }
}

// MARK: - RenderOption.

extension RichImage {
    /// A type representing the render option for the image processing.
    /// Clients typically use the static functions `.cpu`, `.auto` or `gpu(:)` to locate the
    /// render destination for the processing.
    public struct RenderOption {
        /// The render destination of the image processing.
        var dest: Destination
        /// The interpolation quality for the rescaling in CoreGraphics when using CPU as the render destination.
        var quality: CGInterpolationQuality = .default
        
        init(dest: Destination) {
            self.dest = dest
        }
    }
}

extension RichImage.RenderOption {
    /// Returns an option of `RenderOption` with using `CPU` as the render destination.
    public static var  cpu : RichImage.RenderOption { return RichImage.RenderOption(dest: .cpu) }
    /// Returns an option of `RenderOption` with using `AUTO MODE` as the render destination.
    public static var  auto: RichImage.RenderOption { return RichImage.RenderOption(dest: .auto) }
    /// Creates an option of `RenderOption` with using `GPU` as the render destination.
    ///
    /// - Parameter gpu: A value describ in `Destination.GPU` indicates the gpu device the tec. using
    ///                  as the target GPU destination.
    ///
    /// - Returns: An GPU-Based `RenderOption` with the given gpu device or tec. .
    public static func gpu(_ gpu: Destination.GPU) -> RichImage.RenderOption {
        return RichImage.RenderOption(dest: .gpu(gpu))
    }
    /// Creates an option of `RenderOption` with using `CPU` as the render destination and the specific interpolation quality.
    ///
    /// - Parameter quality: The interpolation quality for the rescaling in CoreGraphics when using CPU as the render destination.
    ///
    /// - Returns: An CPU-Based `RenderOption` with the given interpolation quality.
    public static func cpu(_ quality: CGInterpolationQuality) -> RichImage.RenderOption {
        var option = RichImage.RenderOption(dest: .cpu)
        option.quality = quality
        return option
    }
}

// MARK: - Destination.

extension RichImage.RenderOption {
    /// A type representing the rendering destination of the image's cropping and other processing.
    public enum Destination {
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

extension RichImage.RenderOption.Destination {
    /// Returns the available GPU-Related render destination values.
    public static var availableGPURelatedDestinations: [RichImage.RenderOption.Destination] {
        if #available(iOS 9.0, *) {
            return [.auto, .gpu(.default), .gpu(.metal), .gpu(.openGLES)]
        } else {
            return [.auto, .gpu(.default), .gpu(.openGLES)]
        }
    }
}

extension RichImagable {
    /// Returns a new image created by applying a filter to the original image with the specified name and parameters.
    ///
    /// Calling this method is equivalent to the following sequence of steps:
    /// * Creating a CIFilter instance.
    /// * Setting the original image.ciImage as the filter’s inputImage parameter.
    /// * Setting the remaining filter parameters from the params dictionary.
    /// * Retrieving the outputImage object from the filter.
    /// * Using the context from the given render option to create a cgImage.
    /// * Creating a UIImage object with the cgImage, scale and orientation.
    ///
    /// - Parameter filterName: The name of the filter to apply, as used when creating a CIFilter instance with the init(name:) method.
    /// - Parameter params    : A dictionary whose key-value pairs are set as input values to the filter. Each key is a constant that
    ///                         specifies the name of an input parameter for the filter, and the corresponding value is the value for
    ///                         that parameter. See `Core Image Filter Reference` for built-in filters and their allowed parameters.
    /// - Parameter option    : A value of `RenderOption` indicates the rendering options of the image scaling processing.
    ///                         Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: An image object representing the result of applying the filter.
    public func applying(_ filterName:String, inputParameters params: [String: Any]?, option: RichImage.RenderOption = .auto) -> UIImage! {
        return type(of: self).filter(image, with: filterName, inputParameters: params, option: option)
    }
    /// Returns a new image created by making a generator filter with the specified name and parameters.
    ///
    /// Calling this method is equivalent to the following sequence of steps:
    /// * Creating a CIFilter instance.
    /// * Setting the necesary filter parameters from the params dictionary.
    /// * Retrieving the outputImage object from the filter.
    /// * Using the context from the given render option to create a cgImage.
    /// * Creating a UIImage object with the cgImage, scale and orientation.
    ///
    /// - Parameter filterName  : The name of the filter to apply, as used when creating a CIFilter instance with the init(name:) method.
    /// - Parameter params      : A dictionary whose key-value pairs are set as input values to the filter. Each key is a constant that
    ///                           specifies the name of an input parameter for the filter, and the corresponding value is the value for
    ///                           that parameter. See `Core Image Filter Reference` for built-in filters and their allowed parameters.
    /// - Parameter croppingRect: A rect for the generator filter to crop to because some of the generator filters need to be cropped
    ///                           before they can be displayed like "CICheckerboardGenerator". Defaults to nil.
    /// - Parameter option      : A value of `RenderOption` indicates the rendering options of the image scaling processing.
    ///                           Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: An image object representing the result of generator filter.
    public static func generate(_ filterName: String, inputParameters params: [String: Any]?, cropTo croppingRect: CGRect? = nil, option: RichImage.RenderOption = .auto) -> UIImage! {
        if params?["inputImage"] != nil { fatalError("Using \(#function) to apply a generator filter which is not an input image parameter. Please using instance function 'applying(_:inputParameters:option:)' instead because a normal filter's result should using the same scale or orientation as the original image.") }
        return filter(nil, with: filterName, inputParameters: params, croppingRect: croppingRect, scale: UIScreen.main.scale, orientation: .up, option: option)
    }
    /// Returns a new image created by applying a filter to the given image or making a generator filter if the image is nil
    /// with the specified name and parameters.
    ///
    /// Calling this method is equivalent to the following sequence of steps:
    /// * Creating a CIFilter instance.
    /// * Setting the original image as the filter’s inputImage parameter.
    /// * Setting the remaining filter parameters from the params dictionary.
    /// * Retrieving the outputImage object from the filter.
    /// * Using the context from the given render option to create a cgImage.
    /// * Creating a UIImage object with the cgImage, scale and orientation.
    ///
    /// - Parameter image       : The image to apply filter to. Pass nil if you want to create a filter with unnecessary image parameter
    ///                           like generator filter.
    /// - Parameter filterName  : The name of the filter to apply, as used when creating a CIFilter instance with the init(name:) method.
    /// - Parameter params      : A dictionary whose key-value pairs are set as input values to the filter. Each key is a constant that
    ///                           specifies the name of an input parameter for the filter, and the corresponding value is the value for
    ///                           that parameter. See `Core Image Filter Reference` for built-in filters and their allowed parameters.
    /// - Parameter croppingRect: A rect for the generator filter to crop to because some of the generator filters need to be cropped
    ///                           before they can be displayed like "CICheckerboardGenerator". Defaults to nil.
    /// - Parameter scale       : A float value indicates the scale of the image mapping from pxiels to points. The `scale` of the given
    ///                           image will be used as the result image's scale and this given value will be ignored if the given image
    ///                           is not nil. Default using the scale of the main screen.
    /// - Parameter orientation : A value of `UIImageOrientation` indicates the orientation of  the result UIImage. The `orientation` of
    ///                           the given image will be used as the result image's scale and this given value will be ignored if the
    ///                           given image is not nil. Default using `.up`.
    /// - Parameter option      : A value of `RenderOption` indicates the rendering options of the image scaling processing.
    ///                           Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: An image object representing the result of applying the filter.
    public static func filter(_ image: UIImage?, with filterName: String, inputParameters params: [String: Any]?, croppingRect: CGRect? = nil, scale: CGFloat = UIScreen.main.scale, orientation: UIImageOrientation = .up, option: RichImage.RenderOption = .auto) -> UIImage! {
        switch option.dest {
        case .auto  : fallthrough
        case .gpu(_):
            var input: CIImage!
            if CIFilter.filterNames(inCategory: kCICategoryGenerator).contains(filterName) && image == nil {// The filter is generator. And the image is not needed.
                input = CIFilter(name: filterName, withInputParameters: params)?.outputImage
                // Some of the generator filters need to be cropped before they can be displayed.
                /// Crop the input to the given rect if any.
                if let crop = croppingRect {
                    input = input.cropping(to: crop)
                }
            } else {
                input = image?._makeCiImage()?.applyingFilter(filterName, withInputParameters: params)
            }
            guard let ciImage   = input else { return nil }
            
            return make(ciImage, scale: image?.scale ?? scale, orientation: image?.imageOrientation ?? orientation, option: option)
        default: return nil
        }
    }
    /// Creates the UIImage instance from a given CIImage with the given scale, orientation and redner option.
    ///
    /// - Note: The CIImage is rendered using the render destination in the render option and `.cpu` mode is not supported.
    ///
    /// - Parameter ciImage     : The core image to be rendered to the UIImage.
    /// - Parameter scale       : A float value indicates the scale of the image mapping from pxiels to points. The `scale` of the given
    ///                           image will be used as the result image's scale and this given value will be ignored if the given image
    ///                           is not nil. Default using the scale of the main screen.
    /// - Parameter orientation : A value of `UIImageOrientation` indicates the orientation of  the result UIImage. The `orientation` of
    ///                           the given image will be used as the result image's scale and this given value will be ignored if the
    ///                           given image is not nil. Default using `.up`.
    /// - Parameter option      : A value of `RenderOption` indicates the rendering options of the image scaling processing.
    ///                           Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: An UIImage object contains bitmap(CGImage-Based) data rather than core image data.
    public static func make(_ ciImage: CIImage, from extent: CGRect? = nil, scale: CGFloat = UIScreen.main.scale, orientation: UIImageOrientation = .up, option: RichImage.RenderOption) -> UIImage! {
        guard let ciContext = RichImage.default.ciContext(at: option.dest)                     else { return nil }
        guard let cgImage   = ciContext.createCGImage(ciImage, from: extent ?? ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }
}

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
    /// Returns the width of the size of the receiver multiplied by the scale of the image.
    public var scaledWidth : CGFloat { return size.width * scale }
    /// Returns the height of the size of the receiver multiplied by the scale of the image.
    public var scaledHeight: CGFloat { return size.height * scale }
    /// Returns the size of the size of the receiver multiplied by the scale of the image.
    public var scaledSize  : CGSize  { return CGSize(width: scaledWidth, height: scaledHeight) }
}

extension CGRect { public func scale(by scale: CGFloat) -> CGRect {  return applying(CGAffineTransform(scaleX: scale, y: scale)) } }
extension CGSize { public func scale(by scale: CGFloat) -> CGSize {  return applying(CGAffineTransform(scaleX: scale, y: scale)) } }

// MARK: - Context Manager.

extension RichImage {
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
            var options: [String: Any] = [kCIContextUseSoftwareRenderer: false]
            if #available(iOS 9.0, *) {
                options[kCIContextHighQualityDownsample] = true
            }
            let context = CIContext(options: options)
            return context
        }()
    }
    /// A type representing a core image context using the real-time rendering with Metal.
    @available(iOS 9.0, *)
    fileprivate struct _MetalBasedCIContext {
        lazy var context: CIContext! = { () -> CIContext! in
            guard let device = MTLCreateSystemDefaultDevice() else { return RichImage.default._openGLESCIContext.context }
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
    internal func _makeCgImage(_ dest: RichImage.RenderOption.Destination = .auto) -> CGImage! {
        var cgImage: CGImage! = nil
        if let underlyingCgImage = self.cgImage {
            cgImage = underlyingCgImage
        } else if let ciImage = self.ciImage, let context = RichImage.default.ciContext(at: dest), let renderedCgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            cgImage = renderedCgImage
        } else {
            guard let data = UIImageJPEGRepresentation(self, 1.0) as CFData?, let dataProvider = CGDataProvider(data: data) else { return nil }
            cgImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }
        return cgImage
    }
}
