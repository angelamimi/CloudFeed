//
//  ViewerController.swift
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

import AVFoundation
import AVKit
import UIKit
import NextcloudKit
import os.log

protocol ViewerDelegate: AnyObject {
    func singleTapped()
    func updateStatus(status: Global.ViewerStatus)
}

class ViewerController: UIViewController {
    
    var viewModel: ViewerViewModel!
    
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var detailView: DetailView!
    @IBOutlet weak var statusContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var statusContainerTopConstraint: NSLayoutConstraint!
    
    weak var delegate: ViewerDelegate?
    weak var videoView: UIView?
    weak var videoViewHeightConstraint: NSLayoutConstraint?
    weak var videoViewRightConstraint: NSLayoutConstraint?
    
    var metadata: tableMetadata = tableMetadata()
    var path: String?
    var index: Int = 0
    
    private var playerViewController: AVPlayerViewController?
    private var panRecognizer: UIPanGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var singleTapRecognizer: UITapGestureRecognizer?
    private var initialCenter: CGPoint = .zero
    private var size = CGSize.zero
    private var disappearing = false
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ViewerController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if viewModel.isLivePhoto() {
            statusImageView.image = UIImage(systemName: "livephoto")?.withTintColor(.label, renderingMode: .alwaysOriginal)
            statusLabel.text = Strings.LiveTitle
        } else {
            statusImageView.image = nil
            statusLabel.text = ""
        }
        
        statusContainerView.isHidden = true
        statusContainerView.layer.cornerRadius = 14
        
