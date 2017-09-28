//
//  ViewController.swift
//  RichImages
//
//  Created by devedbox on 2017/9/4.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit
import CoreImage

class ViewController: UIViewController {

    @IBOutlet weak var imageView0: UIImageView!
    @IBOutlet weak var imageView1: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Make sure all the core image contexts are initialized.
        RichImage.initialize(RichImage.RenderOption.Destination.availableGPURelatedDestinations)
        // let gif = UIImage.gif(named: "Gif")!
        let date = Date()
        // let data = "https://www.baidu.com".data(using: .isoLatin1)!
        let image = #imageLiteral(resourceName: "image_to_merge")
        // let bordered = image.bordered(100.0)
        // let rounded = image.makeCornered(.gpu(.default))
        // let size = CGSize(width: image.size.width * 0.5, height: image.size.height * 0.8)
        // let resizing = UIImage.ResizingMode.center
        // let result = image.perspectiveCorrect(topLeft    : CGPoint(x: 0.0, y: image.size.height * 0.7),
        //                                      topRight   : CGPoint(x: image.size.width, y: image.size.height),
        //                                      bottomLeft : CGPoint(x: 0.0, y: image.size.height * 0.3),
        //                                     bottomRight: CGPoint(x: image.size.width, y: 0.0))
        // let result = image.scale(to: 0.5).flip(horizontally: true, option: .gpu(.default))
        // let result = image.straightenRotate(by: CGFloat.pi / 6.0, option: .gpu(.default))
        // let result = UIImage.generateAztecCode(data, layers: 32.0).resize(fills: CGSize(width: 300, height: 300), option: .cpu(.none))
        // let result = UIImage.generateCode128Barcode(data).resize(fits: UIScreen.main.bounds.size, using: .scaleAspectFit, option: .cpu(.none))
        // let result = UIImage.generateConstantColor(.orange).resize(fills: CGSize(width: 300, height: 300), option: .cpu(.none)).makeCornered(.gpu(.default))
        // let result = UIImage.generateLenticularHalo(color: .green)
        // let result = UIImage.generatePDF417Barcode(data)
        // let result = UIImage.generateRandom(size: CGSize(width: 300, height: 300))
        // let result = UIImage.generateStarShine(color: .orange, size: CGSize(width: 1600, height: 1600))
        // let result = UIImage.generateStripes(color0: .white, color1: .black, size: CGSize(width: 1600, height: 1600))
        // let result = UIImage.generateSunbeams(color: .orange)
        // let result = UIImage.generateCheckerboard(color0: .black, color1: .white, size: CGSize(width: 500, height: 500))
        // let result = UIImage.generateQRCode(data).resize(fills: CGSize(width: 300, height: 300), option: .cpu(.none))
        // let cornered = image.cornered
        // let cropped = image.crop(to: CGRect(origin: .zero, size: image.size).insetBy(dx: 0.0, dy: fabs(image.size.height - image.size.width) * 0.5))
        // let result = image.blur(.box(radius: 100.0), option: .auto)
        // let result = image.clampColor(min: UIImage.ColorComponents(r: 0.2, g: 0.2, b: 0.2, a: 0.2), max: UIImage.ColorComponents(r: 0.8, g: 0.8, b: 0.8, a: 0.8))
        // let result = image.multiply(UIColor.Components(r: 0.5, g: 0.30, b: 0.7, a: 0.9), bias: .min, option: .auto)
        // let result = image.polynomial(red: RichImage.ColorPolynomial(zero: 0.0, one: 0.0, double: 0.0, triple: 0.4), green: RichImage.ColorPolynomial(zero: 0.0, one: 0.0, double: 0.5, triple: 0.8), blue: RichImage.ColorPolynomial(zero: 0.0, one: 0.0, double: 0.5, triple: 1.0), alpha: RichImage.ColorPolynomial(zero: 0.0, one: 1.0, double: 1.0, triple: 1.0), option: .auto)
        // let result = image.adjustToneCurve(point0: CGPoint(x: 0.1, y: 0.3))
        // let result = image.adjustVibrance(amount: 10.0)
        // let result = image.adjustWhitePoint(color: .orange)
        // let result = image.crossPolynomial(red: [0.5, 0.1, 0.5, 0.8, 0.9])
        // let result = image.invert()
        // let result = image.map(color: .red)
        // let result = image.posterize()
        // let result = image.maskToAlpha()
        // let result = image.minimumComponent()
        // let result = image.transfer()
        // let result = image.sepiaTone()
        // let result = image.vignette(radius: 3.0, intensity: 1.0)
        let result = image.vignetteEffect(radius: 3.0, intensity: 1.0)
        // let transform = CGAffineTransform(rotationAngle: CGFloat.pi / 6.0).scaledBy(x: 1.0, y: 3.0)
        // let result = image.applying(transform, option: .cpu(.none))
        // let cropped = image.crop(fits: image.size.scale(by: 0.5), using: .center, rendering: .cpu).lightBlur
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
        print("Cost timing: \(Date().timeIntervalSince(date))")
        imageView1.image = result
        // imageView1.backgroundColor = .black
        imageView0.image = image
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController {
    override var prefersStatusBarHidden: Bool { return true }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { return .fade }
}

//extension ViewController {
//    private func _clut(dimension: Int) -> Data {
//        var cubeSpace = Array<Array<Float>>(repeating: Array<Float>(repeating: 0.0, count: 4), count: dimension * dimension * dimension)
//        for b in 0..<dimension {
//            for g in 0..<dimension {
//                for r in 0..<dimension {
//                    let index = b * dimension * dimension + g * dimension + r
//                    cubeSpace[index][0] = 0.0
//                    cubeSpace[index][1] = 0.0
//                    cubeSpace[index][2] = 0.0
//                    cubeSpace[index][3] = 0.0
//                }
//            }
//        }
//    }
//}
