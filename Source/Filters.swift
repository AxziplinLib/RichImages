//
//  Filters.swift
//  RichImages
//
//  Created by devedbox on 2017/9/5.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage

// MARK: - Kernel.

/// A type managing the codes of the kernel to applying the custom filters.
fileprivate struct _Kernel {}
extension _Kernel {
    /// Returns the kernel codes to generate a rounded radius effect.
    fileprivate static var roundRadius: String {
        return "kernel vec4 roundr(sampler src, float r)"                                                             +
        "{"                                                                                                           +
            "vec2  p      = destCoord();"                                                                             +
            "vec4  extent = samplerExtent(src);"                                                                      +
            "vec4  pixel  = sample(src, samplerCoord(src));"                                                          +
            "float ty     = extent.w - r;"                                                                            +
            "float rx     = extent.z - r;"                                                                            +
            "float r_s    = pow(r, 2.0);"                                                                             +
            "float xd_s   = pow((p.x - r), 2.0);"                                                                     +
            "float yd_s   = pow((p.y - r), 2.0);"                                                                     +
            "float rxd_s  = pow((p.x - rx), 2.0);"                                                                    +
            "float tyd_s  = pow((p.y - ty), 2.0);"                                                                    +
            "if ((xd_s + yd_s) >= r_s && (xd_s + tyd_s) >= r_s && (rxd_s + yd_s) >= r_s && (rxd_s + tyd_s) >= r_s) {" +
                "if (p.x <= r  && p.y <= r ) { pixel.a = max(0.0, 1.0 - (sqrt((xd_s  + yd_s)) - r ) * 1.0); }"        +
                "if (p.x <= r  && p.y >= ty) { pixel.a = max(0.0, 1.0 - (sqrt((xd_s  + tyd_s)) - r) * 1.0); }"        +
                "if (p.x >= rx && p.y <= r ) { pixel.a = max(0.0, 1.0 - (sqrt((rxd_s + yd_s)) - r ) * 1.0); }"        +
                "if (p.x >= rx && p.y >= ty) { pixel.a = max(0.0, 1.0 - (sqrt((rxd_s + tyd_s)) - r) * 1.0); }"        +
            "}"                                                                                                       +
         "return premultiply(pixel);"                                                                                 +
        "}"
    }
}

// MARK: - RoundRadiusFilter.

/// A type representing the filter to generate a rounded raduis effect.
internal class RoundRadiusFilter: CIFilter {
    var inputImage: CIImage!
    var inputRadius: CGFloat = 0.0
    let kernel = CIKernel(string: _Kernel.roundRadius)
    
    override var attributes: [String : Any] {
        return ["inputRadius": [kCIAttributeMin:0.0, kCIAttributeMax: max(inputImage?.extent.width ?? 0.0, inputImage?.extent.height ?? 0.0), kCIAttributeSliderMin: 0.0, kCIAttributeSliderMax: max(inputImage?.extent.width ?? 0.0, inputImage?.extent.height ?? 0.0), kCIAttributeDefault: 0.0, kCIAttributeIdentity: 0.0, kCIAttributeType: kCIAttributeTypeScalar ] as Any]
    }
    
    override var outputImage: CIImage? {
        guard let image = inputImage, let kernel = self.kernel else { return nil }
        return kernel.apply(withExtent: image.extent, roiCallback: { return $1 }, arguments: [image, inputRadius])
    }
}

extension RoundRadiusFilter {
    convenience init(_ inputImage: CIImage, radius: CGFloat) {
        self.init()
        self.inputImage = inputImage
        self.inputRadius = radius
    }
}

extension CIImage {
    /// Creates a copy of this image with rounded corners in pixels.
    ///
    /// - Parameter radius: The radius of the corner drawing. The value must not be negative.
    ///
    /// - Returns: An image with rounded corners.
    public func round(by radius: CGFloat) -> CIImage! {
        return RoundRadiusFilter(self, radius: radius).outputImage
    }
}
