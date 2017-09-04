//
//  Merging.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreGraphics

// MARK: - Merging.

extension UIImage {
    /// A type representing the mode of the merging of images. Currently supporting `overlay`, `horizontal` and `vertical`.
    public enum MergingMode {
        /// A type representing the direction on the horizontal.
        public enum Horizontal {
            /// Indicates from-left-to-right direction.
            case leftToRight
            /// Indicates from-right-to-left direction.
            case rightToLeft
        }
        /// A type representing the direction on the vertical.
        public enum Vertical {
            /// Indicates from-top-to-bottom direction.
            case topToBottom
            /// Indicates from-bottom-to-top direction.
            case bottomToTop
        }
        /// Indicates the merged image will over lay on the original image.
        case overlay(ResizingMode)
        /// Indicates the images to merge will lay on the horizontal stack.
        case horizontally(Horizontal, ResizingMode)
        /// Indicates the images to merge will lay on the vertical stack.
        case vertically(Vertical, ResizingMode)
    }
    /// Creates a new instance of UIImage with the given images merged to the receiver by using the merging mode.
    /// The same direction resizing mode of the horizontal or vertical merging mode act just like the overlay mode.
    /// Animated image supported. Each frame of the animated image will merge with the given images if animatable,
    ///
    /// - Parameter images: A collection of instance of UIImage to merge with.
    /// - Parameter mode  : A value defined in the type `MergingMode` used to calculate the rectangle area of the images.
    ///
    /// - Returns: A new image object with all the images merged using the specific merging mode.
    public func merge(with images: [UIImage], using mode: MergingMode) -> UIImage! {
        guard !animatable else { return UIImage.animatedImage(with: self.images!.flatMap({ _img in autoreleasepool{ _img.merge(with: images, using: mode) } }), duration: duration) }
        
        var resultImage: UIImage = self
        images.forEach { (image) in autoreleasepool{
            var resultRect = CGRect(origin: .zero, size: resultImage.size)
            var pageRect   = CGRect(origin: .zero, size: image.size)
            var imageRect  : CGRect = .zero
            switch mode {
            case .overlay(let resizing):
                imageRect = CGRect(origin: .zero, size: CGSize(width: max(resultRect.width, pageRect.width), height: max(resultRect.height, pageRect.height)))
                switch resizing {
                case .scaleToFill:
                    resultRect = imageRect
                    pageRect   = imageRect
                case .scaleAspectFit:
                    resultRect = _rect(scales: resultRect, toFit: imageRect)
                    pageRect   = _rect(scales: pageRect  , toFit: imageRect)
                case .scaleAspectFill:
                    resultRect = _rect(scales: resultRect, toFill: imageRect)
                    pageRect   = _rect(scales: pageRect  , toFill: imageRect)
                case .center:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 0.5
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 0.5
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 0.5
                case .top:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 0.5
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 0.5
                case .bottom:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 0.5
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 0.5
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 1.0
                case .left:
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 0.5
                case .right:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 1.0
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 0.5
                case .topLeft: break
                case .topRight:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 1.0
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 1.0
                case .bottomLeft:
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 1.0
                case .bottomRight:
                    resultRect.origin.x = (imageRect.width  - resultRect.width ) * 1.0
                    resultRect.origin.y = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x   = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y   = (imageRect.height - pageRect.height  ) * 1.0
                }
                resultImage = resultImage._merge(with: image, size: imageRect.size, beginsRect: resultRect, endsRect: pageRect)
            case .horizontally(let horizontal, let resizing):
                imageRect.size.width = resultRect.width + pageRect.width
                if horizontal == .leftToRight { pageRect.origin.x = resultRect.width } else {
                    resultRect.origin.x = pageRect.width
                }
                switch resizing {
                case .scaleToFill:
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.size.height = imageRect.height
                    pageRect.size.height   = imageRect.height
                case .scaleAspectFit : fallthrough
                case .scaleAspectFill:
                    let scalesToFitResult  = _rect(equalHeightScales: horizontal == .leftToRight ? resultRect : pageRect, toFit: horizontal == .leftToRight ? pageRect : resultRect)
                    resultRect             = horizontal == .leftToRight ? scalesToFitResult.0 : scalesToFitResult.1
                    pageRect               = horizontal == .leftToRight ?  scalesToFitResult.1: scalesToFitResult.0
                    imageRect.size.width   = scalesToFitResult.0.width + scalesToFitResult.1.width
                    imageRect.size.height  = max(scalesToFitResult.0.height, scalesToFitResult.1.height)
                case .center:
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 0.5
                case .top:
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                case .bottom:
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 1.0
                case .left:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    if horizontal == .leftToRight { pageRect.origin.x =               0.0 } else {
                        resultRect.origin.x =                                          0.0
                    }
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 0.5
                case .right:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.x    = (imageRect.width - resultRect.width)   * 1.0
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 0.5
                    pageRect.origin.x      = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 0.5
                case .topLeft:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    if horizontal == .leftToRight { pageRect.origin.x =               0.0 } else {
                        resultRect.origin.x =                                          0.0
                    }
                case .topRight:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.x    = (imageRect.width - resultRect.width)   * 1.0
                    pageRect.origin.x      = (imageRect.width  - pageRect.width )   * 1.0
                case .bottomLeft:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    if horizontal == .leftToRight { pageRect.origin.x =               0.0 } else {
                        resultRect.origin.x =                                          0.0
                    }
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 1.0
                case .bottomRight:
                    imageRect.size.width   = max(resultRect.width, pageRect.width)
                    imageRect.size.height  = max(resultRect.height, pageRect.height)
                    resultRect.origin.x    = (imageRect.width - resultRect.width)   * 1.0
                    resultRect.origin.y    = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x      = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y      = (imageRect.height - pageRect.height  ) * 1.0
                }
                resultImage = resultImage._merge(with: image, size: imageRect.size, beginsRect: resultRect, endsRect: pageRect)
            case .vertically(let vertical, let resizing):
                imageRect.size.height = resultRect.height + pageRect.height
                if vertical == .topToBottom { pageRect.origin.y = resultRect.height } else {
                    resultRect.origin.y = pageRect.height
                }
                switch resizing {
                case .scaleToFill:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    resultRect.size.width = imageRect.width
                    pageRect.size.width   = imageRect.width
                case .scaleAspectFit : fallthrough
                case .scaleAspectFill:
                    let scalesToFitResult = _rect(equalWidthScales: vertical == .topToBottom ? resultRect : pageRect, toFit: vertical == .topToBottom ? pageRect : resultRect)
                    resultRect            = vertical == .topToBottom ? scalesToFitResult.0 : scalesToFitResult.1
                    pageRect              = vertical == .topToBottom ? scalesToFitResult.1 : scalesToFitResult.0
                    imageRect.size.width  = max(scalesToFitResult.0.width, scalesToFitResult.1.width)
                    imageRect.size.height = scalesToFitResult.0.height + scalesToFitResult.1.height
                case .center:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    resultRect.origin.x   = (imageRect.width - resultRect.width)   * 0.5
                    pageRect.origin.x     = (imageRect.width - pageRect.width  )   * 0.5
                case .top:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.x   = (imageRect.width - resultRect.width)   * 0.5
                    pageRect.origin.x     = (imageRect.width - pageRect.width  )   * 0.5
                    if vertical == .topToBottom { pageRect.origin.y =                0.0 } else {
                        resultRect.origin.y =                                         0.0
                    }
                case .bottom:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.x   = (imageRect.width - resultRect.width  ) * 0.5
                    resultRect.origin.y   = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x     = (imageRect.width - pageRect.width    ) * 0.5
                    pageRect.origin.y     = (imageRect.height - pageRect.height  ) * 1.0
                case .left:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                case .right:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    resultRect.origin.x   = (imageRect.width - resultRect.width )  * 1.0
                    pageRect.origin.x     = (imageRect.width  - pageRect.width  )  * 1.0
                case .topLeft:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    if vertical == .topToBottom { pageRect.origin.y =                0.0 } else {
                        resultRect.origin.y =                                         0.0
                    }
                case .topRight:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.x   = (imageRect.width - resultRect.width)   * 1.0
                    pageRect.origin.x     = (imageRect.width  - pageRect.width )   * 1.0
                    if vertical == .topToBottom { pageRect.origin.y =                0.0 } else {
                        resultRect.origin.y =                                         0.0
                    }
                case .bottomLeft:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.y   = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.y     = (imageRect.height - pageRect.height  ) * 1.0
                case .bottomRight:
                    imageRect.size.width  = max(resultRect.width, pageRect.width)
                    imageRect.size.height = max(resultRect.height, pageRect.height)
                    resultRect.origin.x   = (imageRect.width - resultRect.width)   * 1.0
                    resultRect.origin.y   = (imageRect.height - resultRect.height) * 1.0
                    pageRect.origin.x     = (imageRect.width  - pageRect.width   ) * 1.0
                    pageRect.origin.y     = (imageRect.height - pageRect.height  ) * 1.0
                }
                resultImage = resultImage._merge(with: image, size: imageRect.size, beginsRect: resultRect, endsRect: pageRect)
            }
            } }
        return resultImage
    }
    
