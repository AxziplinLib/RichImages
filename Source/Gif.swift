//
//  Gif.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import ImageIO
import CoreGraphics

// MARK: - AnimatedImage.

extension UIImage {
    /// Indicates whether the image is animated image contains multiple images.
    public var animatable: Bool { return images?.count ?? 0 > 1 }
    /// Creates a `GIF` animated image with the given data by get the frame info of the image source.
    ///
    /// - Parameter data : A data object that image source reading from.
    /// - Parameter scale: The scale factor of the source image.
    ///
    /// - Returns: An instance of animated image contains multiple frame of images.
    public class func gif(_ data: Data, scale: CGFloat = 1.0) -> UIImage! {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let imagesCount = CGImageSourceGetCount(imageSource)
        
        var animatedImage: UIImage!
        if imagesCount > 1 {
            var images  : [UIImage]    = []
            var duration: TimeInterval = 0.0
            for index in 0..<imagesCount {
                guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else { continue }
                images.append(UIImage(cgImage: cgImage, scale: scale, orientation: .up))
                // Calculate durations.
                guard let frameProps = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as NSDictionary? else { continue }
                guard let gifProps   = frameProps[kCGImagePropertyGIFDictionary as String] as? NSDictionary else { continue }
                
                var frameDuration: TimeInterval = 0.1
                if let delayTimeUnclampedProp = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval {
                    frameDuration = delayTimeUnclampedProp
                } else if let delayTimeProp = gifProps[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
                    frameDuration = delayTimeProp
                }
                // Many annoying ads specify a 0 duration to make an image flash as quickly as possible.
                // We follow Firefox's behavior and use a duration of 100 ms for any frames that specify
                // a duration of <= 10 ms. See <rdar://problem/7689300> and <http://webkit.org/b/36082>
                // for more information.
                frameDuration = max(frameDuration, 0.1)
                duration += frameDuration
            }
            
            if duration == 0.0 { duration = 0.1 * Double(imagesCount) }
            
            animatedImage = UIImage.animatedImage(with: images, duration: duration)
        } else {
            animatedImage = UIImage(data: data)
        }
        
        return animatedImage
    }
    /// Creates a `GIF` animated image with the contents of a `URL`.
    ///
    /// - parameter url: The `URL` to read image source data.
    /// - parameter options: Options for the read operation. Default value is `[]`.
    ///
    /// - Returns: An instance of animated image contains multiple frame of images.
    public class func gif(contentsOf url: URL, options: Data.ReadingOptions = [], scale: CGFloat = 1.0) -> UIImage! {
        guard let data = try? Data(contentsOf: url, options: options) else {return nil }
        return gif(data, scale: scale)
    }
    /// Creates a `GIF` animated image with the name path extension in a `Bundle`.
    ///
    /// - parameter name: The name to load data from.
    /// - parameter bundle: The bundle that file data locate in.
    ///
    /// - Returns: An instance of animated image contains multiple frame of images.
    public class func gif(named name: String, `in` bundle: Bundle = .main) -> UIImage! {
        var fileName: String = name; var scale: CGFloat = 1.0
        switch UIScreen.main.scale {
        case 3.0: //@3x
            fileName += "@3x"; scale = 3.0
        case 2.0: //@2x
            fileName += "@2x"; scale = 2.0
        default: // @1x
            fileName += "@1x"; scale = 1.0
        }
        if let path = bundle.path(forResource: fileName, ofType: "gif"), let image = gif(contentsOf: URL(fileURLWithPath: path), scale: scale) {
            return image
        } else {
            guard let path = bundle.path(forResource: name, ofType: "gif") else { return nil }
            return gif(contentsOf: URL(fileURLWithPath: path))
        }
    }
}
