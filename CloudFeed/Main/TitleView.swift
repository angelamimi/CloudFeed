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
    
    weak var mediaView: MediaViewController?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TitleView.self)
    )

    override func awakeFromNib() {
        menuButton.showsMenuAsPrimaryAction = true
        
        menuButton.layer.cornerRadius = 20
        menuButton.layer.masksToBounds = true
        
        doneButton.isHidden = true
        doneButton.addTarget(self, action: #selector(endEdit), for: .touchUpInside)
        
        cancelButton.isHidden = true
        cancelButton.addTarget(self, action: #selector(cancelEdit), for: .touchUpInside)
        
        backButton.isHidden = true
        backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        
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
    
        title.font = .boldSystemFont(ofSize: 22)
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
    
    @objc func back() {
       self.mediaView?.cancel()
    }
    
    @objc func titleTouched() {
        Self.logger.debug("titleTouched()")
        self.mediaView?.titleTouched()
    }
}

