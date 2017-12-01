//
//  TableViewController.swift
//  RichImages
//
//  Created by devedbox on 2017/11/30.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {
    /// The image object.
    var image = #imageLiteral(resourceName: "image_to_merge")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .scrollableAxes
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: Table view delegate.
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let resultViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ViewController") as! ViewController
        resultViewController.original = image
        switch indexPath.section {
        case 1:// Bluring effects.
            resultViewController.title = tableView.cellForRow(at: indexPath)?.textLabel?.text
            navigationController?.pushViewController(resultViewController, animated: true)
            let renderOption = RichImage.RenderOption(dest: .gpu(.openGLES))
            switch indexPath.row {
            case 0:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.lightBlur
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            case 1:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.extraLightBlur
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            case 2:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.darkBlur
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            case 3:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.blur(.box(), option: renderOption)
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            case 4:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.blur(.disc(), option: renderOption)
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            case 5:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.blur(.gaussian(), option: renderOption)
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            case 6:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.blur(.median, option: renderOption)
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
        
            case 7:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.blur(.motion(), option: renderOption)
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            case 8:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.blur(.noise(), option: renderOption)
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            case 9:
                DispatchQueue(label: "com.bluring.rich-images", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                    let img = self.image.blur(.zoom(), option: renderOption)
                    DispatchQueue.main.sync {
                        resultViewController.result = img
                    }
                }
            default: break
            }
        default: break
        }
    }
}
