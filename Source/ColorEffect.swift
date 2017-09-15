//
//  ColorEffect.swift
//  RichImages
//
//  Created by devedbox on 2017/9/14.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage

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
/// ColorEffectAppliable conformance of UIImage.
extension UIImage: ColorEffectAppliable { }
