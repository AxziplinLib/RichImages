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
              let _image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return _image
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
              let _image = type(of: self).make(ciImage, from: CGRect(origin: .zero, size: image.size.scale(by: image.scale)), scale: image.scale, orientation: image.imageOrientation, option: option) else {
                return nil
        }
        return _image
    }
}

/// ColorEffectAppliable conformance of UIImage.
extension UIImage: ColorEffectAppliable { }
