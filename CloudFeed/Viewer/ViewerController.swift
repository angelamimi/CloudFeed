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
@preconcurrency import MobileVLCKit
import NextcloudKit
import os.log

@MainActor
protocol ViewerDelegate: AnyObject {
    func singleTapped()
    func videoError()
    func updateStatus(status: Global.ViewerStatus)
}

class ViewerController: UIViewController {
    
    var viewModel: ViewerViewModel!
    
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var statusContainerTopConstraint: NSLayoutConstraint!
    
    weak var delegate: ViewerDelegate?
    private weak var detailView: DetailView?
    private weak var videoView: UIView?
    private weak var videoViewHeightConstraint: NSLayoutConstraint?
    private weak var videoViewRightConstraint: NSLayoutConstraint?
    private weak var detailViewTopConstraint: NSLayoutConstraint?
    private weak var detailViewWidthConstraint: NSLayoutConstraint?
    private weak var detailViewHeightConstraint: NSLayoutConstraint?
    private weak var detailViewLeadingConstraint: NSLayoutConstraint?
    
    var metadata: Metadata = Metadata(obj: tableMetadata())
    var path: String?
    var videoURL: URL?
    var index: Int = 0
    
    private weak var playerViewController: AVPlayerViewController?
    private var panRecognizer: UIPanGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var singleTapRecognizer: UITapGestureRecognizer?
    private var initialCenter: CGPoint = .zero
    private var size = CGSize.zero
    private var disappearing = false
    private var overrideVideoPosition = false
    
    private var mediaPlayer: VLCMediaPlayer?
    //private var dialogProvider: VLCDialogProvider?
    private var controlsView: ControlsView?
    
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

