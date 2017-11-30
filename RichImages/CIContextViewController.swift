//
//  CIContextViewController.swift
//  RichImages
//
//  Created by devedbox on 2017/11/30.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit

class CIContextViewController: UIViewController {
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        RichImage.initialize([.cpu, .gpu(.metal), .gpu(.openGLES)])
        var content = "CPU: availale\n\n"
        if let _ = RichImage.default.ciContext(at: .gpu(.metal)) {
            content += "Metal GPU: available\n\n"
        } else {
            content += "Metal GPU: unavailable\n\n"
        }
        if let _ = RichImage.default.ciContext(at: .gpu(.openGLES)) {
            content += "OpenGLES GPU: available\n\n"
        } else {
            content += "OpenGLES GPU: unavailable\n\n"
        }
        
        label.text = content
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