    private func _merge(with image: UIImage, size: CGSize, beginsRect: CGRect, endsRect: CGRect) -> UIImage! {
        guard let cgImage = _makeCgImage(), let mergingCgImage = image._makeCgImage() else { return nil }
        var mergedImage: UIImage! = self
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let transform = CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0.0, y: -size.height)
        context.concatenate(transform)
        
        context.draw(cgImage, in: beginsRect.applying(transform))
        context.draw(mergingCgImage, in: endsRect.applying(transform))
        mergedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        return mergedImage
    }
    
    private func _rect(equalHeightScales rect1: CGRect, toFit rect2: CGRect) -> (CGRect, CGRect) {
        var resultRect1 = rect1
        var resultRect2 = rect2
        
        if resultRect1.height >= resultRect2.height {
            let ratio = resultRect1.height / resultRect2.height
            resultRect2.size.width  = resultRect2.width * ratio
            resultRect2.size.height = resultRect1.height
        } else {
            let ratio = resultRect2.height / resultRect1.height
            resultRect1.size.width  = resultRect1.width * ratio
            resultRect1.size.height = resultRect2.height
        }
        resultRect1.origin.y = 0.0
        resultRect2.origin.y = 0.0
        resultRect2.origin.x = resultRect1.width
        
        return (resultRect1, resultRect2)
    }
    
    private func _rect(equalWidthScales rect1: CGRect, toFit rect2: CGRect) -> (CGRect, CGRect) {
        var resultRect1 = rect1
        var resultRect2 = rect2
        
        if resultRect1.width >= resultRect2.width {
            let ratio = resultRect1.width / resultRect2.width
            resultRect2.size.height = resultRect2.height * ratio
            resultRect2.size.width  = resultRect1.width
        } else {
            let ratio = resultRect2.width / resultRect1.width
            resultRect1.size.height = resultRect1.height * ratio
            resultRect1.size.width  = resultRect2.width
        }
        resultRect1.origin.x = 0.0
        resultRect2.origin.x = 0.0
        resultRect2.origin.y = resultRect1.height
        
        return (resultRect1, resultRect2)
    }
    
    private func _rect(scales rect1: CGRect, toFit rect2: CGRect) -> CGRect {
        let maxRect = CGRect(origin: .zero, size: CGSize(width: max(rect1.width, rect2.width), height: max(rect1.height, rect2.height)))
        
        var resultRect = rect1
        
        if resultRect.height >= resultRect.width { // Aspect fit height.
            let ratio = maxRect.height / resultRect.height
            resultRect.size.width  = resultRect.width * ratio
            resultRect.size.height = maxRect.height
            resultRect.origin.x    = (maxRect.width - resultRect.width) * 0.5
        } else {
            let ratio = maxRect.width / resultRect.width
            resultRect.size.height = resultRect.height * ratio
            resultRect.size.width  = maxRect.width
            resultRect.origin.y    = (maxRect.height - resultRect.height) * 0.5
        }
        
        return resultRect
    }
    
    private func _rect(scales rect1: CGRect, toFill rect2: CGRect) -> CGRect {
        let maxRect = CGRect(origin: .zero, size: CGSize(width: max(rect1.width, rect2.width), height: max(rect1.height, rect2.height)))
        
        var resultRect = rect1
        
        if resultRect.height < resultRect.width { // Aspect fill width.
            let ratio = maxRect.height / resultRect.height
            resultRect.size.width  = resultRect.width * ratio
            resultRect.size.height = maxRect.height
            resultRect.origin.x    = (maxRect.width - resultRect.width) * 0.5
        } else {
            let ratio = maxRect.width / resultRect.width
            resultRect.size.height = resultRect.height * ratio
            resultRect.size.width  = maxRect.width
            resultRect.origin.y    = (maxRect.height - resultRect.height) * 0.5
        }
        
        return resultRect
    }
}
