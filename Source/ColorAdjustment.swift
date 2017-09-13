//
//  ColorAdjustment.swift
//  RichImages
//
//  Created by devedbox on 2017/9/9.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage

/// MARK: - ColorComponents.

extension UIColor {
    /// A type representing the rgba components of color object.
    public struct Components {
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

extension UIColor.Components {
    /// Returns a min values of the color component.
    public static var min: UIColor.Components { return UIColor.Components(r: 0.0, g: 0.0, b: 0.0, a: 0.0) }
    /// Returns a max values of the color component.
    public static var max: UIColor.Components { return UIColor.Components(r: 1.0, g: 1.0, b: 1.0, a: 1.0) }
}

// MARK: - ColorPolynomial.

extension RichImage {
    /// A type representing the coefficients fields in the processing parameters of filter `CIColorPolynomial`.
    public struct ColorPolynomial {
        let zero: CGFloat, one: CGFloat, double: CGFloat, triple: CGFloat
        /// Returns the identity color polynomial.
        static var identity: ColorPolynomial { return ColorPolynomial(zero: 0.0, one: 1.0, double: 0.0, triple: 0.0) }
    }
}

// MARK: - CIVector.

extension CIVector {
    /// Initializes a vector that is initialized with values provided by a UIColor.Components structure.
    /// The UIColor.Components structure’s r, g, b and a values are stored in the vector’s x, y, z and w properties.
    ///
    /// - Parameters colorComponent: A color component.
    /// - Returns: A CIVector object with the values in the given color component.
    public convenience init(colorComponent: UIColor.Components) {
        self.init(x: colorComponent.r, y: colorComponent.g, z: colorComponent.b, w: colorComponent.a)
    }
    /// Initializes a vector that is initialized with values provided by a RichImage.ColorPolynomial structure.
    /// The RichImage.ColorPolynomial structure’s zero, one, double and triple values are stored in the vector’s 
    /// x, y, z and w properties.
    ///
    /// - Parameters colorPolynomial: A color polynomial.
    /// - Returns: A CIVector object with the values in the given color component.
    public convenience init(colorPolynomial: RichImage.ColorPolynomial) {
        self.init(x: colorPolynomial.zero, y: colorPolynomial.one, z: colorPolynomial.double, w: colorPolynomial.triple)
    }
}

// MARK: - ColorAdjustable.

/// A protocol defines the color adjustment processing of `RichImage` by applying the filters in category
/// `kCICategoryColorAdjustment`.
///
/// Any conforming type is required to implement the getter `image` so that the conforming type can be used 
/// to adjust color of the returned UIImage object.
///
public protocol ColorAdjustable: RichImagable { /* ColorAdjustable field. */ }
extension ColorAdjustable {
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
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image blurring processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the recevier clampped to the given range of color components.
    public func clamp(min: UIColor.Components = .min, max: UIColor.Components = .max, option: RichImage.RenderOption = .auto) -> UIImage! {
        let size  = image.size
        let scale = image.scale
        let imageOrientation = image.imageOrientation
        
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorClamp", withInputParameters: ["inputMinComponents": CIVector(x: min.r, y: min.g, z: min.b, w: min.a), "inputMaxComponents": CIVector(x: max.r, y: max.g, z: max.b, w:  max.a)]),
              let _image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: size.scale(by: scale)), scale: scale, orientation: imageOrientation, option: option) else {
                return nil
        }
        return _image
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
    /// - Parameter option    : A value of `RichImage.RenderOption` indicates the rendering options of the image blurring processing.
    ///                         Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the receiver by adjusting the color components of the receiver image.
    public func adjust(saturation: CGFloat = 1.0, brightness: CGFloat = 1.0, contrast: CGFloat = 1.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        let size  = image.size
        let scale = image.scale
        let imageOrientation = image.imageOrientation
        
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorControls", withInputParameters: ["inputSaturation": saturation, "inputBrightness": brightness, "inputContrast": contrast]),
              let _image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: size.scale(by: scale)), scale: scale, orientation: imageOrientation, option: option) else {
                return nil
        }
        return _image
    }
    /// Multiplies source color values and adds a bias factor to each color component.
    ///
    /// This filter performs a matrix multiplication, as follows, to transform the color vector:
    ///
    /// - s.r = dot(s, redVector)
    /// - s.g = dot(s, greenVector)
    /// - s.b = dot(s, blueVector)
    /// - s.a = dot(s, alphaVector)
    /// - s = s + bias
    ///
    ///
    ///- Note: As with all color filters, this operation is performed in the working color space of the Core Image context
    ///        (CIContext) executing the filter, using unpremultiplied pixel color values. If you see unexpected results,
    ///        verify that your output and working color spaces are set up as intended.
    ///
    /// - Parameter component: The color component to be multiplied by the color of the receiver. Using `UIColor.Components.max` as default.
    /// - Parameter bias     : The color component to be added by the color of the receiver. Using `UIColor.Components.min` as default.
    /// - Parameter option   : A value of `RichImage.RenderOption` indicates the rendering options of the image blurring processing.
    ///                        Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the receiver by multiplying and adding the given color components.
    public func multiply(_ component: UIColor.Components = .max, bias: UIColor.Components = .min, option: RichImage.RenderOption = .auto) -> UIImage! {
        let size  = image.size
        let scale = image.scale
        let imageOrientation = image.imageOrientation
        
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorMatrix", withInputParameters: ["inputRVector": CIVector(x: component.r, y: 0.0, z: 0.0, w: 0.0), "inputGVector": CIVector(x: 0.0, y: component.g, z: 0.0, w: 0.0), "inputBVector": CIVector(x: 0.0, y: 0.0, z: component.b, w: 0.0), "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: component.a), "inputBiasVector": CIVector(colorComponent: bias)]),
              let _image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: size.scale(by: scale)), scale: scale, orientation: imageOrientation, option: option) else {
                return nil
        }
        return _image
    }
    /// Modifies the pixel values in an image by applying a set of cubic polynomials.
    ///
    /// For each pixel, the value of each color component is treated as the input to a cubic polynomial, 
    /// whose coefficients are taken from the corresponding input coefficients parameter in ascending order.
    /// Equivalent to the following formula:
    ///```
    /// r = rCoeff[0] + rCoeff[1] * r + rCoeff[2] * r*r + rCoeff[3] * r*r*r
    ///```
    ///```
    /// g = gCoeff[0] + gCoeff[1] * g + gCoeff[2] * g*g + gCoeff[3] * g*g*g
    ///```
    ///```
    /// b = bCoeff[0] + bCoeff[1] * b + bCoeff[2] * b*b + bCoeff[3] * b*b*b
    ///```
    ///```
    /// a = aCoeff[0] + aCoeff[1] * a + aCoeff[2] * a*a + aCoeff[3] * a*a*a
    ///```
    ///
    /// - Note: As with all color filters, this operation is performed in the working color space of the Core Image 
    ///         context (CIContext) executing the filter, using unpremultiplied pixel color values. If you see unexpected
    ///         results, verify that your output and working color spaces are set up as intended.
    ///
    /// - Parameter red   : The `red` field polynomial coefficients to modify the color source image. Using [0.0, 1.0, 0.0, 0.0] as default.
    /// - Parameter green : The `green` field polynomial coefficients to modify the color source image. Using [0.0, 1.0, 0.0, 0.0] as default.
    /// - Parameter blue  : The `blue` field polynomial coefficients to modify the color source image. Using [0.0, 1.0, 0.0, 0.0] as default.
    /// - Parameter alpha : The `alpha` field polynomial coefficients to modify the color source image. Using [0.0, 1.0, 0.0, 0.0] as default.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image blurring processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the receiver modified with the given polynomial coefficients.
    public func polynomial(red: RichImage.ColorPolynomial = .identity, green: RichImage.ColorPolynomial = .identity, blue: RichImage.ColorPolynomial = .identity, alpha: RichImage.ColorPolynomial = .identity, option: RichImage.RenderOption = .auto) -> UIImage! {
        let size  = image.size
        let scale = image.scale
        let imageOrientation = image.imageOrientation
        
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorPolynomial", withInputParameters: ["inputRedCoefficients": CIVector(colorPolynomial: red), "inputGreenCoefficients": CIVector(colorPolynomial: green), "inputBlueCoefficients": CIVector(colorPolynomial: blue), "inputAlphaCoefficients": CIVector(colorPolynomial: alpha)]),
            let _image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: size.scale(by: scale)), scale: scale, orientation: imageOrientation, option: option) else {
                return nil
        }
        return _image
    }
    /// Adjusts the exposure setting for an image similar to the way you control exposure for a
    /// camera when you change the F-stop.
    ///
    /// This filter multiplies the color values, as follows, to simulate exposure change by the specified F-stops:
    ///```
    /// s.rgb * pow(2.0, ev)
    ///```
    ///
    /// - Parameter exposureValue: The exposure value indicates the exposures of the image. The image will be
    ///                            under-exposed if the value is negative. Using 0.5 as default.
    /// - Parameter option       : A value of `RichImage.RenderOption` indicates the rendering options of the image blurring processing.
    ///                            Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the source image by adjusting the exposure value.
    public func expose(_ exposureValue: CGFloat = 0.5, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIExposureAdjust", withInputParameters: ["inputEV": exposureValue]),
            let _image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return _image
    }
}
/// ColorAdjustable conformance of UIImage.
extension UIImage: ColorAdjustable { }
