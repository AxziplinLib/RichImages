//
//  ImageView.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit

class ImageView: UIImageView {

    override var intrinsicContentSize: CGSize {
        var size = CGSize(width: self.bounds.width, height: 0.0)
        if  let img = image {
            size.height = img.size.height * min(1.0, (size.width / img.size.width))
        } else {
            size.height = 0.5
        }
        return size
    }
    override var image: UIImage? {
        didSet { invalidateIntrinsicContentSize() }
    }
}
