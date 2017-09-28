//
//  ColorEffect.swift
//  RichImages
//
//  Created by devedbox on 2017/9/14.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage
import CoreGraphics

// MARK: - ColorCrossPolynomial.

extension RichImage {
    /// A type representing the coefficients fields in the processing parameters of filter `CIColorPolynomial`.
    public struct ColorCrossPolynomial {
        // The ten crossing polynomial fields start from zero.
        let zero: CGFloat, one: CGFloat, two: CGFloat, three: CGFloat, four: CGFloat, five: CGFloat, six: CGFloat, seven: CGFloat, eight: CGFloat, nine: CGFloat
        // Destined initializer.
        public init(_ zero: CGFloat, _ one: CGFloat, _ two: CGFloat, _ three: CGFloat, _ four: CGFloat, _ five: CGFloat, _ six: CGFloat, _ seven: CGFloat, _ eight: CGFloat, _ nine: CGFloat) {
            self.zero  = zero
            self.one   = one
            self.two   = two
            self.three = three
            self.four  = four
            self.five  = five
            self.six   = six
            self.seven = seven
            self.eight = eight
            self.nine  = nine
        }
    }
}

extension RichImage.ColorCrossPolynomial: ExpressibleByArrayLiteral {
    public typealias Element = CGFloat
    /// Creates an instance initialized with the given elements.
    ///
    /// The rest field will be initialzed as 0.0 if the count of the elements is less than
    /// 10.
    public init(arrayLiteral elements: Element...) {
        var _elements: [Element] = Array<Element>(repeating: 0.0, count: 10)
        for (index, ele) in elements.enumerated() {
            if index >= _elements.endIndex { break }
            _elements[index] = ele
        }
        self.init(_elements[0], _elements[1], _elements[2], _elements[3], _elements[4], _elements[5], _elements[6], _elements[7], _elements[8], _elements[9])
    }
}

extension CIVector {
    /// Initializes a vector that is initialized with values provided by a RichImage.ColorCrossPolynomial structure.
    ///
    /// - Parameters colorPolynomial: A color crossing polynomial.
    /// - Returns: A CIVector object with the values in the given color component.
    public convenience init(colorCrossPolynomial polynomial: RichImage.ColorCrossPolynomial) {
        let values = [polynomial.zero, polynomial.one, polynomial.two, polynomial.three, polynomial.four, polynomial.five, polynomial.six, polynomial.seven, polynomial.eight, polynomial.nine]
        self.init(values: values, count: 10)
    }
}

// MARK: - ColorEffectAppliable.

/// A protocol defines the color effect processing of `RichImage` by applying the filters in category
/// `kCICategoryColorEffect`.
///
/// Any conforming type is required to implement the getter `image` so that the conforming type can be used
/// to applying color effects of the returned UIImage object.
///
public protocol ColorEffectAppliable: RichImagable { }

