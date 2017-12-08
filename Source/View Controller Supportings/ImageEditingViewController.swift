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
    private lazy var _scrollView: UIScrollView = _createContainerScrollView()
    
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

// MARK: Public Interface.

extension ImageEditingViewController {
    public var scrollView: UIScrollView { return _scrollView }
}

extension ImageEditingViewController {
    /// Add scroll view to the root view and add constraints to the scroll view.
    fileprivate func _setupScrollView() {
        view.addSubview(_scrollView)
        _scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        _scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        _scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        _scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}
