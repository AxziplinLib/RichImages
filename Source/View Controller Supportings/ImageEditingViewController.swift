//
//  ImageEditingViewController.swift
//  RichImages
//
//  Created by devedbox on 2017/12/3.
//  Copyright © 2017年 devedbox. All rights reserved.
//

import UIKit

class ImageEditingViewController: UIViewController {
    /// The scroll view of the visible content.
    private lazy var _scrollView: UIScrollView = { () -> UIScrollView in
        let scrollView = UIScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        return scrollView
    }()
    /// Content view for image, tool bar or other views.
    private lazy var _contentView: UIView = { () -> UIView in
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    /// Image view to show the result of image.
    private lazy var _imageView: _SizeFitsImageView = { () -> _SizeFitsImageView in
        let imageView = _SizeFitsImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
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

// MARK: - _SizeFitsImageView.

extension ImageEditingViewController {
    fileprivate class _SizeFitsImageView: UIImageView {
        override var intrinsicContentSize: CGSize {
            return super.intrinsicContentSize
        }
    }
}

// MARK: - Public Interface.

extension ImageEditingViewController {
    public var scrollView: UIScrollView { return _scrollView }
}

// MARK: - Private.

extension ImageEditingViewController {
    /// Add scroll view to the root view and add constraints to the scroll view.
    fileprivate func _setupScrollView() {
        view.addSubview(_scrollView)
        _scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        _scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        _scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        _scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    fileprivate func _setupContentView() {
        _scrollView.addSubview(_contentView)
        _contentView.leadingAnchor.constraint(equalTo: _scrollView.leadingAnchor).isActive = true
        _contentView.trailingAnchor.constraint(equalTo: _scrollView.trailingAnchor).isActive = true
        _contentView.topAnchor.constraint(equalTo: _scrollView.topAnchor).isActive = true
        _contentView.bottomAnchor.constraint(equalTo: _scrollView.bottomAnchor).isActive = true
    }
}