extension ColorEffectAppliable {
    /// Modifies the pixel values in an image by applying a set of polynomial cross-products.
    ///
    /// Each component in an output pixel out is determined using the component values in the input pixel in according
    /// to a polynomial cross product with the input coefficients. That is, the red component of the output pixel is 
    /// calculated using the inputRedCoefficients parameter (abbreviated rC below) using the following formula:
    ///```
    /// out.r =  in.r * rC[0] +        in.g * rC[1] +        in.b * rC[2]
    /// + in.r * in.r * rC[3] + in.g * in.g * rC[4] + in.b * in.b * rC[5]
    /// + in.r * in.g * rC[6] + in.g * in.b * rC[7] + in.b * in.r * rC[8]
    /// + rC[9]
    ///```
    /// Then, the formula is repeated to calculate the blue and green components of the output pixel using the blue and 
    /// green coefficients, respectively.
    ///
    /// This function can be used for advanced color space and tone mapping conversions, such as imitating the color reproduction
    /// of vintage photography film.
    ///
    /// - Note: As with all color filters, this operation is performed in the working color space of the Core Image context (CIContext)
    ///         executing the filter, using unpremultiplied pixel color values. If you see unexpected results, verify that your output 
    ///         and working color spaces are set up as intended.
    ///
    /// - Parameter red   : The `red` field polynomial coefficients to modify the color source image. Using [1.0, 0.0, ...] as default.
    /// - Parameter green : The `green` field polynomial coefficients to modify the color source image. Using [0.0, 1.0, 0.0, ...] as default.
    /// - Parameter blue  : The `blue` field polynomial coefficients to modify the color source image. Using [0.0, 0.0, 1.0, 0.0, ...] as default.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the receiver modified with the given cross polynomial coefficients.
    public func crossPolynomial(red: RichImage.ColorCrossPolynomial = [1.0], green: RichImage.ColorCrossPolynomial = [0.0, 1.0], blue: RichImage.ColorCrossPolynomial = [0.0, 0.0, 1.0], option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorCrossPolynomial", withInputParameters: ["inputRedCoefficients": CIVector(colorCrossPolynomial: red), "inputGreenCoefficients": CIVector(colorCrossPolynomial: green), "inputBlueCoefficients": CIVector(colorCrossPolynomial: blue)]),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
}

extension ColorEffectAppliable {
    /// Uses a three-dimensional color table to transform the source image pixels.
    ///
    /// This filter maps color values in the input image to new color values using a three-dimensional color lookup table 
    /// (also called a CLUT or color cube). For each RGBA pixel in the input image, the filter uses the R, G, and B component 
    /// values as indices to identify a location in the table; the RGBA value at that location becomes the RGBA value of the 
    /// output pixel.
    ///
    /// Use the inputCubeData parameter to provide data formatted for use as a color lookup table, and the inputCubeDimension 
    /// parameter to specify the size of the table. This data should be an array of texel values in 32-bit floating-point RGBA 
    /// linear premultiplied format. The inputCubeDimension parameter identifies the size of the cube by specifying the length 
    /// of one side, so the size of the array should be inputCubeDimension cubed times the size of a single texel value. In the 
    /// color table, the R component varies fastest, followed by G, then B. Listing 1 shows a basic pattern for creating color
    /// cube data in `objective-c`.
    ///
    /// ```
    /// // Allocate and opulate color cube table
    /// const unsigned int size = 64;
    /// float *cubeData = (float *)malloc(size * size * size * sizeof(float) * 4);
    /// for (int b = 0; b < size; b++) {
    ///    for (int g = 0; g < size; r++) {
    ///        for (int r = 0; r < size; r ++) {
    ///            cubeData[b][g][r][0] = `output R value`;
    ///            cubeData[b][g][r][1] = `output G value`;
    ///            cubeData[b][g][r][2] = `output B value`;
    ///            cubeData[b][g][r][3] = `output A value`;
    ///        }
    ///    }
    /// }
    /// // Put the table in a data object and create the filter
    /// NSData *data = [NSData dataWithBytesNoCopy:cubeData length:cubeDataSize freeWhenDone:YES];
    /// CIFilter *colorCube = [CIFilter filterWithName:@"CIColorCube" withInputParameters:@{@"inputCubeDimension": @(size),@"inputCubeData": data,}];
    ///```
    /// For another example of this filter in action, see `Chroma Key Filter Recipe` in `Core Image Programming Guide`.
    ///
    /// - Note: As with all color filters, this operation is performed in the working color space of the Core Image context
    ///         (CIContext) executing the filter, using unpremultiplied pixel color values. If you see unexpected results, 
    ///         verify that your output and working color spaces are set up as intended.
    ///
    /// - Parameter dimension : The dimension of the cube data for each x, y and z components.
    /// - Parameter data      : The COLOR-LOOKUP_TABLE data of the cube data.
    /// - Parameter colorSpace: The color space to draw the target image.
    /// - Parameter option    : A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the srouce image by applying the clut data.
    public func transform(_ dimension: CGFloat, clut data: Data, into colorSpace: CGColorSpace? = nil, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter(colorSpace == nil ? "CIColorCube" : "CIColorCubeWithColorSpace", withInputParameters: { () -> [String: Any]? in
            if let cs = colorSpace {
                return ["inputCubeDimension": dimension, "inputCubeData": data, "inputColorSpace": cs]
            } else {
                return ["inputCubeDimension": dimension, "inputCubeData": data]
            }
        }()),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
}

extension ColorEffectAppliable {
    /// Inverts the colors in an image.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by invert the color of the source image.
    public func invert(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorInvert", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Performs a nonlinear transformation of source color values using mapping values provided in a table.
    ///
    /// - Parameter gradientImage: The input gradient image used as the color look up table to map the source image.
    /// - Parameter option       : A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                            Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the source image with the given image mapped.
    public func map(gradientImage: CIImage, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorMap", withInputParameters: ["inputGradientImage": gradientImage]),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Remaps colors so they fall within shades of a single color.
    ///
    /// - Parameter color    : The input color object used the map the color of the source image.
    /// - Parameter intensity: A CGFloat value indicates the intensity of the mapping. Using 1.0 as default.
    /// - Parameter option   : A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                        Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the source image by the remapping processing.
    public func map(color: UIColor, intensity: CGFloat = 1.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorMonochrome", withInputParameters: ["inputColor": CIColor(color: color), "inputIntensity": intensity]),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Remaps red, green, and blue color components to the number of brightness values you specify for each color component.
    ///
    /// This filter flattens colors to achieve a look similar to that of a silk-screened poster.
    ///
    /// - Parameter levels: The input levels parameter to remap the source image. Using 6.0 as default.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the source image by posterizing with the given levels.
    public func posterize(levels: CGFloat = 6.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIColorPosterize", withInputParameters: ["inputLevels": levels]),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Maps luminance to a color ramp of two colors.
    ///
    /// False color is often used to process astronomical and other scientific data, such as ultraviolet and x-ray images.
    ///
    /// - Parameter color0: A UIColor object at field `color0` used to applying the false color effect.
    /// - Parameter color1: A UIColor object at field `color1` used to applying the false color effect.
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the source image by applying false color effect.
    public func falseColor(color0: UIColor, color1: UIColor, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIFalseColor", withInputParameters: ["inputColor0": CIColor(color: color0), "inputColor1": CIColor(color: color1)]),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
}

extension ColorEffectAppliable {
    /// Converts a grayscale image to a white image that is masked by alpha.
    ///
    /// The white values from the source image produce the inside of the mask; the black values become completely transparent.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the source image by masking to alpha channel.
    public func maskToAlpha(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIMaskToAlpha", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
}

extension ColorEffectAppliable {
    /// Returns a grayscale image from max(r,g,b).
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A graystyle copy of the source image from max(r,g,b).
    public func maximumComponent(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIMaximumComponent", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Returns a grayscale image from min(r,g,b).
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A graystyle copy of the source image from min(r,g,b).
    public func minimumComponent(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIMinimumComponent", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
}

extension ColorEffectAppliable {
    /// Applies a preconfigured set of effects that imitate vintage photography film with exaggerated color.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying photo effect chrome.
    public func chrome(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIPhotoEffectChrome", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Applies a preconfigured set of effects that imitate vintage photography film with diminished color.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying photo effect fade.
    public func fade(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIPhotoEffectFade", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Applies a preconfigured set of effects that imitate vintage photography film with distorted colors.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying photo effect instant.
    public func instant(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIPhotoEffectInstant", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Applies a preconfigured set of effects that imitate black-and-white photography film with low contrast.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying photo effect mono.
    public func mono(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIPhotoEffectMono", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Applies a preconfigured set of effects that imitate black-and-white photography film with exaggerated contrast.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying photo effect noir.
    public func noir(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIPhotoEffectNoir", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Applies a preconfigured set of effects that imitate vintage photography film with emphasized cool colors.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying photo effect process.
    public func process(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIPhotoEffectProcess", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Applies a preconfigured set of effects that imitate black-and-white photography film without significantly altering contrast.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying photo effect tonal.
    public func tonal(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIPhotoEffectTonal", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Applies a preconfigured set of effects that imitate vintage photography film with emphasized warm colors.
    ///
    /// - Parameter option: A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                     Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying photo effect transfer.
    public func transfer(option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIPhotoEffectTransfer", withInputParameters: nil),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
}

extension ColorEffectAppliable {
    /// Maps the colors of an image to various shades of brown.
    ///
    /// - Parameter intensity: A CGFloat value indicates the intensity of the effect. Using 1.0 as default.
    /// - Parameter option   : A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                        Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    /// - Returns: A copy of the source image by applying sepia tone effect.
    public func sepiaTone(intensity: CGFloat = 1.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CISepiaTone", withInputParameters: ["inputIntensity": intensity]),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
}

extension ColorEffectAppliable {
    /// Reduces the brightness of an image at the periphery.
    ///
    /// - Parameter radius   : A CGFloat value indicates the radius of applying vignette effect. Using 1.0 as default.
    /// - Parameter intensity: A CGFloat value indicates the intensity of the effect. Using 0.0 as default.
    /// - Parameter option   : A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                        Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the source image by applying the vignette effect.
    public func vignette(radius: CGFloat = 1.0, intensity: CGFloat = 0.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIVignette", withInputParameters: ["inputRadius": radius, "inputIntensity": intensity]),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
    /// Modifies the brightness of an image around the periphery of a specified region.
    ///
    /// - Parameter center   : The centered region to make the brightness effect. Default value: [150.0, 150.0]
    /// - Parameter radius   : A CGFloat value indicates the radius of applying vignette effect. The value is valid in [0.0, 0.0].
    ///                        Using 0.0 as default.
    /// - Parameter intensity: A CGFloat value indicates the intensity of the effect. The value is valid in [0.0, 1.0],
    ///                        Using 1.0 as default.
    /// - Parameter option   : A value of `RichImage.RenderOption` indicates the rendering options of the image processing.
    ///                        Note that the CPU-Based option is not available in ths section. Using `.auto` by default.
    ///
    /// - Returns: A copy of the source image by applying the vignette effect.
    public func vignetteEffect(center: CGPoint = CGPoint(x: 150.0, y: 150.0), radius: CGFloat = 0.0, intensity: CGFloat = 1.0, option: RichImage.RenderOption = .auto) -> UIImage! {
        guard let ciImage = image._makeCiImage()?.applyingFilter("CIVignetteEffect", withInputParameters: ["inputCenter": CIVector(cgPoint: center), "inputRadius": radius, "inputIntensity": intensity]),
              let img = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return img
    }
}

/// ColorEffectAppliable conformance of UIImage.
extension UIImage: ColorEffectAppliable { }
