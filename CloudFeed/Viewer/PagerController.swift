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
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var statusContainerView: UIView!
    
    var coordinator: PagerCoordinator!
    var viewModel: PagerViewModel!
    var status: Global.ViewerStatus = .title
    
    override var prefersStatusBarHidden: Bool {
        return hideStatusBar
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    weak var pageViewController: UIPageViewController? {
        return children[0] as? UIPageViewController
    }
    
    weak var currentViewController: ViewerController? {
        return pageViewController?.viewControllers?[0] as? ViewerController
    }
    
    private var hideStatusBar: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PagerController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageViewController?.delegate = viewModel
        pageViewController?.dataSource = viewModel
        
        initGestureRecognizers()
        
        let metadata = viewModel.currentMetadata()
        let viewerMedia = viewModel.initViewer()
        
        pageViewController?.setViewControllers([viewerMedia], direction: .forward, animated: true, completion: nil)
        
        initNavigation(metadata: metadata)
        initStatusView()
        setMenu(isFavorite: metadata.favorite)
        
        initObservers()
        
        setTypeContainerView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if status == .title {
            if navigationController?.isNavigationBarHidden ?? true {
                navigationController?.setNavigationBarHidden(false, animated: true)
            } else {
                //large title doesn't come back on its own after rotation
                coordinator.animate { [weak self] _ in
                    self?.navigationController?.navigationBar.sizeToFit()
                }
            }
        } else {
            hideTitle()
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)

        if parent == nil {
            if let metadata = self.currentViewController?.metadata {
                coordinator.pagingEndedWith(metadata: metadata)
            }
        }
    }
    
    func isTitleVisible() -> Bool {
        return !(navigationController?.isNavigationBarHidden ?? true)
    }
    
    private func initObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.willEnterForegroundNotification()
            }
        }
    }
    
    private func initNavigation(metadata: Metadata) {
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = .label
        
        let appearance = UINavigationBarAppearance()
        
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .prominent)
        
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        
        navigationItem.title = getFileName(metadata)
        
        /*if let style = DateFormatter.Style(rawValue: 0) {
            navigationItem.prompt = DateFormatter.localizedString(from: metadata.date, dateStyle: .medium, timeStyle: style)
        }*/
        navigationItem.prompt = metadata.creationDate.formatted(date: .abbreviated, time: .shortened)
    }
    
    private func initStatusView() {
        statusContainerView.isHidden = true
        statusContainerView.alpha = 0
        statusContainerView.layer.cornerRadius = 14
        statusLabel.text = Strings.LiveTitle
        statusLabel.accessibilityLabel = Strings.ViewerLabelLivePhoto
    }
    
    private func initGestureRecognizers() {
        
        if let pageView = pageViewController?.view {
            
            let longPress = UILongPressGestureRecognizer()
            longPress.delaysTouchesBegan = true
            longPress.minimumPressDuration = 0.3
            longPress.delegate = self
            longPress.addTarget(self, action: #selector(handleLongPress(gestureRecognizer:)))
            
            pageView.addGestureRecognizer(longPress)
        }
        
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeUpRecognizer.direction = .up
        
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeDownRecognizer.direction = .down
        
        view.addGestureRecognizer(swipeUpRecognizer)
        view.addGestureRecognizer(swipeDownRecognizer)
    }
    
    private func willEnterForegroundNotification() {
        if isViewLoaded && view.window != nil {
            currentViewController?.willEnterForeground()
        }
    }

    private func setMenu(isFavorite: Bool) {

        guard let currentViewController = currentViewController else { return }
        var action: UIAction
        
        if (isFavorite) {
            action = UIAction(title: Strings.FavRemove, image: UIImage(systemName: "star.slash")) { [weak self] action in
                self?.toggleFavoriteNetwork(isFavorite: false)
            }
        } else {
            action = UIAction(title: Strings.FavAdd, image: UIImage(systemName: "star")) { [weak self] action in
                self?.toggleFavoriteNetwork(isFavorite: true)
            }
        }

        let shareAction = UIAction(title: Strings.ShareAction, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.share([currentViewController.metadata])
        }
        
        let menu = UIMenu(children: [action, shareAction])
        let menuButton = UIBarButtonItem.init(title: nil, image: UIImage(systemName: "ellipsis"), target: self, action: nil, menu: menu)
        let detailsButton = UIBarButtonItem.init(title: nil, image: UIImage(systemName: "info.circle"), target: self, action: #selector(showInfo))
        
        menuButton.tintColor = .label
        detailsButton.tintColor = .label
        
        DispatchQueue.main.async { [weak self] in
            self?.navigationItem.leftBarButtonItems = []
            self?.navigationItem.rightBarButtonItems = [menuButton, detailsButton]
        }
    }
    
    private func toggleFavoriteNetwork(isFavorite: Bool) {
        viewModel.toggleFavorite(isFavorite: isFavorite)
    }
    
    private func share(_ metadatas: [Metadata]) {
        viewModel.share(metadatas: metadatas)
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
    
    private func showTitle() {
        hideStatusBar = false
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    private func hideTitle() {
        hideStatusBar = true
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func showType() {
        statusContainerView?.isHidden = false
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.statusContainerView?.alpha = 1
        })
    }
    
    private func hideType() {
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.statusContainerView?.alpha = 0
        }, completion: { [weak self] _ in
            self?.statusContainerView?.isHidden = true
        })
    }
    
    private func setTypeContainerView() {
        if let metadata = currentViewController?.metadata, metadata.livePhoto == true, status == .title {
            showType()
        } else {
            hideType()
        }
    }
    
    private func getFileName(_ metadata: Metadata) -> String {
        return (metadata.fileNameView as NSString).deletingPathExtension
    }
    
    private func presentDetailPopover() {

        let controller = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailsController") as! DetailsController
        
        guard let current = currentViewController else { return }
        
        controller.delegate = self
        controller.url = current.getUrl()
        controller.metadata = current.metadata
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = CGSize(width: 400, height: 200)
        
        if let popover = controller.popoverPresentationController {

            popover.delegate = self
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.frame.width, y: 0, width: 1, height: 1)
            popover.permittedArrowDirections = []
            popover.passthroughViews = [view]

            let sheet = popover.adaptiveSheetPresentationController
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.detents = [.medium()]
        }

        if presentedViewController == nil {
            present(controller, animated: true)
        }
    }
    
    @objc private func handleSwipe(swipeGesture: UISwipeGestureRecognizer) {
        
        if swipeGesture.direction == .up {
            
            updateStatus(status: .details)
            hideType()
            
            currentViewController?.handleSwipeUp()

            if UIDevice.current.userInterfaceIdiom == .pad && presentedViewController == nil {
                presentDetailPopover()
            }
            
        } else {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                
                let previousStatus = status
                
                updateStatus(status: .title)
                presentedViewController?.dismiss(animated: true)
                
                if previousStatus != .fullscreen && previousStatus != .title {
                    currentViewController?.handlePadSwipeDown()
                }
            } else {
                let scrolledOnly = currentViewController?.handleSwipeDown() ?? false
                if !scrolledOnly {
                    updateStatus(status: .title)
                }
            }
            
            setTypeContainerView()
        }
    }
    
    private func switchToAllDetails(metadata: Metadata) {
        
        guard presentedViewController != nil else { return }
        
        presentedViewController?.dismiss(animated: true, completion: {
            DispatchQueue.main.async { [weak self] in
                self?.presentAllDetailsPopover(metadata: metadata)
            }
        })
    }
    
    private func presentAllDetailsPopover(metadata: Metadata) {
        
        let controller = initDetailController(metadata: metadata)
        
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = CGSize(width: view.frame.width / 2.5, height: view.frame.height / 2.5)
        
        if let popover = controller.popoverPresentationController {

            popover.delegate = self
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.frame.width, y: 0, width: 1, height: 1)
            popover.permittedArrowDirections = []
            
            let sheet = popover.adaptiveSheetPresentationController
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.detents = [.medium()]
        }
        
        if presentedViewController == nil {
            present(controller, animated: true)
        }
    }
    
    private func initDetailController(metadata: Metadata) -> DetailController {
        
        let controller = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailController") as! DetailController
        let mediaPath = viewModel.getFilePath(metadata)
        let viewModel = DetailViewModel()
        
        viewModel.delegate = controller
        viewModel.mediaPath = mediaPath
        viewModel.metadata = metadata
        
        controller.viewModel = viewModel
        
        return controller
    }
    
    private func setShowTitleMode() {
        hideStatusBar = false
        status = .title
        showTitle()
        setTypeContainerView()
    }
    
    @objc private func showInfo() {
        
        hideType()
        hideStatusBar = true
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            if presentedViewController == nil {
                presentDetailPopover()
            }
        }
        
        currentViewController?.showDetails(animate: true, reset: true)
    }
}

