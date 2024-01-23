//
//  TitleView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/31/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import os.log

protocol MediaViewController: AnyObject {
    func zoomInGrid()
    func zoomOutGrid()
    func filter()
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
        initText()
        
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
        
        let zoomIn = UIAction(title: Strings.TitleZoomIn, image: UIImage(systemName: "plus.magnifyingglass")) { [weak self] action in
            self?.mediaView?.zoomInGrid()
        }

        let zoomOut = UIAction(title: Strings.TitleZoomOut, image: UIImage(systemName: "minus.magnifyingglass")) { [weak self] action in
            self?.mediaView?.zoomOutGrid()
        }
        
        let filter = UIAction(title: "Filter", image: UIImage(systemName: "line.3.horizontal.decrease.circle")) { [weak self] action in
            self?.mediaView?.filter()
        }
    
        if allowEdit {
            let edit = UIAction(title: Strings.TitleEdit, image: UIImage(systemName: "pencil")) { [weak self] action in
                self?.mediaView?.edit()
                self?.beginEdit()
            }
            menuButton.menu = UIMenu(children: [zoomIn, zoomOut, filter, edit])
        } else {
            menuButton.menu = UIMenu(children: [zoomIn, zoomOut, filter])
        }

        backButtonConstraint.constant = 4
    }
    
    func updateTitleSize() {
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            updateMenuButtonWithSize(30)
        } else {
            updateMenuButtonWithSize(20)
        }
        
        setTitleSize()
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
    
    func resetEdit() {
        
        menuButton.isHidden = false
        title.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
    }
    
    @objc func endEdit() {

        menuButton.isHidden = false
        title.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
        
        mediaView?.endEdit()
    }
    
    @objc func cancelEdit() {

        menuButton.isHidden = false
        title.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
        
        mediaView?.cancel()
    }
    
    @objc func goBack() {
       mediaView?.cancel()
    }
    
    @objc func titleTouched() {
        mediaView?.titleTouched()
    }
    
    private func initMenuButton() {
        
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.layer.masksToBounds = true
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            updateMenuButtonWithSize(30)
        } else {
            updateMenuButtonWithSize(20)
        }
    }
    
    private func updateMenuButtonWithSize(_ size: CGFloat) {
        
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
        let image = UIImage(systemName: "ellipsis", withConfiguration: configuration)
        let double = size * 2
        
        menuButton.setImage(image, for: .normal)
        menuButton.layer.cornerRadius = size
        
        menuButtonWidthConstraint.constant = double
        menuButtonHeightConstraint.constant = double
    }
    
    private func initTitle() {
        setTitleSize()
    }
    
    private func initText() {
        doneButton.setTitle(Strings.TitleApply, for: .normal)
        cancelButton.setTitle(Strings.TitleCancel, for: .normal)
    }
    
    private func setTitleSize() {
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            title.font = .boldSystemFont(ofSize: 36)
        } else {
            title.font = .boldSystemFont(ofSize: 24)
        }
    }
}

