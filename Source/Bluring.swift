//
//  Bluring.swift
//  RichImages
//
//  Created by devedbox on 2017/9/9.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage

extension RichImage {
    /// A type representing the algorithm of pixels to applying blur effects. References to the filters
    /// in `CICategoryBlur`.
    enum BluringMode {
        /// A value indicates bluring an image using a box-shaped convolution kernel.
        case box(radius: CGFloat)
        /// A value indicates bluring an image using a disc-shaped convolution kernel.
        case disc(radius: CGFloat)
        /// A value indicates spreading source pixels by an amount specified by a Gaussian distribution.
        case gaussian(radius: CGFloat)
        /// A value indicates bluring the source image according to the brightness levels in a mask image.
        case mask(mask: UIImage, radius: CGFloat)
        /// A value indicates computing the median value for a group of neighboring pixels and replaces each pixel value with the median.
        case median
        /// A value indicates bluring an image to simulate the effect of using a camera that moves a specified angle and distance while capturing the image.
        case motion(angle: CGFloat, radius: CGFloat)
        /// A value indicates reducing noise using a threshold value to define what is considered noise.
        case noise(level: CGFloat, sharpness: CGFloat)
        /// A value simulating the effect of zooming the camera while capturing the image.
        case zoom(center: CGPoint, amount: CGFloat)
    }
    /// A type representing the options to apply blur filter. Typically using this type to produce a `BluringMode` value.
    public struct BluringOption {
        /// The underlying bulring mode value of the option type.
        fileprivate let mode: BluringMode
        /// Creates an bluring option with a given bluring mode.
        ///
        /// - Parameter bluringMode: A value of `BluringMode` to produce the `BluringOption`.
        ///
        /// - Returns: An bluring option value contains an bluring underlying mode.
        init(_ bluringMode: BluringMode) {
            self.mode = bluringMode
        }
    }
}

extension RichImage.BluringMode {
    /// Returns the filter info depending on the current value of the bluring mode.
    /// The value is a tuple consists of filter name and input parameters of the filter.
    fileprivate var filter: (name: String, inputParameters: [String: Any]?)? {
        switch self {
        case .box(radius:      let r):
            return ("CIBoxBlur"           , ["inputRadius": r])
        case .disc(radius:     let r):
            return ("CIDiscBlur"          , ["inputRadius": r])
        case .gaussian(radius: let r):
            return ("CIGaussianBlur"      , ["inputRadius": r])
        case .mask(mask:       let img, radius: let r):
            guard let ciImage = img._makeCgImage() else { return nil }
            return ("CIMaskedVariableBlur", ["inputMask": ciImage, "inputRadius": r])
        case .median:
            return ("CIMedianFilter"      , nil)
        case .motion(angle:    let a, radius: let r):
            return ("CIMotionBlur"        , ["inputRadius": r, "inputAngle": a])
        case .noise(level:     let l, sharpness: let s):
            return("CINoiseReduction"     , ["inputNoiseLevel": l, "inputSharpness": s])
        case .zoom(center:     let c, amount: let a):
            return ("CIZoomBlur"          , ["inputCenter": CIVector(cgPoint: c), "inputAmount": a])
        }
    }
}

