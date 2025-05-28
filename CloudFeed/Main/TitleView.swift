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

@MainActor
protocol MediaViewController: AnyObject {
    func zoomInGrid()
    func zoomOutGrid()
    func filter()
    func edit()
    func endEdit()
    func select()
    func updateLayout(_ layout: String)
    func updateMediaType(_ type: Global.FilterType)
}

@MainActor
protocol NavigationDelegate: AnyObject {
    func cancel()
    func titleTouched()
    func showInfo()
}

class TitleView: UIView {
    
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var backButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var actionButtonStackView: UIStackView!
    
    weak var mediaView: MediaViewController?
    weak var navigationDelegate: NavigationDelegate?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TitleView.self)
    )
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initSubviews()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

        MainActor.assumeIsolated {
            
            minimumContentSizeCategory = .large
            
            title.minimumContentSizeCategory = .accessibilityMedium

            initText()
            
            infoButton.isHidden = true
            infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
            
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
    }
    
    func showFilterButton() {
        filterButton.isHidden = false
    }
    
    func hideFilterButton() {
        filterButton.isHidden = true
    }
    
    func initMenu(allowEdit: Bool, allowSelect: Bool, layoutType: String, filterType: Global.FilterType) {
        
        let zoomIn = UIAction(title: Strings.TitleZoomIn, image: UIImage(systemName: "plus.magnifyingglass")) { [weak self] action in
            self?.mediaView?.zoomInGrid()
        }
        
        let zoomOut = UIAction(title: Strings.TitleZoomOut, image: UIImage(systemName: "minus.magnifyingglass")) { [weak self] action in
            self?.mediaView?.zoomOutGrid()
        }
        
        let zoomMenu = UIMenu(title: "", options: .displayInline, children: [zoomIn, zoomOut])
        
        
        let filter = UIAction(title: Strings.TitleFilter, image: UIImage(systemName: "line.3.horizontal.decrease.circle")) { [weak self] action in
            self?.mediaView?.filter()
        }
        
        let layout: UIAction
        
        if layoutType == Global.shared.layoutTypeSquare {
            layout = UIAction(title: Strings.TitleAspectRatioGrid, image: UIImage(systemName: "rectangle.grid.3x2")) { [weak self] action in
                self?.mediaView?.updateLayout(Global.shared.layoutTypeAspectRatio)
            }
        } else {
            layout = UIAction(title: Strings.TitleSquareGrid, image: UIImage(systemName: "square.grid.3x3")) { [weak self] action in
                self?.mediaView?.updateLayout(Global.shared.layoutTypeSquare)
            }
        }
        
        let allType = UIAction(title: Strings.TitleAllItems, image: UIImage(systemName: "photo.on.rectangle")) { [weak self] action in
            self?.mediaView?.updateMediaType(.all)
        }
        
        let imageType = UIAction(title: Strings.TitleImagesOnly, image: UIImage(systemName: "photo")) { [weak self] action in
            self?.mediaView?.updateMediaType(.image)
        }
        
        let videoType = UIAction(title: Strings.TitleVideosOnly, image: UIImage(systemName: "play.circle")) { [weak self] action in
            self?.mediaView?.updateMediaType(.video)
        }
        
        switch filterType {
        case .all:
            allType.state = .on
            break
        case .image:
            imageType.state = .on
            break
        case .video:
            videoType.state = .on
            break
        }
        
        let typeMenu = UIMenu(title: "", options: [.displayInline, .singleSelection], children: [allType, imageType, videoType])
        
        var editAction: UIAction?
        var selectAction: UIAction?
        
        if allowEdit {
            editAction = UIAction(title: Strings.TitleEdit, image: UIImage(systemName: "pencil")) { [weak self] action in
                self?.mediaView?.edit()
            }
        }
        
        if allowSelect {
            selectAction = UIAction(title: Strings.ShareAction, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] action in
                self?.mediaView?.select()
            }
        }

        if editAction == nil && selectAction != nil {
            menuButton.menu = UIMenu(children: [zoomMenu, filter, layout, selectAction!, typeMenu])
        } else if editAction != nil && selectAction == nil {
            menuButton.menu = UIMenu(children: [zoomMenu, filter, layout, editAction!, typeMenu])
        } else if editAction != nil && selectAction != nil {
            menuButton.menu = UIMenu(children: [zoomMenu, filter, layout, editAction!, selectAction!, typeMenu])
        } else {
            menuButton.menu = UIMenu(children: [zoomMenu, filter, layout, typeMenu])
        }
        
        backButtonConstraint.constant = 0
    }
    
    func initTitleOnly() {
        backButtonConstraint.constant = 8
        menuButton.isHidden = true
    }
    
    func initNavigation(withMenu: Bool) {
        
        title.isHidden = false
        
        infoButton.isHidden = false
        actionButtonStackView.isHidden = false
    
        backButton.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
        
        menuButton.isHidden = !withMenu
    }
    
    func beginEdit() {
        
        title.isHidden = true
        actionButtonStackView.isHidden = true
        
        doneButton.isHidden = false
        cancelButton.isHidden = false
    }
    
    func beginSelect() {
        doneButton.setTitle(Strings.ShareAction, for: .normal)
        beginEdit() //buttons are the same as edit mode
    }

    func resetEdit() {
        
        actionButtonStackView.isHidden = false
        title.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
    }
    
    @objc func endEdit() {
        
        actionButtonStackView.isHidden = false
        title.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
        
        mediaView?.endEdit()
    }
    
    @objc func cancelEdit() {
        
        actionButtonStackView.isHidden = false
        title.isHidden = false
        
        doneButton.isHidden = true
        cancelButton.isHidden = true
        
        navigationDelegate?.cancel()
    }
    
    @objc func goBack() {
        navigationDelegate?.cancel()
    }
    
    @objc func titleTouched() {
        navigationDelegate?.titleTouched()
    }
    
    @objc func editFilter() {
        mediaView?.filter()
    }
    
    @objc func infoTapped() {
        navigationDelegate?.showInfo()
    }
    
    private func initText() {
        
        menuButton.accessibilityLabel = Strings.TitleMenu
        
        doneButton.setTitle(Strings.TitleApply, for: .normal)
        cancelButton.setTitle(Strings.TitleCancel, for: .normal)
    }
    
    private func initSubviews() {
        
        let nib = UINib(nibName: "TitleView", bundle: Bundle(for: type(of: self)))
        let container = nib.instantiate(withOwner: self, options: nil).first as! UIView
        
        addSubview(container)
        
        container.backgroundColor = self.backgroundColor
        container.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leftAnchor.constraint(equalTo: leftAnchor),
            container.rightAnchor.constraint(equalTo: rightAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

