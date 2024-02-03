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
    @IBOutlet weak var filterButton: UIButton!
    
    @IBOutlet weak var menuButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var menuButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var menuButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterButtonTrailingConstraint: NSLayoutConstraint!
    
    weak var mediaView: MediaViewController?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TitleView.self)
    )

    override func awakeFromNib() {

        initButtons()
        initTitle()
        initText()
        
        doneButton.isHidden = true
        doneButton.addTarget(self, action: #selector(endEdit), for: .touchUpInside)
        
        cancelButton.isHidden = true
        cancelButton.addTarget(self, action: #selector(cancelEdit), for: .touchUpInside)
        
        backButton.isHidden = true
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        
        filterButton.isHidden = true
        filterButton.addTarget(self, action: #selector(editFilter), for: .touchUpInside)
        
        let guestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(titleTouched))
        title.addGestureRecognizer(guestureRecognizer)
    }
    
    func showFilterButton() {
        filterButton.isHidden = false
    }
    
    func hideFilterButton() {
        filterButton.isHidden = true
    }
    
    func hideMenu() {
        menuButton.isHidden = true
        
        //shift the filter button over to fill the gap of the now hidden menu button
        filterButtonTrailingConstraint.constant = menuButtonTrailingConstraint.constant
        
        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }
    
    func showMenu() {
        menuButton.isHidden = false
        
        setFilterButtonTrailingConstraint()
        
        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }
    
    func initMenu(allowEdit: Bool) {
        
        let zoomIn = UIAction(title: Strings.TitleZoomIn, image: UIImage(systemName: "plus.magnifyingglass")) { [weak self] action in
            self?.mediaView?.zoomInGrid()
        }

        let zoomOut = UIAction(title: Strings.TitleZoomOut, image: UIImage(systemName: "minus.magnifyingglass")) { [weak self] action in
            self?.mediaView?.zoomOutGrid()
        }
        
        let filter = UIAction(title: "Filter", image: UIImage(systemName: "calendar.badge.clock")) { [weak self] action in
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
        updateButtons()
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
        filterButton.isHidden = true

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
    
    @objc func editFilter() {
        mediaView?.filter()
    }
    
    private func initButtons() {
        
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.layer.masksToBounds = true
        
        filterButton.layer.masksToBounds = true
        
        updateButtons()
    }
    
    private func updateButtons() {
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            updateMenuButtonWithSize(30)
            updateFilterButtonWithSize(30)
            //filterButtonTrailingConstraint.constant = 30
        } else {
            updateMenuButtonWithSize(20)
            updateFilterButtonWithSize(20)
            //filterButtonTrailingConstraint.constant = 56
        }
        
        setFilterButtonTrailingConstraint()
    }
    
    private func setFilterButtonTrailingConstraint() {
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            filterButtonTrailingConstraint.constant = 76
        } else {
            filterButtonTrailingConstraint.constant = 56
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
    
    private func updateFilterButtonWithSize(_ size: CGFloat) {
        
        let configuration = UIImage.SymbolConfiguration(pointSize: size - 5, weight: .bold)
        let dateImage = UIImage(systemName: "calendar.badge.clock", withConfiguration: configuration)
        let double = size * 2
        
        filterButton.setImage(dateImage, for: .normal)
        filterButton.layer.cornerRadius = size
        
        filterButtonWidthConstraint.constant = double
        filterButtonHeightConstraint.constant = double
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