        initGestureRecognizers()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            detailView?.removeFromSuperview()
        } else {
            detailView?.delegate = self
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        disappearing = false
        
        let detailsVisible = detailsVisible()
        let currentStatus = currentStatus()
        
        if detailsVisible && currentStatus != .details {
            hideDetails(animate: false, hideStatus: false, status: currentStatus)
        }
        
        if currentStatus != .title && controlsView != nil && controlsView!.isHidden == false {
            controlsView?.isHidden = true
        }
        
        if metadata.video {
            imageView.backgroundColor = .black
            loadVideo()
        } else {
            reloadImage()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        disappearing = true
        cleanupPlayer()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !view.frame.size.equalTo(size) {
            
            size = view.frame.size
            
            if currentStatus() == .details {
                showDetails(animate: false, reset: true)
            } else {
                imageViewHeightConstraint?.constant = view.frame.height
                videoViewHeightConstraint?.constant = view.frame.height
                
                controlsView?.frame = view.frame
            }
        }
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
            setupLiveVideoController(url: url, autoPlay: true)
        } else {
            playerViewController!.player?.play()
        }
    }
    
    func liveLongPressEnded() {

        playerViewController?.removeFromParent()
        videoView?.removeFromSuperview()

        playerViewController = nil
        videoView = nil

        imageView.isHidden = false
    }
    
    private func hideAll() {
        delegate?.updateStatus(status: .fullscreen)
        controlsView?.isHidden = true
        
        if metadata.livePhoto {
            statusContainerView.isHidden = true
        }
    }
    
    private func loadVideo(autoPlay: Bool = false) {
        
        activityIndicator.startAnimating()

        Task { [weak self] in
            guard let self else { return }
            
            let videoURL = await self.viewModel.getVideoURL(metadata: self.metadata)
            
            guard videoURL != nil else {
                //Unable to access Nextcloud. VLC doesn't report an error state if stopped because of
                //a failed connection, so allowing to fail here as a check for access upon video reload.
                //https://code.videolan.org/videolan/VLCKit/-/issues/720
                delegate?.videoError()
                
                activityIndicator.stopAnimating()
                
                if controlsView != nil && controlsView!.isDescendant(of: view) {
                    controlsView?.enable() //make sure enabled so user can try again
                    controlsView?.reset()
                }
                
                return
            }
            
            self.detailView?.url = videoURL
            self.path = videoURL?.absoluteString
            self.videoURL = videoURL
            
            if self.path != nil && self.currentStatus() == .details {
                self.updateDetailsForPath(self.path!)
            }
            
            await self.showFrame(url: videoURL!)

            setupVideoControls()
            activityIndicator.stopAnimating()
        }
    }
    
    private func showFrame(url: URL) async {

        if let image = await viewModel.downloadVideoFrame(metadata: metadata, url: url, size: imageView.frame.size) {
            await setImage(image: image)
        }
    }
    
    private func setupVideoControls() {
        
        if controlsView == nil && currentStatus() == .title {
            initControls()
        }
        
        let status = currentStatus()
        
        if controlsView != nil && (status == .title || status == .fullscreen) {
            addControls()
        }
    }
    
    private func setupVideoController(autoPlay: Bool) {
        
        guard let url = self.videoURL else { return }
        
        activityIndicator.startAnimating()
        
        if mediaPlayer != nil {
            mediaPlayer!.media = VLCMedia(url: url)
        } else {
            
            mediaPlayer = VLCMediaPlayer()
            
            let media = VLCMedia(url: url)
            //let logger = VLCConsoleLogger()
            
            //logger.level = .error
            //logger.formatter.contextFlags = .levelContextModule
            
            //dialogProvider = VLCDialogProvider(library: VLCLibrary.shared(), customUI: true)
            //dialogProvider?.customRenderer = self

            //mediaPlayer!.libraryInstance.loggers = [logger]
            mediaPlayer?.media = media
            mediaPlayer?.drawable = imageView
            mediaPlayer?.delegate = self
        }
        
        if autoPlay {
            mediaPlayer?.play()
        }
    }
    
    private func initControls() {
        controlsView = ControlsView.init(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
    }
    
    private func showControls() {
        
        if controlsView == nil {
            initControls()
            addControls()
        } else {
            controlsView?.frame = view.frame
            controlsView?.isHidden = false
        }
    }
    
    private func addControls() {
        
        guard let controls = controlsView else { return }
        
        if controls.isDescendant(of: view) {
            //already added
            controls.enable()
            controls.reset()
            return
        }

        controls.delegate = self

        view.addSubview(controls)
        view.bringSubviewToFront(controls)
    }
    
    private func reloadImage() {
        
        Task { [weak self] in
            
            if self != nil, let metadata = await self!.viewModel.getMetadataFromOcId(self!.metadata.ocId) {
             
                await MainActor.run { [weak self] in
                    self?.metadata = metadata
                    self?.activityIndicator.startAnimating()
                }
                
                await self?.loadImage(metadata: metadata)
            }
        }
    }
    
    private func loadImage(metadata: Metadata) async {
    
        let image = await viewModel.loadImage(metadata: metadata, viewWidth: view.frame.width, viewHeight: view.frame.height)
        
        path = viewModel.getFilePath(metadata)
        
        if path != nil && currentStatus() == .details {
            updateDetailsForPath(path!)
        }

        if image != nil && metadata.ocId == metadata.ocId && imageView.layer.sublayers?.count == nil {
            await setImage(image: image!)
            handleImageLoaded(metadata: metadata)
        }
    }
    
    private func handleImageLoaded(metadata: Metadata) {
        
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
    
    private func setupLiveVideoController(url: URL, autoPlay: Bool) {
        
        let player = AVPlayer(url: url)
        let avpController = AVPlayerViewController()
        
        avpController.player = player
        avpController.showsPlaybackControls = false

        videoView = avpController.view
        
        if self.children.count == 0 {
            addChild(avpController)
        }
        
        if videoView != nil && !videoView!.isDescendant(of: view) {
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleVideoTap(tapGesture:)))
                
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delegate = self
            tapRecognizer.numberOfTapsRequired = 1
                
            avpController.view.addGestureRecognizer(tapRecognizer)
            
            avpController.view.backgroundColor = .clear

            avpController.view.frame.size.height = imageView.frame.height
            avpController.view.frame.size.width = imageView.frame.width
            
            avpController.videoGravity = .resizeAspect
            avpController.allowsPictureInPicturePlayback = false
            
            view.addSubview(videoView!)
            
            view.bringSubviewToFront(statusContainerView)
            
            if metadata.livePhoto {
                //make sure can't see both the imageview and videoview at the same time. looks bad when showing/hiding details
                imageView.isHidden = true
            }

            videoView?.translatesAutoresizingMaskIntoConstraints = false

            let heightConstraint = NSLayoutConstraint(item: videoView!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: imageView.frame.height)
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
    
    private func cleanupPlayer() {
        
        guard metadata.video else { return }

        if mediaPlayer != nil && mediaPlayer!.media != nil && mediaPlayer!.isPlaying {
            mediaPlayer?.stop()
        }
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
    
    private func videoSetupForDetails() {
        
        if mediaPlayer != nil && mediaPlayer!.isPlaying {
            mediaPlayer!.stop()
        }
        
        guard let image = viewModel.getVideoFrame(metadata: metadata) else { return }

        Task {
            await self.setImage(image: image)
        }
    }
    
    private func setImage(image: UIImage) async {
        
        imageView.image = await image.byPreparingForDisplay()
        
        let detailsVisible = currentStatus() == .details
        
        if UIDevice.current.userInterfaceIdiom != .pad && detailsVisible {
            
            if isPortrait() {
                calculateVerticalConstraintsShow(transformImage: imageViewRatioWithinThreshold(), height: imageViewHeightConstraint.constant)
            }
        }
    }
    
    @objc private func handleSwipe(swipeGesture: UISwipeGestureRecognizer) {

        if swipeGesture.direction == .up {
            
            if !detailsVisible() {
                
                if metadata.video {
                    videoSetupForDetails()
                }
            }
            
            showDetails(animate: true, reset: false)
            
        } else {
            
            if metadata.video && UIDevice.current.userInterfaceIdiom == .pad {
                //skip hiding details. see handlePresentationControllerDidDismiss
            } else {
                if detailsScrolled() {
                    scrollDownDetails()
                } else {
                    hideDetails(animate: true, hideStatus: false, status: .title)
                }
            }
        }
    }
    
    private func detailsScrolled() -> Bool {
        if isPortrait() {
            return imageViewHeightConstraint.constant < view.frame.height / 2
        } else {
            return detailViewTopConstraint?.constant ?? 0 > view.frame.height
        }
    }
    
    @objc private func handleSingleTap(tapGesture: UITapGestureRecognizer) {
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            if presentedViewController == nil {
                delegate?.singleTapped()
                toggleStatusVisibility()
                toggleControlsVisibility()
            } else {
                presentedViewController?.dismiss(animated: true)
                hideDetails(animate: true, hideStatus: false, status: .title)
            }
        } else {

            if detailsVisible() {
                hideDetails(animate: true, hideStatus: false, status: .title)
            } else {
                delegate?.singleTapped()
                toggleStatusVisibility()
                toggleControlsVisibility()
            }
        }
    }
    
    private func toggleStatusVisibility() {
        if metadata.livePhoto {
            statusContainerView.isHidden = !statusContainerView.isHidden
        }
    }
    
    private func toggleControlsVisibility() {
        
        guard metadata.video else { return }
        
        if controlsView == nil {
            initControls()
            addControls()
        } else {
            controlsView!.isHidden = !controlsView!.isHidden
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
        
        if detailsVisible() {
            hideDetails(animate: true, hideStatus: false, status: .title)
        } else {
            delegate?.singleTapped()
            toggleStatusVisibility()
        }
    }
    
    @objc private func handleDoubleTap(tapGesture: UITapGestureRecognizer) {
        
        let currentScale : CGFloat = tapGesture.view?.layer.value(forKeyPath: "transform.scale.x") as! CGFloat
        
        if currentScale == 1.0 {
            panRecognizer?.isEnabled = true
            UIView.animate(withDuration: 0.3, delay: 0.0, animations: {
                self.imageView.transform = CGAffineTransformMakeScale(2, 2)
            })
        } else {
            panRecognizer?.isEnabled = false
            UIView.animate(withDuration: 0.3, delay: 0.0, animations: {
                self.imageView.transform = CGAffineTransformMakeScale(1, 1)
            })
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
    
    private func handleControlsSingleTap() {
        delegate?.singleTapped()
        toggleControlsVisibility()
    }
    
    private func handleVideoPlaying() {
        
        if mediaPlayer?.isSeekable ?? false {
            controlsView?.enableSeek()
        }
        
        if let volume = controlsView?.getVolume() {
            mediaPlayer?.audio?.volume = Int32(volume)
        }
        
        controlsView?.initCaptionsMenu(currentSubtitleIndex: mediaPlayer!.currentVideoSubTitleIndex,
                                       subtitleIndexes: mediaPlayer!.videoSubTitlesIndexes,
                                       subtitleNames: mediaPlayer!.videoSubTitlesNames)
    }
    
    private func restartMediaPlayer() {

        mediaPlayer?.media = nil
        controlsView?.reset()
        
        // make sure video wasn't stopped because user swiped up details or disappearing
        if !disappearing && currentStatus() != .details {
            controlsView?.disable()
            loadVideo()
        }
    }
    
    private func toggleMute() {
        
        guard mediaPlayer != nil else { return }
        
        if mediaPlayer!.audio?.volume == 0 {
            mediaPlayer!.audio?.volume = 100
            controlsView?.setVolume(100)
        } else {
            mediaPlayer!.audio?.volume = 0
            controlsView?.setVolume(0)
        }
    }
    
    private func playPause() {

        if mediaPlayer == nil || mediaPlayer!.media == nil {
            setupVideoController(autoPlay: true)
        } else {
            if mediaPlayer!.isPlaying {
                mediaPlayer!.pause()
            } else {
                mediaPlayer!.play()
            }
        }
    }
    
    private func fullScreen() {
        hideAll()
    }
    
    private func isPortrait() -> Bool {
        
        if UIDevice.current.orientation == .faceUp
            || UIDevice.current.orientation == .faceDown
            || UIDevice.current.orientation == .unknown
            || UIDevice.current.orientation == .portraitUpsideDown {
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
            //Size of zero = haven't laid out subviews. Details not really visible.
            return size != .zero && detailView != nil && detailView!.frame.origin.y < view.frame.size.height
        }
    }
    
    private func presentDetailPopover() {
        
        let controller = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailsController") as! DetailsController
        
        controller.delegate = self
        controller.url = getUrl()
        controller.metadata = metadata
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = CGSize(width: 400, height: 220)
        
        if let popover = controller.popoverPresentationController {

            popover.delegate = self
            popover.sourceView = imageView
            popover.sourceRect = CGRect(x: view.frame.width, y: 80, width: 100, height: 100)
            popover.permittedArrowDirections = []
            
            let sheet = popover.adaptiveSheetPresentationController
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.detents = [.medium()]
        }
        
        if presentedViewController == nil {
            present(controller, animated: true)
        }
    }
    
    private func switchToAllDetails() {
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            guard presentedViewController != nil else { return }
            
            let preferredHeight = presentedViewController?.preferredContentSize.height
            
            presentedViewController?.dismiss(animated: true, completion: {
                DispatchQueue.main.async { [weak self] in
                    self?.presentAllDetailsPopover(preferredHeight: preferredHeight)
                }
            })
        } else {
            presentAllDetailsSheet()
        }
    }
    
    private func initDetailController() -> DetailController {
        
        let controller = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailController") as! DetailController
        let mediaPath = viewModel.getFilePath(metadata)
        let viewModel = DetailViewModel()
        
        viewModel.delegate = controller
        viewModel.mediaPath = mediaPath
        viewModel.metadata = metadata
        
        controller.viewModel = viewModel
        
        return controller
    }
    
    private func presentAllDetailsSheet() {
        
        let controller = initDetailController()
        let height = view.frame.height - imageViewHeightConstraint.constant
        
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.custom { _ in
                return height
               }, .large()]
            sheet.preferredCornerRadius = .zero
        }
        
        present(controller, animated: true)
    }
    
    private func presentAllDetailsPopover(preferredHeight: CGFloat?) {
        
        let controller = initDetailController()
        let height = preferredHeight == nil ? 500 : preferredHeight!
        
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = CGSize(width: 500, height: height)
        
        if let popover = controller.popoverPresentationController {

            popover.delegate = self
            popover.sourceView = imageView
            popover.sourceRect = CGRect(x: view.frame.width, y: 80, width: 100, height: 100)
            popover.permittedArrowDirections = []
            
            let sheet = popover.adaptiveSheetPresentationController
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.detents = [.medium()]
        }
        
        if presentedViewController == nil {
            present(controller, animated: true)
        }
    }
    
    private func showDetails(animate: Bool, reset: Bool) {

        delegate?.updateStatus(status: .details)
        
        statusContainerView.isHidden = true
        
        if controlsView != nil {
            controlsView!.isHidden = true
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            imageViewHeightConstraint?.constant = view.frame.height
            videoViewHeightConstraint?.constant = view.frame.height
            
            if presentedViewController == nil {
                presentDetailPopover()
            } else {
                
                if let popover = presentedViewController!.popoverPresentationController {
                    //popover is moved off the screen sometimes on rotation. reset it.
                    popover.sourceRect = CGRect(x: view.frame.width, y: 80, width: 100, height: 100)
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

            if detailView == nil {
                initDetailView()
            }
            
            //end up with not fully dismissed details sheet if rotated while presented. this dismisses on rotation.
            if presentedViewController != nil {
                presentedViewController?.dismiss(animated: false)
            }
            
            //video view is added at runtime, which ends up in front of detail view. bring detail view back to front
            if detailView != nil {
                view.bringSubviewToFront(detailView!)
            }
            
            if isPortrait() {
                showVerticalDetails(animate: animate, reset: reset)
            } else {
                showHorizontalDetails(animate: animate, reset: reset)
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
    
    private func initDetailView() {
        
        guard let detailView = Bundle.main.loadNibNamed("DetailView", owner: self, options: nil)?.first as? DetailView else { return }
        
        self.detailView = detailView

        view.addSubview(detailView)
        
        detailView.translatesAutoresizingMaskIntoConstraints = false
        
        detailView.backgroundColor = .blue
        
        detailViewTopConstraint = detailView.topAnchor.constraint(equalTo: imageView.bottomAnchor)
        detailViewWidthConstraint = detailView.widthAnchor.constraint(equalToConstant: imageView.frame.width)
        detailViewHeightConstraint = detailView.heightAnchor.constraint(equalToConstant: 0)
        detailViewLeadingConstraint = detailView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 0)
        
        detailViewTopConstraint?.isActive = true
        detailViewWidthConstraint?.isActive = true
        detailViewHeightConstraint?.isActive = true
        detailViewLeadingConstraint?.isActive = true
        
        detailViewHeightConstraint?.priority = .defaultLow
        
        view.layoutIfNeeded()
    }
    
    private func scrollDownDetails() {
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            
            if isPortrait() {
                scrollDownVerticalDetails()
            } else {
                scrollDownHorizontalDetails()
            }
        }
    }
    
    private func hideDetails(animate: Bool, hideStatus: Bool, status: Global.ViewerStatus) {
        
        delegate?.updateStatus(status: status)
        
        if metadata.livePhoto {
            statusContainerView.isHidden = hideStatus
        } else if metadata.video && status == .title {
            showControls()
        }
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            
            if isPortrait() {
                hideVerticalDetails(animate: animate)
            } else {
                hideHorizontalDetails(animate: animate)
            }
        }
    }
    
    private func showVerticalDetails(animate: Bool, reset: Bool) {
        
        guard let detailView = self.detailView else { return }
        let allowTransform = imageViewRatioWithinThreshold()
        let heightOffset: CGFloat
        let size = view.frame.size
        let height = size.height
        let halfHeight = height / 2
        
        if detailView.frame.origin.y < height {

            //details visible. snap to half or full detail
            if Int(detailView.frame.origin.y) > Int(halfHeight) || reset == true {
                //not up to half height. snap to half height
                heightOffset = halfHeight
            } else {
                
                let detailViewHeight = detailView.height()
                
                if detailViewHeight < halfHeight {
                    heightOffset = halfHeight
                } else {
                    //more than half height. show full details
                    heightOffset = min(height - detailViewHeight, halfHeight)
                }
            }
        } else {
            //details not visible yet. snap top of detail visible
            heightOffset = halfHeight
        }
        
        if imageView.contentMode != .scaleAspectFit {
            imageView.contentMode = .scaleAspectFit
            videoView?.contentMode = .scaleAspectFit
        }

        if animate && !UIAccessibility.isReduceMotionEnabled {

            UIView.animate(withDuration: 0.2, delay: 0, options: .curveLinear, animations: {
                self.calculateVerticalConstraintsShow(transformImage: allowTransform, height: heightOffset)
            })
            
        } else {
            calculateVerticalConstraintsShow(transformImage: allowTransform, height: heightOffset)
        }
    }
    
    private func calculateVerticalConstraintsShow(transformImage: Bool, height: CGFloat) {

        guard let originalSize = imageView.image?.size else {
            updateVerticalConstraintsShow(heightOffset: height)
            return
        }
        
        let renderSize = CGSize(width: view.frame.size.width, height: height)
        
        let scaleW: CGFloat = renderSize.width / originalSize.width
        let scaleH: CGFloat = renderSize.height / originalSize.height
        
        let scale: CGFloat = scaleW > scaleH ? scaleW : scaleH
        let resizeSize: CGSize = CGSize(width: round(originalSize.width * scale), height: round(originalSize.height * scale))
        
        let diff = resizeSize.height - renderSize.height
        
        var newScale = 1.0
        var shiftUpOnly = false
        
        if (resizeSize.height > renderSize.height) && diff >= 1.0 {

            if resizeSize.width == renderSize.width {
                shiftUpOnly = true //don't transform, just shift up when details appear
            } else {
                newScale = resizeSize.height / renderSize.height
            }
            
        } else if resizeSize.width > renderSize.width {

            newScale = resizeSize.width / renderSize.width
        }
        
        if transformImage {
            imageView.transform = CGAffineTransform(scaleX: newScale, y: newScale)
            videoView?.transform = CGAffineTransform(scaleX: newScale, y: newScale)
        }
        
        if shiftUpOnly && transformImage {
            imageViewTopConstraint.constant = -(resizeSize.height - renderSize.height)
            updateVerticalConstraintsShow(heightOffset: resizeSize.height)
        } else {
            updateVerticalConstraintsShow(heightOffset: height)
        }
    }
    
    private func scrollDownVerticalDetails() {
        
        let heightOffset = view.frame.height / 2
        let allowTransform = imageViewRatioWithinThreshold()
        
        if UIAccessibility.isReduceMotionEnabled {
            self.calculateVerticalConstraintsShow(transformImage: allowTransform, height: heightOffset)
        } else {
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                self.calculateVerticalConstraintsShow(transformImage: allowTransform, height: heightOffset)
            })
        }
    }
    
    private func hideVerticalDetails(animate: Bool) {
        
        if animate && !UIAccessibility.isReduceMotionEnabled {
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                self.updateVerticalConstraintsHide()
            })
            
        } else {
            updateVerticalConstraintsHide()
        }
    }
    
    private func updateVerticalConstraintsShow(heightOffset: CGFloat) {
        
        imageViewTrailingConstraint?.constant = 0
        videoViewRightConstraint?.constant = 0

        imageViewHeightConstraint?.constant = heightOffset
        videoViewHeightConstraint?.constant = heightOffset
        
        detailViewTopConstraint?.constant = 0
        detailViewLeadingConstraint?.constant = 0
        detailViewWidthConstraint?.constant = view.frame.width
        
        view.layoutIfNeeded()
    }
    
    private func updateVerticalConstraintsHide() {
        
        detailViewTopConstraint?.constant = 0
        
        imageViewHeightConstraint?.constant = view.frame.height
        videoViewHeightConstraint?.constant = view.frame.height
        
        imageViewTopConstraint.constant = 0
        imageView.transform = CGAffineTransform(scaleX: 1, y: 1)
        
        view.layoutIfNeeded()
    }
    
    private func showHorizontalDetails(animate: Bool, reset: Bool) {
        
        guard let detailView = self.detailView else { return }
        let trailingOffset: CGFloat
        let topOffset: CGFloat
        let height = view.frame.height
        let halfWidth = view.frame.width / 2

        if detailView.frame.origin.y < height && reset == false {
            //details visible. show more if can
            trailingOffset = (halfWidth)
            topOffset = max(detailView.height(), height)
        } else {
            
            //details not visible yet. snap top of detail visible
            trailingOffset = (halfWidth)
            topOffset = height
        }
        
        if animate && !UIAccessibility.isReduceMotionEnabled {
            
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveLinear, animations: {
                self.updateHorizontalConstraintsShow(height: height, topOffset: topOffset, trailingOffset: trailingOffset)
            })
            
            if imageViewRatioWithinThreshold() {
                UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                    self.updateContentMode(contentMode: .scaleAspectFill)
                })
            }
            
        } else {
            updateHorizontalConstraintsShow(height: height, topOffset: topOffset, trailingOffset: trailingOffset)
            
            if imageViewRatioWithinThreshold() {
                updateContentMode(contentMode: .scaleAspectFill)
            }
        }
    }
    
    private func scrollDownHorizontalDetails() {
        
        self.detailViewTopConstraint?.constant = view.frame.height
        
        if UIAccessibility.isReduceMotionEnabled {
            self.view.layoutIfNeeded()
        } else {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveLinear, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }
    
    private func hideHorizontalDetails(animate: Bool) {
        
        if animate && !UIAccessibility.isReduceMotionEnabled {
            
            if imageView.contentMode != .scaleAspectFit {
                UIView.transition(with: imageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
                    self.updateContentMode(contentMode: .scaleAspectFit)
                })
            }
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                self.updateHorizontalConstraintsHide()
            })
            
        } else {
            
            if imageView.contentMode != .scaleAspectFit {
                updateContentMode(contentMode: .scaleAspectFit)
            }
            
            updateHorizontalConstraintsHide()
        }
    }
    
    private func updateHorizontalConstraintsShow(height: CGFloat, topOffset: CGFloat, trailingOffset: CGFloat) {

        detailViewTopConstraint?.constant = -topOffset
        
        imageViewHeightConstraint?.constant = height
        videoViewHeightConstraint?.constant = height
                         
        imageViewTrailingConstraint?.constant = trailingOffset
        videoViewRightConstraint?.constant = -trailingOffset
        
        detailViewWidthConstraint?.constant = trailingOffset
        detailViewLeadingConstraint?.constant = trailingOffset

        detailViewHeightConstraint?.constant = height
        
        imageViewTopConstraint.constant = 0
        
        view.layoutIfNeeded()
    }
    
    private func updateHorizontalConstraintsHide() {
        
        detailViewTopConstraint?.constant = 0
        
        imageViewTrailingConstraint?.constant = 0
        videoViewRightConstraint?.constant = 0
        
        view.layoutIfNeeded()
    }
    
    private func updateContentMode(contentMode: UIView.ContentMode) {
        imageView.contentMode = contentMode
        videoView?.contentMode = contentMode
    }
    
    private func imageViewRatioWithinThreshold() -> Bool {
        
        guard let size = imageView.image?.size else { return true }
        
        let width = Double(size.width)
        let height = Double(size.height)
        
        guard width > 0 && height > 0 else { return true }
        
        let ratio = width < height ? width / height : height / width
        
        if ratio <= 0.25 {
            return false
        } else {
            return true
        }
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

extension ViewerController: ControlsDelegate {
    
    func tapped() {
        handleControlsSingleTap()
    }
    
    func beganTracking() {
        if mediaPlayer?.isPlaying ?? false {
            mediaPlayer?.pause()
            controlsView?.setPlaying(playing: false)
        }
    }
    
    func timeChanged(time: Float) {
        if mediaPlayer != nil {
            mediaPlayer!.position = time
        }
    }
    
    func volumeChanged(volume: Float) {
        mediaPlayer?.audio?.volume = Int32(volume)
    }
    
    func volumeButtonTapped() {
        toggleMute()
    }

    func captionsSelected(subtitleIndex: Int32) {
        
        guard mediaPlayer != nil else { return }
        
        mediaPlayer!.currentVideoSubTitleIndex = subtitleIndex
        controlsView?.selectCaption(currentSubtitleIndex: mediaPlayer!.currentVideoSubTitleIndex)
    }
    
    func playButtonTapped() {
        playPause()
    }
    
    func fullScreenButtonTapped() {
        fullScreen()
    }
}

extension ViewerController: VLCMediaPlayerDelegate {
    
    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        
        Task { @MainActor [weak self] in

            self?.activityIndicator.stopAnimating()
            
            guard let currentPosition = self?.controlsView?.timeSlider.value else { return }
            guard let playerPosition = self?.mediaPlayer?.position else { return }
            
            self?.controlsView?.setMediaLength(length: self?.mediaPlayer?.media?.length.value?.doubleValue ?? 0)
            
            if currentPosition == 0 {
                //playing for the first time
                self?.handleVideoPlaying()
            }
            
            self?.controlsView?.setPosition(position: playerPosition)
            
            if let time = self?.mediaPlayer?.time.stringValue {
                self?.controlsView?.setTime(time: time)
            }
            
            if let remainingTime = self?.mediaPlayer?.remainingTime?.stringValue {
                self?.controlsView?.setRemainingTime(time: remainingTime)
            }
        }
    }
    
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        
        Task { @MainActor [weak self] in
            
            guard let player = self?.mediaPlayer else { return }
            
            let state = player.state
            
            //Self.logger.debug("mediaPlayerStateChanged() - state: \(VLCMediaPlayerStateToString(state))")
            
            if state == .playing || state == .opening || (state == .buffering && player.isPlaying) {
                self?.activityIndicator.startAnimating()
            } else {
                self?.activityIndicator.stopAnimating()
            }
            
            if state == .stopped {
                self?.restartMediaPlayer()
            }
        }
    }
}

