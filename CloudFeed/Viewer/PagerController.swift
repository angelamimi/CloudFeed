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

class PagerController: UIViewController {
    
    var coordinator: PagerCoordinator!
    var viewModel: PagerViewModel!
    var status: Global.ViewerStatus = .title
    
    private var titleViewHeightAnchor: NSLayoutConstraint?
    private weak var titleView: TitleView?
    
    weak var pageViewController: UIPageViewController? {
        return children[0] as? UIPageViewController
    }
    
    weak var currentViewController: ViewerController? {
        return pageViewController?.viewControllers![0] as? ViewerController
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
        
        let longPress = UILongPressGestureRecognizer()
        longPress.delaysTouchesBegan = true
        longPress.minimumPressDuration = 0.3
        longPress.delegate = self
        longPress.addTarget(self, action: #selector(handleLongPress(gestureRecognizer:)))
        
        pageViewController?.view.addGestureRecognizer(longPress)
        
        let metadata = viewModel.currentMetadata()
        let viewerMedia = viewModel.initViewer()
        
        pageViewController?.setViewControllers([viewerMedia], direction: .forward, animated: true, completion: nil)
        
        titleView = Bundle.main.loadNibNamed("TitleView", owner: self, options: nil)?.first as? TitleView
        view.addSubview(titleView!)
        
        titleView?.mediaView = self
        titleView?.title.text = getFileName(metadata)
        titleView?.initNavigation()
        
        setFavoriteMenu(isFavorite: metadata.favorite)
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        initObservers()
        initConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateTitleConstraints()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        titleView?.menuButton.menu = nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if status == .title {
            titleView?.isHidden = false
            updateTitleConstraints()
        } else {
            hideTitle()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func isTitleVisible() -> Bool {
        if titleView == nil {
            return false
        } else {
            return !titleView!.isHidden
        }
    }
    
    private func initObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.willEnterForegroundNotification()
            }
        }
    }
    
    private func initConstraints() {
        
        titleView?.translatesAutoresizingMaskIntoConstraints = false
        
        titleView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        titleView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        titleView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            titleViewHeightAnchor = titleView?.heightAnchor.constraint(equalToConstant: Global.shared.titleSizeLarge)
        } else {
            titleViewHeightAnchor = titleView?.heightAnchor.constraint(equalToConstant: Global.shared.titleSize)
        }

        titleViewHeightAnchor?.isActive = true
    }
    
    private func willEnterForegroundNotification() {
        if isViewLoaded && view.window != nil {
            updateTitleConstraints()
            currentViewController?.willEnterForeground()
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
    
    private func getVideoURL(metadata: Metadata) -> URL? {
        
        if viewModel.dataService.store.fileExists(metadata) {
            return URL(fileURLWithPath: viewModel.dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!)
        }
        return nil
    }
    
    private func playLiveVideoFromMetadata(controller: ViewerController, metadata: Metadata) {
        
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
    
    private func showTitle() {
        titleView?.isHidden = false
        updateTitleConstraints()
    }
    
    private func hideTitle() {
        titleViewHeightAnchor?.constant = 0
        titleView?.updateTitleSize()
        titleView?.isHidden = true
    }
    
    private func getFileName(_ metadata: Metadata) -> String {
        return (metadata.fileNameView as NSString).deletingPathExtension
    }
}

extension PagerController: ViewerDelegate {
    
    func videoError() {
        coordinator.showVideoError()
    }

    func updateStatus(status: Global.ViewerStatus) {
        self.status = status
        
        if status == .title {
            showTitle()
        } else {
            hideTitle()
        }
    }
    
    func singleTapped() {
        
        if status == .details {
            status = .title
            showTitle()
        } else if status == .fullscreen {
            status = .title
            showTitle()
        } else {
            status = .fullscreen
            if isTitleVisible() {
                hideTitle()
            }
        }
    }
}

extension PagerController: PagerViewModelDelegate {

    func finishedPaging(metadata: Metadata) {
        DispatchQueue.main.async { [weak self] in
            self?.titleView?.title.text = self?.getFileName(metadata)
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
    
    @objc private func handleLongPress(gestureRecognizer: UITapGestureRecognizer) {

        guard status != .details else { return }
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
            currentViewController.liveLongPressEnded()
        }
    }
}

extension PagerController: MediaViewController {
    
    func cancel() {
        navigationController?.popViewController(animated: true)
        
        if let metadata = self.currentViewController?.metadata {
            coordinator.pagingEndedWith(metadata: metadata)
        }
    }
    
    func updateMediaType(_ type: Global.FilterType) {}
    func updateLayout(_ layout: String) {}
    func zoomInGrid() {}
    func zoomOutGrid() {}
    func edit() {}
    func endEdit() {}
    func titleTouched() {}
    func filter() {}
}