extension RichImage.BluringOption {
    /// Creates a bluring option with box mode with a given bluring radius.
    ///
    /// - Parameter radius: The bluring radius to affect the bluring effects. Using 10.0 as default.
    ///
    /// - Returns: A `BluringOption` value with the given radius.
    public static func box(radius: CGFloat = 10.0) -> RichImage.BluringOption {
        return RichImage.BluringOption(.box(radius: radius))
    }
    /// Creates a bluring option with disc mode with a given bluring radius.
    ///
    /// - Parameter radius: The bluring radius to affect the bluring effects. Using 8.0 as default.
    ///
    /// - Returns: A `BluringOption` value with the given radius.
    public static func disc(radius: CGFloat = 8.0) -> RichImage.BluringOption {
        return RichImage.BluringOption(.disc(radius: radius))
    }
    /// Creates a bluring option with gaussian mode with a given bluring radius.
    ///
    /// - Parameter radius: The bluring radius to affect the bluring effects. Using 10.0 as default.
    ///
    /// - Returns: A `BluringOption` value with the given radius.
    public static func gaussian(radius: CGFloat = 10.0) -> RichImage.BluringOption {
        return RichImage.BluringOption(.gaussian(radius: radius))
    }
    /// Creates a bluring option with masking mode with a given bluring radius.
    ///
    /// Shades of gray in the mask image vary the blur radius from zero (where the mask image is black) 
    /// to the radius specified in the inputRadius parameter (where the mask image is white).
    ///
    /// - Parameter mask  : The mask image with alpha channel to bluring the source image.
    /// - Parameter radius: The bluring radius to affect the bluring effects. Using 10.0 as default.
    ///
    /// - Returns: A `BluringOption` value with the given radius.
    public static func mask(_ mask: UIImage, radius: CGFloat = 10.0) -> RichImage.BluringOption {
        return RichImage.BluringOption(.mask(mask: mask, radius: radius))
    }
    /// Returns a bluring option with median mode with a given bluring radius.
    public static var  median: RichImage.BluringOption {
        return RichImage.BluringOption(.median)
    }
    /// Creates a bluring option with motion mode with a given angle and bluring radius.
    ///
    /// - Parameter angle : The angle of the motion effects. Using 0.0 as default.
    /// - Parameter radius: The bluring radius to affect the bluring effects. Using 20.0 as default.
    ///
    /// - Returns: A `BluringOption` value with the given values.
    public static func motion(angle: CGFloat = 0.0, radius: CGFloat = 20.0) -> RichImage.BluringOption {
        return RichImage.BluringOption(.motion(angle: angle, radius: radius))
    }
    /// Creates a bluring option with noise mode with a given angle and bluring radius.
    ///
    /// Small changes in luminance below that value are considered noise and get a noise reduction treatment, 
    /// which is a local blur. Changes above the threshold value are considered edges, so they are sharpened.
    ///
    /// - Parameter level    : The level of the noise effects. Using 0.02 as default.
    /// - Parameter sharpness: The bluring sharpness to affect the bluring effects. Using 0.4 as default.
    ///
    /// - Returns: A `BluringOption` value with the given values.
    public static func noise(level: CGFloat = 0.02, sharpness: CGFloat = 0.4) -> RichImage.BluringOption {
        return RichImage.BluringOption(.noise(level: level, sharpness: sharpness))
    }
    /// Creates a bluring option with zoom mode with a given center and bluring amount.
    ///
    /// - Parameter center: A CGPoint value indicates the bluring center. Using [150.0, 150.0] as default.
    /// - Parameter amount: The bluring amount to affect the bluring effects. Using 20.0 as default.
    ///
    /// - Returns: A `BluringOption` value with the given values.
    public static func zoom(center: CGPoint = CGPoint(x: 150.0, y: 150.0), amount: CGFloat = 20.0) -> RichImage.BluringOption {
        return RichImage.BluringOption(.zoom(center: center, amount: amount))
    }
}
/// A type that can process the UIImage object by add core image bluring filter or using Accelerate.vImage.
///
/// To add `Blurrable` conformance to your custom types, define `image` property and return an UIImage object.
public protocol Blurrable: RichImagable {}

extension Blurrable {
    /// Creates a copy of the receiver by applying a blur filter with the bluring option and render with the given render option.
    ///
    /// Typically use this function to produce an image with the core image's filter. Use vImageBluring if you want creates an
    /// CPU-Based and more efficiently blured image.
    ///
    /// - Parameter bluringOption: A `BluringOption` value indicates the bluring filter info.
    /// - Parameter option       : A value of `RichImage.RenderOption` indicates the rendering options of the image blurring processing.
    ///                            Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the receiver image with applying a blur effect.
    public func blur(_ bluringOption: RichImage.BluringOption, option: RichImage.RenderOption = .auto) -> UIImage! {
        if  let filter  = bluringOption.mode.filter,
            let ciImage = image._makeCiImage()?.applyingFilter(filter.name, withInputParameters: filter.inputParameters),
            let uiImage = type(of: self).make(ciImage, scale: image.scale, orientation: image.imageOrientation, option: option)
        {
            return uiImage
        }
        return nil
    }
}
/// Added Blurrable comformance.
extension UIImage: Blurrable {}
