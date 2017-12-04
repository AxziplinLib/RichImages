//
//  ImageEditingViewController.swift
//  RichImages
//
//  Created by devedbox on 2017/12/3.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit

private func _createContainerScrollView() -> UIScrollView {
    let scrollView = UIScrollView(frame: .zero)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.backgroundColor = .clear
    return scrollView
}

class ImageEditingViewController: UIViewController {
    /// The scroll view of the visible content.
    public lazy var scrollView: UIScrollView = _createContainerScrollView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        _setupScrollView()
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

extension ImageEditingViewController {
    /// Add scroll view to the root view and add constraints to the scroll view.
    fileprivate func _setupScrollView() {
        view.addSubview(scrollView)
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}
