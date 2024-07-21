//
//  PagerController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/2/23.
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
import NextcloudKit
import MediaPlayer
import os.log

class PagerController: UIViewController, MediaViewController {
    
    var coordinator: PagerCoordinator!
    var viewModel: PagerViewModel!
    
    private var titleViewHeightAnchor: NSLayoutConstraint?
    
    private weak var titleView: TitleView?
    
    weak var pageViewController: UIPageViewController? {
        return self.children[0] as? UIPageViewController
    }
    
    weak var currentViewController: ViewerController? {
        return self.pageViewController?.viewControllers![0] as? ViewerController
    }
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PagerController.self)
    )
    
    override func viewSafeAreaInsetsDidChange() {
        titleView?.translatesAutoresizingMaskIntoConstraints = false
        titleView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        titleView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        titleView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageViewController?.delegate = viewModel
        pageViewController?.dataSource = viewModel
        
        let longtapGestureRecognizer = UILongPressGestureRecognizer()
        longtapGestureRecognizer.delaysTouchesBegan = true
        longtapGestureRecognizer.minimumPressDuration = 0.3
        longtapGestureRecognizer.delegate = self
        longtapGestureRecognizer.addTarget(self, action: #selector(didLongpressGestureEvent(gestureRecognizer:)))
        
        pageViewController?.view.addGestureRecognizer(longtapGestureRecognizer)
        
        let metadata = viewModel.currentMetadata()
        let viewerMedia = viewModel.initViewer()
        
        pageViewController?.setViewControllers([viewerMedia], direction: .forward, animated: true, completion: nil)
        
        titleView = Bundle.main.loadNibNamed("TitleView", owner: self, options: nil)?.first as? TitleView
        self.view.addSubview(titleView!)
        
        titleView?.mediaView = self
        titleView?.title.text = metadata.fileNameView
        titleView?.initNavigation()
        
        setFavoriteMenu(isFavorite: metadata.favorite)
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        initObservers()
        initConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateTitleConstraints()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.titleView?.menuButton.menu = nil
    }
    
    func updateMediaType(_ type: Global.FilterType) {}
    func updateLayout(_ layout: String) {}
    func zoomInGrid() {}
    func zoomOutGrid() {}
    func edit() {}
    func endEdit() {}
    func titleTouched() {}
    func filter() {}
    
    func cancel() {        
        navigationController?.popViewController(animated: true)
    }
    
    private func initObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.willEnterForegroundNotification()
        }
    }
    
    private func initConstraints() {
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            titleViewHeightAnchor = titleView?.heightAnchor.constraint(equalToConstant: Global.shared.titleSizeLarge)
        } else {
            titleViewHeightAnchor = titleView?.heightAnchor.constraint(equalToConstant: Global.shared.titleSize)
        }
        
        titleViewHeightAnchor?.isActive = true
    }
    
    private func cleanup() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func willEnterForegroundNotification() {
        if isViewLoaded && view.window != nil {
            updateTitleConstraints()
        }
    }

    private func setFavoriteMenu(isFavorite: Bool) {

        var action: UIAction
        
        if (isFavorite) {
            action = UIAction(title: Strings.FavRemove, image: UIImage(systemName: "star.fill")) { action in
                self.toggleFavoriteNetwork(isFavorite: false)
            }
        } else {
            action = UIAction(title: Strings.FavAdd, image: UIImage(systemName: "star")) { action in
                self.toggleFavoriteNetwork(isFavorite: true)
            }
        }
        
        let menu = UIMenu(children: [action])
        
        DispatchQueue.main.async { [weak self] in
            self?.titleView?.menuButton.menu = menu
        }
    }
    
    private func toggleFavoriteNetwork(isFavorite: Bool) {
        viewModel.toggleFavorite(isFavorite: isFavorite)
    }
    
    private func getVideoURL(metadata: tableMetadata) -> URL? {
        
        if viewModel.dataService.store.fileExists(metadata) {
            return URL(fileURLWithPath: viewModel.dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!)
        }
        return nil
    }
    
    private func playLiveVideoFromMetadata(controller: ViewerController, metadata: tableMetadata) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            let urlVideo = self.getVideoURL(metadata: metadata)

            if let url = urlVideo {
                controller.playLivePhoto(url)
            }
        }
    }
    
    private func updateTitleConstraints() {
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            titleViewHeightAnchor?.constant = Global.shared.titleSizeLarge
        } else {
            titleViewHeightAnchor?.constant = Global.shared.titleSize
        }

        titleView?.updateTitleSize()
    }
}

extension PagerController: PagerViewModelDelegate {
    
    func detailVisibilityChanged(visible: Bool) {
        if visible {
            titleViewHeightAnchor?.constant = 0
            titleView?.updateTitleSize()
            titleView?.isHidden = true
        } else {
            titleView?.isHidden = false
            updateTitleConstraints()
        }
    }

    func finishedPaging(metadata: tableMetadata) {
        DispatchQueue.main.async { [weak self] in
            self?.titleView?.title.text = metadata.fileNameView
        }
        setFavoriteMenu(isFavorite: metadata.favorite)
    }
    
    func finishedUpdatingFavorite(isFavorite: Bool) {
        setFavoriteMenu(isFavorite: isFavorite)
    }
    
    func saveFavoriteError() {
        DispatchQueue.main.async { [weak self] in
            self?.coordinator.showFavoriteUpdateFailedError()
        }
    }
}

extension PagerController: UIGestureRecognizerDelegate {

    @objc func didLongpressGestureEvent(gestureRecognizer: UITapGestureRecognizer) {
        
        guard let currentViewController = currentViewController else { return }
        
        if !currentViewController.metadata.livePhoto { return }
        
        if gestureRecognizer.state == .began {
            
            currentViewController.updateViewConstraints()
            
            if let videoMetadata = viewModel.getMetadataLivePhoto(metadata: currentViewController.metadata) {
                
                if viewModel.dataService.store.fileExists(videoMetadata) {
                    playLiveVideoFromMetadata(controller: currentViewController, metadata: videoMetadata)
                } else {
                    Task { [weak self] in
                        await self?.viewModel.downloadLivePhotoVideo(metadata: videoMetadata)
                        self?.playLiveVideoFromMetadata(controller: currentViewController, metadata: videoMetadata)
                    }
                }
            }
        } else if gestureRecognizer.state == .ended {
            //Self.logger.debug("didLongpressGestureEvent() - ended")
        }
    }
}

