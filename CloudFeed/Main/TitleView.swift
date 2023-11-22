//
//  TitleView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/31/23.
//

import UIKit
import os.log

protocol MediaViewController : AnyObject {
    func zoomInGrid()
    func zoomOutGrid()
    func edit()
    func endEdit()
    func cancel()
    func titleTouched()
}

class TitleView: UIView {

    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var backButtonConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var menuButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var menuButtonHeightConstraint: NSLayoutConstraint!
    
    weak var mediaView: MediaViewController?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TitleView.self)
    )

    override func awakeFromNib() {

        initMenuButton()
        initTitle()
        
        doneButton.isHidden = true
        doneButton.addTarget(self, action: #selector(endEdit), for: .touchUpInside)
        
        cancelButton.isHidden = true
        cancelButton.addTarget(self, action: #selector(cancelEdit), for: .touchUpInside)
        
        backButton.isHidden = true
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        
        let guestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(titleTouched))
        title.addGestureRecognizer(guestureRecognizer)
    }
    
    func hideMenu() {
        menuButton.isHidden = true
    }
    
    func showMenu() {
        menuButton.isHidden = false
    }
    
    func initMenu(allowEdit: Bool) {
        
        let zoomIn = UIAction(title: "Zoom In", image: UIImage(systemName: "plus.magnifyingglass")) { action in
            self.mediaView?.zoomInGrid()
        }

        let zoomOut = UIAction(title: "Zoom Out", image: UIImage(systemName: "minus.magnifyingglass")) { action in
            self.mediaView?.zoomOutGrid()
        }
    
        if allowEdit {
            let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { action in
                self.mediaView?.edit()
                self.beginEdit()
            }
            menuButton.menu = UIMenu(children: [zoomIn, zoomOut, edit])
        } else {
            menuButton.menu = UIMenu(children: [zoomIn, zoomOut])
        }
        
        backButtonConstraint.constant = 8
    }
    
    func initNavigation() {
        title.isHidden = false
        backButton.isHidden = false
        doneButton.isHidden = true
        cancelButton.isHidden = true
    }
    
    func beginEdit() {

        menuButton.isHidden = true
        title.isHidden = true
        
        doneButton.isHidden = false
        cancelButton.isHidden = false
    }
    
    @objc func endEdit() {

        menuButton.isHidden = false
        title.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
        
        self.mediaView?.endEdit()
    }
    
    @objc func cancelEdit() {

        menuButton.isHidden = false
        title.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
        
        self.mediaView?.cancel()
    }
    
    @objc func goBack() {
       self.mediaView?.cancel()
    }
    
    @objc func titleTouched() {
        Self.logger.debug("titleTouched()")
        self.mediaView?.titleTouched()
    }
    
    private func initMenuButton() {
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.layer.masksToBounds = true
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            initMenuButtonWithSize(30)
        } else {
            initMenuButtonWithSize(20)
        }
    }
    
    private func initMenuButtonWithSize(_ size: CGFloat) {
        
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
        let image = UIImage(systemName: "ellipsis", withConfiguration: configuration)
        let double = size * 2
        
        menuButton.setImage(image, for: .normal)
        menuButton.layer.cornerRadius = size
        
        menuButtonWidthConstraint.constant = double
        menuButtonHeightConstraint.constant = double
    }
    
    private func initTitle() {
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            title.font = .boldSystemFont(ofSize: 36)
        } else {
            title.font = .boldSystemFont(ofSize: 24)
        }
    }
}

