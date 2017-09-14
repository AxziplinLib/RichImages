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
}
