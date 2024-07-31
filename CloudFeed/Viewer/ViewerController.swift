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

protocol ViewerDetailsDelegate: AnyObject {
    func detailVisibilityChanged(visible: Bool)
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
    
    weak var delegate: ViewerDetailsDelegate?
    weak var videoView: UIView?
    weak var videoViewHeightConstraint: NSLayoutConstraint?
    weak var videoViewRightConstraint: NSLayoutConstraint?
    
    var metadata: tableMetadata = tableMetadata()
    var path: String?
    var index: Int = 0
    
    private var panRecognizer: UIPanGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var initialCenter: CGPoint = .zero
    
    private var transitioned: Bool = false
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ViewerController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if viewModel.isLivePhoto() {
            statusImageView.image = UIImage(systemName: "livephoto")?.withTintColor(.label, renderingMode: .alwaysOriginal)
            statusLabel.text = Strings.LiveTitle
            statusContainerView.isHidden = false
        } else {
            statusImageView.image = nil
            statusLabel.text = ""
            statusContainerView.isHidden = true
        }
        
        statusContainerView.layer.cornerRadius = 14
        
        imageView.isUserInteractionEnabled = true
        
        initObservers()
        initGestureRecognizers()
        setStatusContainerContraints()

        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            loadVideo()
        } else {
            reloadImage()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {

        //don't have real size until laying out subviews. flag for processing
        transitioned = true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        //orientation change. don't have real size until laying out subviews. flag for processing
        transitioned = true
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if transitioned {
            transitioned = false
            
            if parentDetailsVisible() {
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
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func playLivePhoto(_ url: URL) {
        let avpController = viewModel.loadVideoFromUrl(url, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
        setupVideoController(avpController: avpController, autoPlay: true)
    }
    
    private func loadVideo() {
        guard let avpController = viewModel.loadVideo(viewWidth: self.view.frame.width, viewHeight: self.view.frame.height) else { return }
        setupVideoController(avpController: avpController, autoPlay: false)
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
            
            let image = await viewModel.loadImage(metadata: metadata, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
            
            //Self.logger.debug("loadImage() - have image? \(image != nil) for ocId: \(metadata.ocId)")
            
            if image != nil && self.metadata.ocId == metadata.ocId && self.imageView.layer.sublayers?.count == nil {
                
                DispatchQueue.main.async { [weak self] in
                    //Self.logger.debug("loadImage() - setting imageview image for ocId: \(metadata.ocId)")
                    self?.imageView.image = image
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func setupVideoController(avpController: AVPlayerViewController, autoPlay: Bool) {

        videoView = avpController.view
        
        if self.children.count == 0 {
            addChild(avpController)
        }
        
        //titleView, live photo container, activity indicator, and detail view
        if self.view.subviews.count == 4 && videoView != nil {

            self.view.addSubview(videoView!)
            
            view.bringSubviewToFront(statusContainerView)

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
    }
    
    private func parentDetailsVisible() -> Bool {
        guard let pagerController = parent?.parent as? PagerController else { return false }
        return pagerController.detailsVisible
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
        
        imageView.addGestureRecognizer(pinchRecognizer)
        imageView.addGestureRecognizer(panRecognizer!)
        imageView.addGestureRecognizer(doubleTapRecognizer!)
        
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
            showDetails(animate: true)
        } else {
            hideDetails(animate: true)
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
    
    private func presentDetailPopover() {
        
        let controller = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailsController") as! DetailsController
        
        controller.metadata = metadata
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = CGSize(width: 400, height: 500)
        
        if let popover = controller.popoverPresentationController {
            
            popover.sourceView = imageView
            popover.sourceRect = CGRect(x: view.frame.width, y: 0, width: 100, height: 100)
            popover.permittedArrowDirections = []
           
            let sheet = popover.adaptiveSheetPresentationController
            sheet.largestUndimmedDetentIdentifier = .large
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(controller, animated: true)
    }
    
    private func showDetails(animate: Bool) {
        
        delegate?.detailVisibilityChanged(visible: true)
        
        statusContainerView.isHidden = true
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            imageViewHeightConstraint?.constant = view.frame.height
            videoViewHeightConstraint?.constant = view.frame.height
            
            if presentedViewController == nil {
                presentDetailPopover()
            } else {
                presentedViewController?.dismiss(animated: false, completion: {
                    DispatchQueue.main.async { [weak self] in
                        self?.presentDetailPopover()
                    }
                })
            }
        } else if UIDevice.current.userInterfaceIdiom == .phone {
            
            //video view is added at runtime, which ends up in front of detail view. bring detail view back to front
            view.bringSubviewToFront(detailView)
            
            if isPortrait() {
                showVerticalDetails(animate: animate)
            } else {
                showHorizontalDetails(animate: animate)
            }
            
            detailView?.metadata = metadata
            detailView?.path = path
            
            detailView?.populateDetails()
        }
    }
    
    private func hideDetails(animate: Bool) {
        
        delegate?.detailVisibilityChanged(visible: false)
        
        if viewModel.isLivePhoto() {
            statusContainerView.isHidden = false
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
            
            UIView.transition(with: imageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
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
    }
}
