//
//  ColorAdjustment.swift
//  RichImages
//
//  Created by devedbox on 2017/9/9.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage

extension UIImage {
    /// A type representing the rgba components of color object.
    public struct ColorComponents {
        let r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat
        init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }
        init(_ color: UIColor) {
            var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.init(r: r, g: g, b: b, a: a)
        }
    }
}

extension UIImage.ColorComponents {
    /// Returns a min values of the color component.
    public static var min: UIImage.ColorComponents { return UIImage.ColorComponents(r: 0.0, g: 0.0, b: 0.0, a: 0.0) }
    /// Returns a max values of the color component.
    public static var max: UIImage.ColorComponents { return UIImage.ColorComponents(r: 1.0, g: 1.0, b: 1.0, a: 1.0) }
}

extension UIImage {
    /// Modifies color values to keep them within a specified range.
    ///
    /// At each pixel, color component values less than those in inputMinComponents will be increased to 
    /// match those in inputMinComponents, and color component values greater than those in inputMaxComponents 
    /// will be decreased to match those in inputMaxComponents.
    ///
    /// - Parameter min   : RGBA values for the lower end of the range. A ColorComponents object whose attribute type is CIAttributeTypeRectangle
    ///                     and whose display name is MinComponents. Default value: [0.0, 0.0, 0.0, 0.0].
    /// - Parameter max   : RGBA values for the upper end of the range. A ColorComponents object whose attribute type is CIAttributeTypeRectangle
    ///                     and whose display name is MaxComponents. Default value: [1.0, 1.0, 1.0, 1.0].
    /// - Parameter option: A value of `RenderOption` indicates the rendering options of the image blurring processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// 
    /// - Returns: A copy of the recevier clampped to the given range of color components.
    public func clampColor(min: ColorComponents = .min, max: ColorComponents = .max, option: RenderOption = .auto) -> UIImage! {
        guard let ciImage = _makeCiImage()?.applyingFilter("CIColorClamp", withInputParameters: ["inputMinComponents": CIVector(x: min.r, y: min.g, z: min.b, w: min.a), "inputMaxComponents": CIVector(x: max.r, y: max.g, z: max.b, w:  max.a)]),
              let image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: size.scale(by: scale)), scale: scale, orientation: imageOrientation, option: option)
        else {
            return nil
        }
        return image
    }
    /// Adjusts saturation, brightness, and contrast values.
    ///
    /// To calculate saturation, this filter linearly interpolates between a grayscale image (saturation = 0.0)
    /// and the original image (saturation = 1.0). The filter supports extrapolation: For values large than 1.0, 
    /// it increases saturation.
    ///
    /// To calculate contrast, this filter uses the following formula:
    /// ```
    /// (color.rgb - vec3(0.5)) * contrast + vec3(0.5)
    /// ```
    /// This filter calculates brightness by adding a bias value:
    /// ```
    /// color.rgb + vec3(brightness)
    /// ```
    ///
    /// - Parameter saturation: The saturation component of the color of the receiver image. Default value: 1.0.
    /// - Parameter brightness: The brightness component of the color of the receiver image. Default value: 1.0.
    /// - Parameter contrast  : The contrast component of the color of the receiver image. Default value: 1.0.
    /// - Parameter option    : A value of `RenderOption` indicates the rendering options of the image blurring processing.
    ///                         Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the receiver by adjusting the color components of the receiver image.
    public func adjust(saturation: CGFloat = 1.0, brightness: CGFloat = 1.0, contrast: CGFloat = 1.0, option: RenderOption = .auto) -> UIImage! {
        guard let ciImage = _makeCiImage()?.applyingFilter("CIColorControls", withInputParameters: ["inputSaturation": saturation, "inputBrightness": brightness, "inputContrast": contrast]),
            let image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: size.scale(by: scale)), scale: scale, orientation: imageOrientation, option: option)
            else {
                return nil
        }
        return image
    }
}