extension ViewerController: VLCCustomDialogRendererProtocol {
    
    nonisolated func showLogin(withTitle title: String, message: String, defaultUsername username: String?, askingForStorage: Bool, withReference reference: NSValue) {
    }
    
    nonisolated func showQuestion(withTitle title: String, message: String, type questionType: VLCDialogQuestionType, cancel cancelString: String?, action1String: String?, action2String: String?, withReference reference: NSValue) {
        //Self.logger.debug("showQuestion() - title: \(title) message: \(message)")
    }
    
    nonisolated func showProgress(withTitle title: String, message: String, isIndeterminate: Bool, position: Float, cancel cancelString: String?, withReference reference: NSValue) {
    }
    
    nonisolated func updateProgress(withReference reference: NSValue, message: String?, position: Float) {
    }
    
    nonisolated func cancelDialog(withReference reference: NSValue) {
    }
    
    nonisolated func showError(withTitle error: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            Self.logger.error("showError() - ERROR: \(error) MESSAGE: \(message)")
            self?.delegate?.videoError()
        }
    }
}

extension ViewerController: DetailViewDelegate {
    
    func showAllDetails() {
        switchToAllDetails()
    }
}

extension ViewerController: DetailsControllerDelegate {
    
    func showAllMetadataDetails() {
        switchToAllDetails()
    }
}
