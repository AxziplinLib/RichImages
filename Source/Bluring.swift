//
//  Bluring.swift
//  RichImages
//
//  Created by devedbox on 2017/9/9.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage

extension UIImage {
    enum BluringMode {
        case box(radius: CGFloat)
        case disc(radius: CGFloat)
        case gaussian(radius: CGFloat)
        case mask(mask: UIImage, radius: CGFloat)
        case median
        case motion(angle: CGFloat, radius: CGFloat)
        case noise(level: CGFloat, sharpness: CGFloat)
        case zoom(center: CGPoint, amount: CGFloat)
    }
    
    public struct BluringOption {
        fileprivate let mode: BluringMode
        init(_ bluringMode: BluringMode) {
            self.mode = bluringMode
        }
    }
}

extension UIImage.BluringMode {
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

extension UIImage.BluringOption {
    public static func box(radius: CGFloat = 10.0) -> UIImage.BluringOption {
        return UIImage.BluringOption(.box(radius: radius))
    }
    public static func disc(radius: CGFloat = 8.0) -> UIImage.BluringOption {
        return UIImage.BluringOption(.disc(radius: radius))
    }
    public static func gaussian(radius: CGFloat = 10.0) -> UIImage.BluringOption {
        return UIImage.BluringOption(.gaussian(radius: radius))
    }
    public static func mask(_ mask: UIImage, radius: CGFloat = 10.0) -> UIImage.BluringOption {
        return UIImage.BluringOption(.mask(mask: mask, radius: radius))
    }
    public static var  median: UIImage.BluringOption {
        return UIImage.BluringOption(.median)
    }
    public static func motion(angle: CGFloat = 0.0, radius: CGFloat = 20.0) -> UIImage.BluringOption {
        return UIImage.BluringOption(.motion(angle: angle, radius: radius))
    }
    public static func noise(level: CGFloat = 0.02, sharpness: CGFloat = 0.4) -> UIImage.BluringOption {
        return UIImage.BluringOption(.noise(level: level, sharpness: sharpness))
    }
    public static func zoom(center: CGPoint = CGPoint(x: 150.0, y: 150.0), amount: CGFloat = 20.0) -> UIImage.BluringOption {
        return UIImage.BluringOption(.zoom(center: center, amount: amount))
    }
}

extension UIImage {
    public func blur(_ bluringOption: BluringOption, option: RenderOption) -> UIImage! {
        if  let filter = bluringOption.mode.filter,
            let ciImage = _makeCiImage()?.applyingFilter(filter.name, withInputParameters: filter.inputParameters),
            let image = type(of: self).make(ciImage, scale: scale, orientation: imageOrientation, option: option)
        {
            return image
        }
        return nil
    }
}
