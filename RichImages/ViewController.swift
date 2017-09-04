//
//  ViewController.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var imageView0: UIImageView!
    @IBOutlet weak var imageView1: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let gif = UIImage.gif(named: "Gif")!
        // let image = #imageLiteral(resourceName: "image_sample")
        // let bordered = image.bordered(24.0)
        // let rounded = image.round(40.0, border: 30.0)
        // let cornered = image.cornered
        // let cropped = image.crop(to: CGRect(origin: .zero, size: image.size).insetBy(dx: 0.0, dy: fabs(image.size.height - image.size.width) * 0.5))
        let cropped = gif.crop(fits: gif.size.scale(by: 0.5), using: .center, rendering: .auto)
        // let resized = image.resize(fits: CGSize(width: image.size.height, height: image.size.height), quality: .high)
        // let croppingSize = CGSize(width: image.size.width * 0.5, height: image.size.width * 0.5)
        // let cropped = image.crop(fits: croppingSize, using: .bottomRight)
        // let thumbnail = image.thumbnail(squares: 20, borderWidth: 10, cornerRadius: 10, quality: .high)
        // let thumbnail = image.thumbnail(scalesToFit: 100)
        // let imagefromstring = UIImage.image(from: "imagefromstring", using: UIFont.boldSystemFont(ofSize: 36))
        // let pdf = UIImage.image(fromPDFNamed: "Swift", scalesToFit: UIScreen.main.bounds.size, pageCountLimits: 3)
        // let resizing = UIImage.ResizingMode.center
        // let merged1 = #imageLiteral(resourceName: "image_to_merge").merge(with: [image,#imageLiteral(resourceName: "location_center")], using: .vertically(.topToBottom, resizing))
        // let merged2 = #imageLiteral(resourceName: "image_to_merge").merge(with: [image,#imageLiteral(resourceName: "location_center")], using: .vertically(.bottomToTop, resizing))
        // let color = image.color(at: CGPoint(x: image.size.width-1, y: image.size.height-1), scale: 2.0)
        // let colors = image.majorColors()
        // let fixedImage = #imageLiteral(resourceName: "image_to_merge").grayed?.rotate(by: CGFloat.pi / 6.0)
        // let image1 = UIImage.gif(named: "Gif")!
        // let handled1 = image1.resize(fits: CGSize(width: 120, height: 120), using: .center)
        // let image2 = #imageLiteral(resourceName: "image_to_merge")
        // let handled2 = image2.resize(fits: CGSize(width: 120, height: 80), using: .center)
        imageView0.image = cropped
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

