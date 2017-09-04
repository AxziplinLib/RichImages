//
//  ImageView.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit

class ImageView: UIImageView {

    override var intrinsicContentSize: CGSize { return CGSize(width: self.bounds.width, height: image?.size.height ?? 0.0) }
    override var image: UIImage? {
        didSet { invalidateIntrinsicContentSize() }
    }

}