        initObservers()
        initGestureRecognizers()
        setStatusContainerContraints()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            detailView.removeFromSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        disappearing = false

        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            loadVideo()
        } else {
            reloadImage()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        disappearing = true
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !view.frame.size.equalTo(size) {
            size = view.frame.size
            
            if currentStatus() == .details {
                showDetails(animate: false)
            } else {
                imageViewHeightConstraint?.constant = view.frame.height
                videoViewHeightConstraint?.constant = view.frame.height
            }
        }
    }
    
    deinit {
        cleanup()
    }
    
    func willEnterForeground() {
        if presentedViewController != nil {
            presentedViewController?.dismiss(animated: false)
            delegate?.updateStatus(status: .title)
        }
    }
    
    func playLivePhoto(_ url: URL) {
        
        hideAll()
        
        if playerViewController == nil {
            let avpController = viewModel.loadVideoFromUrl(url, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
            avpController.showsPlaybackControls = false
            setupVideoController(avpController: avpController, autoPlay: true)
        } else {
            playerViewController!.player?.play()
        }
    }
    
    func liveLongPressEnded() {
        playerViewController?.player?.pause()
        playerViewController?.player?.seek(to: .zero)
    }
    
    private func hideAll() {
        delegate?.updateStatus(status: .fullscreen)
        
        if metadata.livePhoto {
            statusContainerView.isHidden = true
        }
    }
    
    private func loadVideo() {
        
        let result = viewModel.loadVideo(viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
        
        detailView.url = result.url
        path = result.url?.absoluteString
        
        if path != nil && currentStatus() == .details {
            updateDetailsForPath(path!)
        }
        
        if let playerController = result.playerController {
            
            playerController.showsPlaybackControls = true
            
            setupVideoController(avpController: playerController, autoPlay: false)
        }
    }
    
    private func reloadImage() {
        if let metadata = viewModel.getMetadataFromOcId(metadata.ocId) {
            self.metadata = metadata
            loadImage(metadata: metadata)
        }
    }
    
    private func loadImage(metadata: tableMetadata) {
        
        activityIndicator.startAnimating()
        
        Task { [weak self] in
            guard let self else { return }
            
            let image = await self.viewModel.loadImage(metadata: metadata, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
            
            self.path = self.viewModel.getFilePath(metadata)
            
            if self.path != nil && self.currentStatus() == .details { //TODO: Check viewercontroller has details visible, not parent?
                self.updateDetailsForPath(self.path!)
            }
            
            if image != nil && self.metadata.ocId == metadata.ocId && self.imageView.layer.sublayers?.count == nil {
                
                DispatchQueue.main.async { [weak self] in
                    self?.imageView.image = image
                    self?.handleImageLoaded(metadata: metadata)
                }
            }
        }
    }
    
    private func handleImageLoaded(metadata: tableMetadata) {
        
        activityIndicator.stopAnimating()
        
        if metadata.livePhoto {
            let status = currentStatus()
            statusContainerView.isHidden = status == .details || status == .fullscreen
        }
    }
    
    private func updateDetailsForPath(_ path: String) {

        let url: URL?
        
        if metadata.video {
            url = URL.init(string: path)
        } else if metadata.image {
            url = URL.init(filePath: path)
        } else {
            url = nil
        }
        
        guard url != nil else { return }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            if let popover = presentedViewController as? DetailsController {
                
                if popover.isBeingDismissed {
                    presentedViewController?.dismiss(animated: false, completion: {
                        DispatchQueue.main.async { [weak self] in
                            self?.presentDetailPopover()
                        }
                    })
                } else {
                    popover.metadata = metadata
                    popover.populateDetails(url: url!)
                }
            }
        } else {
            detailView?.metadata = metadata
            detailView?.url = url!
            detailView?.populateDetails()
        }
    }
    
    private func getViewCompareCount() -> Int {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return 4 //titleView, live photo container, activity indicator, and detail view
        } else {
            return 3 //titleView, live photo container, activity indicator
        }
    }
    
    private func setupVideoController(avpController: AVPlayerViewController, autoPlay: Bool) {

        videoView = avpController.view
        
        if self.children.count == 0 {
            addChild(avpController)
        }
        
        if self.view.subviews.count == getViewCompareCount() && videoView != nil {
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleVideoTap(tapGesture:)))
                
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delegate = self
            tapRecognizer.numberOfTapsRequired = 1
                
            avpController.view.addGestureRecognizer(tapRecognizer)
            
            avpController.view.backgroundColor = .clear
            
            view.addSubview(videoView!)
            
            view.bringSubviewToFront(statusContainerView)
            
            if metadata.livePhoto {
                //make sure can't see both the imageview and videoview at the same time. looks bad when showing/hiding details
                imageView.isHidden = true
            }

            videoView?.translatesAutoresizingMaskIntoConstraints = false

            let heightConstraint = NSLayoutConstraint(item: videoView!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: view.frame.height)
            let topConstraint = NSLayoutConstraint(item: videoView!, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1, constant: 0)
            let leftConstraint = NSLayoutConstraint(item: videoView!, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1, constant: 0)
            let rightConstraint = NSLayoutConstraint(item: videoView!, attribute: .right, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1, constant: 0)

            NSLayoutConstraint.activate([heightConstraint, topConstraint, leftConstraint, rightConstraint])

            videoViewHeightConstraint = heightConstraint
            videoViewRightConstraint = rightConstraint
        }
        
        avpController.didMove(toParent: self)
        
        if autoPlay {
            avpController.player?.play()
        }
        
        playerViewController = avpController
    }
    
    private func currentStatus() -> Global.ViewerStatus {
        guard let pagerController = parent?.parent as? PagerController else { return .title }
        return pagerController.status
    }
    
    private func setStatusContainerContraints() {
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            statusContainerTopConstraint.constant = Global.shared.titleSizeLarge + 8
        } else {
            statusContainerTopConstraint.constant = Global.shared.titleSize + 8
        }
    }
    
    private func initObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.willEnterForegroundNotification()
        }
    }
    
    private func willEnterForegroundNotification() {
        if viewModel.isLivePhoto() {
            setStatusContainerContraints()
        }
    }
    
    private func cleanup() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func initGestureRecognizers() {
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(pinchGesture:)))
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(panGesture:)))

        doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(tapGesture:)))
        doubleTapRecognizer!.numberOfTapsRequired = 2
        
        singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(tapGesture:)))
        singleTapRecognizer!.numberOfTapsRequired = 1
        
        imageView.addGestureRecognizer(pinchRecognizer)
        imageView.addGestureRecognizer(panRecognizer!)
        imageView.addGestureRecognizer(doubleTapRecognizer!)
        imageView.addGestureRecognizer(singleTapRecognizer!)
        
        panRecognizer?.isEnabled = false
        
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeUpRecognizer.direction = .up
        
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeDownRecognizer.direction = .down
        
        view.addGestureRecognizer(swipeUpRecognizer)
        view.addGestureRecognizer(swipeDownRecognizer)
    }
    
    @objc private func handleSwipe(swipeGesture: UISwipeGestureRecognizer) {

        if swipeGesture.direction == .up {
            if !detailsVisible() {
                showDetails(animate: true)
            }
        } else {
            if metadata.video && UIDevice.current.userInterfaceIdiom == .pad {
                //skip hiding details. see handlePresentationControllerDidDismiss
            } else {
                hideDetails(animate: true, hideStatus: false)
            }
        }
    }
    
    @objc private func handleSingleTap(tapGesture: UITapGestureRecognizer) {
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            if presentedViewController == nil {
                delegate?.singleTapped()
                toggleStatusVisibility()
            } else {
                presentedViewController?.dismiss(animated: true)
                hideDetails(animate: true, hideStatus: false)
            }
        } else {

            if detailsVisible() {
                hideDetails(animate: true, hideStatus: false)
            } else {
                delegate?.singleTapped()
                toggleStatusVisibility()
            }
        }
    }
    
    private func toggleStatusVisibility() {
        if metadata.livePhoto {
            statusContainerView.isHidden = !statusContainerView.isHidden
        }
    }
    
    private func handlePresentationControllerDidDismiss() {

        guard disappearing == false else { return }
        
        if metadata.video {
            //usability. making sure video controls are not covered by the title bar after dismissing details popover
            delegate?.updateStatus(status: .fullscreen)
        } else {
            delegate?.updateStatus(status: .title)
            
            if metadata.livePhoto {
                statusContainerView.isHidden = false
            }
        }
    }
    
    @objc private func handleSingleVideoTap(tapGesture: UITapGestureRecognizer) {
        if !detailsVisible() {
            delegate?.singleTapped()
            toggleStatusVisibility()
        }
    }
    
    @objc private func handleDoubleTap(tapGesture: UITapGestureRecognizer) {
        
        let currentScale : CGFloat = tapGesture.view?.layer.value(forKeyPath: "transform.scale.x") as! CGFloat
        
        if currentScale == 1.0 {
            let transform = CGAffineTransformMakeScale(2, 2)
            imageView.transform = transform
            panRecognizer?.isEnabled = true
        } else {
            let transform = CGAffineTransformMakeScale(1, 1)
            imageView.transform = transform
            panRecognizer?.isEnabled = false
        }
    }
    
    @objc private func handlePan(panGesture: UIPanGestureRecognizer) {
        
        switch panGesture.state {
        case .began:
            initialCenter = imageView.center
        case .changed:
            let translation = panGesture.translation(in: view)
            imageView.center = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
        case .ended,
             .cancelled:
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.7, options: [.curveEaseInOut]) {
                self.imageView.center = self.view.center
            }
        default:
            break
        }
    }
    
    @objc private func handlePinch(pinchGesture: UIPinchGestureRecognizer) {
        
        // Use the x or y scale, they should be the same for typical zooming (non-skewing)
        let currentScale : CGFloat = pinchGesture.view?.layer.value(forKeyPath: "transform.scale.x") as! CGFloat
        
        if pinchGesture.state == .began || pinchGesture.state == .changed {

            // Variables to adjust the max/min values of zoom
            let minScale: CGFloat = 1.0
            let maxScale: CGFloat = 3.0
            let zoomSpeed: CGFloat = 0.5
            
            //  Converted to Swift 5.7.1 by Swiftify v5.7.24161 - https://swiftify.com/
            var deltaScale = pinchGesture.scale

            // You need to translate the zoom to 0 (origin) so that you
            // can multiply a speed factor and then translate back to "zoomSpace" around 1
            deltaScale = ((deltaScale - 1) * zoomSpeed) + 1
            
            // Limit to min/max size (i.e maxScale = 2, current scale = 2, 2/2 = 1.0)
            //  A deltaScale is ~0.99 for decreasing or ~1.01 for increasing
            //  A deltaScale of 1.0 will maintain the zoom size
            deltaScale = min(deltaScale, maxScale / currentScale)
            deltaScale = max(deltaScale, minScale / currentScale)

            let transform = (pinchGesture.view?.transform.scaledBy(x: deltaScale, y: deltaScale))!
      
            pinchGesture.view?.transform = transform
            pinchGesture.scale = 1.0
            
        } else if pinchGesture.state == .ended {
            
            if currentScale == 1.0 {
                panRecognizer?.isEnabled = false
            } else {
                panRecognizer?.isEnabled = true
            }
        }
    }
    
    private func isPortrait() -> Bool {
        
        //Self.logger.debug("isPortrait() - isportrait: \(UIDevice.current.orientation.isPortrait)")
        //Self.logger.debug("isPortrait() - isLandscape: \(UIDevice.current.orientation.isLandscape)")
        //Self.logger.debug("isPortrait() - rawValue: \(UIDevice.current.orientation.rawValue)")
        
        if UIDevice.current.orientation == .faceUp
            || UIDevice.current.orientation == .faceDown
            || UIDevice.current.orientation == .unknown {
            return view.frame.size.height >= view.frame.size.width
        } else {
            return UIDevice.current.orientation.isPortrait
        }
    }
    
    private func getUrl() -> URL? {
        
        if metadata.image, let path = viewModel.getFilePath(metadata) {
            return URL.init(filePath: path)
        } else if metadata.video && path != nil && !path!.isEmpty {
            return URL.init(string: path!)
        }
        return nil
    }
    
    private func detailsVisible() -> Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return presentedViewController != nil
        } else {
            return detailView.frame.origin.y < view.frame.size.height
        }
    }
    
    private func presentDetailPopover() {
        
        let controller = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailsController") as! DetailsController
        
        controller.url = getUrl()
        controller.metadata = metadata
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = CGSize(width: 400, height: 220)
        
        if let popover = controller.popoverPresentationController {

            popover.delegate = self
            popover.sourceView = imageView
            popover.sourceRect = CGRect(x: view.frame.width, y: 0, width: 100, height: 100)
            popover.permittedArrowDirections = []
            
            let sheet = popover.adaptiveSheetPresentationController
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.detents = [.medium()]
        }
        
        if presentedViewController == nil {
            present(controller, animated: true)
        }
    }
    
    private func showDetails(animate: Bool) {

        delegate?.updateStatus(status: .details)
        
        statusContainerView.isHidden = true
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            imageViewHeightConstraint?.constant = view.frame.height
            videoViewHeightConstraint?.constant = view.frame.height
            
            if presentedViewController == nil {
                presentDetailPopover()
            } else {
                
                if let popover = presentedViewController!.popoverPresentationController {
                    //popover is moved off the screen sometimes on rotation. reset it.
                    popover.sourceRect = CGRect(x: view.frame.width, y: 0, width: 100, height: 100)
                }

                if presentedViewController!.isBeingDismissed {
                    presentedViewController?.dismiss(animated: false, completion: {
                        DispatchQueue.main.async { [weak self] in
                            self?.presentDetailPopover()
                        }
                    })
                }
            }
        } else if UIDevice.current.userInterfaceIdiom == .phone {
            
            //video view is added at runtime, which ends up in front of detail view. bring detail view back to front
            view.bringSubviewToFront(detailView)
            
            /*if metadata.livePhoto && videoView != nil {
                view.sendSubviewToBack(videoView!)
            }*/
            
            if isPortrait() {
                showVerticalDetails(animate: animate)
            } else {
                showHorizontalDetails(animate: animate)
            }
            
            detailView?.metadata = metadata

            if path == nil {
                detailView?.url = nil
            } else {
                detailView?.url = getUrl()
            }
            
            detailView?.populateDetails()
        }
    }
    
    private func hideDetails(animate: Bool, hideStatus: Bool) {
        
        delegate?.updateStatus(status: .title)
        
        if metadata.livePhoto {
            statusContainerView.isHidden = hideStatus
        }
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            
            if isPortrait() {
                hideVerticalDetails(animate: animate)
            } else {
                hideHorizontalDetails(animate: animate)
            }
        }
    }
    
    private func showVerticalDetails(animate: Bool) {
        
        let heightOffset: CGFloat
        let height = view.frame.size.height
        let halfHeight = height / 2
        
        if detailView.frame.origin.y < height {
            
            //details visible. snap to half or full detail
            if Int(detailView.frame.origin.y) > Int(halfHeight) {
                //not up to half height. snap to half height
                heightOffset = halfHeight
            } else {
                //more than half height. show full details\
                heightOffset = min(view.frame.height - detailView.frame.height, halfHeight)
            }
        } else {
            //details not visible yet. snap top of detail visible
            heightOffset = halfHeight
        }
    
        if animate {
            
            UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                self.updateContentMode(contentMode: .scaleAspectFill)
            })
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                self.updateVerticalConstraintsShow(heightOffset: heightOffset)
            })

        } else {
            updateContentMode(contentMode: .scaleAspectFill)
            updateVerticalConstraintsShow(heightOffset: heightOffset)
        }
    }
    
    private func hideVerticalDetails(animate: Bool) {
        
        if animate {
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                self.updateVerticalConstraintsHide()
            })
            
            UIView.transition(with: imageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
                self.updateContentMode(contentMode: .scaleAspectFit)
            })
            
        } else {
            updateVerticalConstraintsHide()
            updateContentMode(contentMode: .scaleAspectFit)
        }
    }
    
    private func updateVerticalConstraintsShow(heightOffset: CGFloat) {
        
        imageViewTrailingConstraint?.constant = 0
        videoViewRightConstraint?.constant = 0

        detailViewTopConstraint?.constant = 0

        imageViewHeightConstraint?.constant = heightOffset
        videoViewHeightConstraint?.constant = heightOffset
        
        detailViewLeadingConstraint?.constant = 0
        detailViewWidthConstraint?.constant = view.frame.width
        
        view.layoutIfNeeded()
    }
    
    private func updateVerticalConstraintsHide() {
        
        detailViewTopConstraint?.constant = 0
        imageViewHeightConstraint?.constant = view.frame.height
        videoViewHeightConstraint?.constant = view.frame.height
        
        view.layoutIfNeeded()
    }
    
    private func showHorizontalDetails(animate: Bool) {
        
        let trailingOffset: CGFloat
        let topOffset: CGFloat
        let height = view.frame.height
        let halfWidth = view.frame.width / 2
        
        if detailView.frame.origin.y < height {
            //details visible. show more if can
            trailingOffset = (halfWidth)
            topOffset = max(detailView.frame.height, view.frame.height)
        } else {
            //details not visible yet. snap top of detail visible
            trailingOffset = (halfWidth)
            topOffset = height
        }
        
        if animate {
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                self.updateHorizontalConstraintsShow(height: height, topOffset: topOffset, trailingOffset: trailingOffset)
            })
            
            UIView.transition(with: imageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
                self.updateContentMode(contentMode: .scaleAspectFill)
            })
            
        } else {
            updateHorizontalConstraintsShow(height: height, topOffset: topOffset, trailingOffset: trailingOffset)
            updateContentMode(contentMode: .scaleAspectFill)
        }
    }
    
    private func hideHorizontalDetails(animate: Bool) {
        
        if animate {
            
            UIView.transition(with: imageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
                self.updateContentMode(contentMode: .scaleAspectFit)
            })
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                self.updateHorizontalConstraintsHide()
            })
            
        } else {
            updateContentMode(contentMode: .scaleAspectFit)
            updateHorizontalConstraintsHide()
        }
    }
    
    private func updateHorizontalConstraintsShow(height: CGFloat, topOffset: CGFloat, trailingOffset: CGFloat) {
        
        detailViewTopConstraint?.constant = topOffset
        
        imageViewHeightConstraint?.constant = height
        videoViewHeightConstraint?.constant = height
                         
        imageViewTrailingConstraint?.constant = trailingOffset
        videoViewRightConstraint?.constant = -trailingOffset
        
        detailViewWidthConstraint?.constant = trailingOffset
        detailViewLeadingConstraint?.constant = trailingOffset
        
        view.layoutIfNeeded()
    }
    
    private func updateHorizontalConstraintsHide() {
        
        detailViewTopConstraint?.constant = 0
        
        imageViewTrailingConstraint?.constant = 0
        videoViewRightConstraint?.constant = 0
        detailViewLeadingConstraint?.constant = 0
        
        view.layoutIfNeeded()
    }
    
    private func updateContentMode(contentMode: UIView.ContentMode) {
        imageView.contentMode = contentMode
        videoView?.contentMode = contentMode
        
        //TODO: Didn't always finish updating, which caused visual issue when scrolling to the next page
        /*if metadata.video && playerViewController != nil {
            Self.logger.debug("updateContentMode() - contentMode: \(contentMode == .scaleAspectFill ? "fill" : "fit")")
            playerViewController?.videoGravity = contentMode == .scaleAspectFill ? .resizeAspectFill : .resizeAspect
        }*/
    }
}

extension ViewerController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard self.metadata.video else { return false }
        
        if gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer
            && gestureRecognizer.state == .ended && otherGestureRecognizer.state == .ended {
            //Allow both video layer and video container to receive tap events
            return true
        }
        
        return false
        
    }
}

extension ViewerController: UIPopoverPresentationControllerDelegate {
  
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        handlePresentationControllerDidDismiss()
    }
}