extension PagerController: DetailsControllerDelegate {
    
    func showAllMetadataDetails(metadata: Metadata) {
        switchToAllDetails(metadata: metadata)
    }
}

extension PagerController: UIPopoverPresentationControllerDelegate {

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        currentViewController?.handlePresentationControllerDidDismiss()
    }
}

extension PagerController: ViewerDelegate {
    
    func mediaLoaded(metadata: Metadata, url: URL) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let details = presentedViewController as? DetailsController {
                if let current = currentViewController?.metadata.id, current == metadata.id {
                    details.populateDetails(metadata: metadata, url: url)
                }
            }
        }
    }
    
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
            setShowTitleMode()
        } else if status == .fullscreen {
            setShowTitleMode()
        } else {
            status = .fullscreen
            if isTitleVisible() {
                hideTitle()
            }
            hideStatusBar = true
            hideType()
        }
    }
}

extension PagerController: PagerViewModelDelegate {

    func finishedPaging(metadata: Metadata) {
        
        DispatchQueue.main.async { [weak self] in
            self?.navigationItem.title = self?.getFileName(metadata)
            self?.setTypeContainerView()
            
            /*if let style = DateFormatter.Style(rawValue: 0) {
                self?.navigationItem.prompt = DateFormatter.localizedString(from: metadata.date, dateStyle: .medium, timeStyle: style)
            }*/
            self?.navigationItem.prompt = metadata.creationDate.formatted(date: .abbreviated, time: .shortened)
        }
        
        setMenu(isFavorite: metadata.favorite)
        
        if let detail = presentedViewController as? DetailsController,
           let presentedId = detail.metadata?.id,
           let currentId = currentViewController?.metadata.id {

            if currentId == metadata.id && presentedId != metadata.id {
                
                if let url = currentViewController?.getUrl() {
                    detail.populateDetails(metadata: metadata, url: url)
                }
            }
        }
    }
    
    func finishedUpdatingFavorite(isFavorite: Bool) {
        setMenu(isFavorite: isFavorite)
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
            
            hideType()
            
            currentViewController.updateViewConstraints()
            
            Task { [weak self] in
                guard let self = self else { return }
                
                if let videoMetadata = await self.viewModel.getMetadataLivePhoto(metadata: currentViewController.metadata) {
                    
                    if self.viewModel.dataService.store.fileExists(videoMetadata) {
                        self.playLiveVideoFromMetadata(controller: currentViewController, metadata: videoMetadata)
                    } else {
                        await self.viewModel.downloadLivePhotoVideo(metadata: videoMetadata)
                        self.playLiveVideoFromMetadata(controller: currentViewController, metadata: videoMetadata)
                    }
                }
            }
        } else if gestureRecognizer.state == .ended {
            if status == .title {
                showType()
            }
            currentViewController.liveLongPressEnded()
        }
    }
}
