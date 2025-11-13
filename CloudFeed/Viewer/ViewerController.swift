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
    func mediaLoaded(metadata: Metadata, url: URL)
}

class ViewerController: UIViewController {
    
    var viewModel: ViewerViewModel!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
    
    private weak var detailView: DetailView?
    private weak var detailViewTopConstraint: NSLayoutConstraint?
    private weak var detailViewWidthConstraint: NSLayoutConstraint?
    private weak var detailViewHeightConstraint: NSLayoutConstraint?
    private weak var detailViewLeadingConstraint: NSLayoutConstraint?
    
    weak var delegate: ViewerDelegate?
    
    var metadata: Metadata!
    var path: String?
    var videoURL: URL?
    var index: Int = 0
    var center: CGPoint?
    
    private var avpLayer: AVPlayerLayer?
    private var pinchRecognizer: UIPinchGestureRecognizer?
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
        
        if metadata.video {
            imageView.accessibilityLabel = Strings.ViewerLabelVideo + " " + metadata.fileNameView 
        } else if metadata.livePhoto {
            imageView.accessibilityLabel = Strings.ViewerLabelLivePhoto + " " + metadata.fileNameView
        } else {
            imageView.accessibilityLabel = Strings.ViewerLabelImage + " " + metadata.fileNameView
        }

        initGestureRecognizers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        disappearing = false
        
        let detailsVisible = detailsVisible()
        let currentStatus = currentStatus()
        
        if detailsVisible && currentStatus != .details {
            hideDetails(animate: false, status: currentStatus)
        }
        
        if currentStatus != .title && controlsView != nil {
            hideControls()
        }
        
        setImageViewBackgroundColor()
        
        if metadata.video {
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

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {

        if imageViewTrailingConstraint?.constant != 0 && size.height > size.width && isPad() == false {
            imageViewTrailingConstraint?.constant = 0  //prevent contraints from conflicting on orientation change
        }
        
        super.viewWillTransition(to: size, with: coordinator)

        handleTransition(to: size, with: coordinator)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if center != nil {
            imageView.center = center!
        }
        
        if !view.frame.size.equalTo(size) {

            size = view.frame.size
            
            if currentStatus() == .details {
                showDetails(animate: false, reset: true, recenter: false)
            } else {
                imageViewHeightConstraint?.constant = view.frame.height
                controlsView?.frame = view.frame
            }
        }
    }
    
    func willEnterForeground() {
        if presentedViewController != nil && presentedViewController is DetailsController {
            presentedViewController?.dismiss(animated: false)
            updateStatus(.title)
        } else if isPad() == false && currentStatus() == .details {
            showDetails(animate: false, reset: true, recenter: false)
        }
    }
    
    func playLivePhoto(_ url: URL) {
        hideAll()
        setupLiveVideo(url: url, autoPlay: true)
    }
    
    func liveLongPressEnded() {
        avpLayer?.removeFromSuperlayer()
    }
    
    func handleSwipeUp() -> Bool {
        
       let details = detailsVisible()
        
        if !details && imageView.transform.a != 1.0 {
            //sometimes swipe hijacks child view controller pan when zoomed
            return false
        }
        
        if isPad() {
            setImageViewBackgroundColor()
            if !details {
                toggleControlsVisibility()
            }
        } else {
            
            if !details {
                if metadata.video {
                    videoSetupForDetails()
                }
            }
            
            showDetails(animate: true, reset: false, recenter: false)
        }
        
        return true
    }
    
    func handleSwipeDown() -> Bool {
        
        guard detailsVisible() else { return false }
        
        if detailsScrolled() {
            scrollDownDetails()
            return true
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.pinchRecognizer?.isEnabled = true
                self?.hideDetails(animate: true, status: .title)
            }
            return false
        }
    }
    
    func handlePadSwipeDown() {
        
        pinchRecognizer?.isEnabled = true
        
        if imageView.transform.a != 1.0 {
            panRecognizer?.isEnabled = true
        }
        
        toggleControlsVisibility()
    }
    
    func handlePresentationControllerDidDismiss() {
        
        guard disappearing == false else { return }
        
        center = imageView.center
        
        if metadata.video {
            //usability. making sure video controls are not covered by the title bar after dismissing details popover
            updateStatus(.fullscreen)
        } else {
            updateStatus(.title)
        }
    }
    
    func handleTraitChange() {
        
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        
        if presentedViewController != nil && presentedViewController is DetailsController {
            presentedViewController?.dismiss(animated: false)
            updateStatus(.title)
        } else if verticalDetailsVisible() {
            hideVerticalDetails(animate: false)
            updateStatus(.title)
        } else if horizontalDetailsVisible() {
            hideHorizontalDetails(animate: false)
            updateStatus(.title)
        }
    }
    
    func getUrl() -> URL? {
        
        if metadata.image, let path = viewModel.getFilePath(metadata) {
            return URL.init(filePath: path)
        } else if metadata.video && path != nil && !path!.isEmpty {
            return URL.init(string: path!)
        }
        return nil
    }
    
    private func handleTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        
        if controlsView != nil {
            coordinator.animate(alongsideTransition: { [weak self] _ in
                self?.controlsView?.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            }, completion: nil)
        }
        
        if isPad() {
            
            if imageView.transform.a != 1.0 {
                center = nil
            } else {
                center = CGPoint(x: size.width / 2, y: size.height / 2)
            }
            
            coordinator.animate(alongsideTransition: { [weak self] _ in
                self?.imageViewHeightConstraint.constant = size.height
            }, completion: { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.handlePopover()
                    self?.layout(rotated: true)
                }
            })
        } else {
            
            if currentStatus() != .details {
                center = nil
                
                if imageView.transform.a == 1.0 {
                    coordinator.animate(alongsideTransition: { [weak self] _ in
                        self?.imageViewHeightConstraint.constant = size.height
                        self?.imageView.center = CGPoint(x: size.width / 2, y: size.height / 2)
                    }, completion: nil)
                }
            }
        }
    }
    
    private func handlePopover() {
        if currentStatus() == .details && isPad() && presentedViewController == nil {
            showDetails(animate: true, reset: true, recenter: false)
        }
    }
    
    private func layout(rotated: Bool) {
        
        if center != nil {
            imageView.center = center!
            center = nil
        }
        
        if currentStatus() == .details {
            showDetails(animate: false, reset: true, recenter: !rotated)
        } else {
            imageViewHeightConstraint?.constant = view.frame.height
            controlsView?.frame = view.frame
            
            if imageView.transform.a != 1.0 {
                adjustImageView()
            }
        }
    }
    
    private func setImageViewBackgroundColor() {
        if metadata.video {
            imageView.backgroundColor = .black
        } else {
            let status = currentStatus()
            let color: UIColor
            let pad = isPad()
            
            if !imageView.transform.isIdentity && ((pad && (status == .details || status == .title)) || (!pad && status == .title)) {
                color = .black
            } else {
                color = status == .fullscreen ? .black : .systemBackground
            }
            
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: { [weak self] in
                self?.imageView.backgroundColor = color
            })
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
        } else {
            setupVideoController(autoPlay: false)
            if let media = mediaPlayer?.media {
                let thumbnailer = VLCMediaThumbnailer(media: media, andDelegate: self)
                thumbnailer.snapshotPosition = 0.05
                thumbnailer.thumbnailWidth = imageView.frame.width
                thumbnailer.thumbnailHeight = imageView.frame.height
                thumbnailer.fetchThumbnail()
            }
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
        
        if status == .title {
            showControls()
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
        controlsView?.alpha = 0
        controlsView?.isOpaque = false
    }
    
    private func showControls() {
        
        guard metadata.video else { return }
        
        if controlsView == nil {
            initControls()
            addControls()
        } else {
            controlsView?.frame = view.frame
        }
        
        UIView.animate(withDuration: 0.1, animations: { [weak self] in
            self?.controlsView?.alpha = 1
        })
    }
    
    private func hideControls() {
        //controls view interferes with pinch gesture if just hidden. remove entirely.
        controlsView?.removeFromSuperview()
        controlsView = nil
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
    
    private func toggleControlsVisibility() {
        
        guard metadata.video else { return }
        
        if controlsView == nil {
            showControls()
        } else {
            hideControls()
        }
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

        if image != nil && metadata.ocId == self.metadata.ocId && imageView.layer.sublayers?.count == nil {
            await setImage(image: image!)
            handleImageLoaded(metadata: metadata)
        }
    }
    
    private func handleImageLoaded(metadata: Metadata) {
        activityIndicator.stopAnimating()
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
        
        if isPad() {
            delegate?.mediaLoaded(metadata: metadata, url: url!)
        } else {
            detailView?.metadata = metadata
            detailView?.url = url!
            detailView?.populateDetails()
        }
    }
    
    private func setupLiveVideo(url: URL, autoPlay: Bool) {
        
        let player = AVPlayer(url: url)
        
        avpLayer = AVPlayerLayer(player: player)
        
        avpLayer?.frame = imageView.bounds

        imageView.layer.addSublayer(avpLayer!)
        
        if autoPlay {
            player.play()
        }
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
        
        pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(pinchGesture:)))
        
        pinchRecognizer?.delaysTouchesBegan = false
        pinchRecognizer?.delaysTouchesEnded = false
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(panGesture:)))

        panRecognizer?.delaysTouchesBegan = false
        panRecognizer?.delaysTouchesEnded = false
        
        doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapRecognizer?.numberOfTapsRequired = 2
        
        singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(tapGesture:)))
        singleTapRecognizer?.numberOfTapsRequired = 1
        singleTapRecognizer?.require(toFail: doubleTapRecognizer!)
        
        doubleTapRecognizer?.cancelsTouchesInView = false
        singleTapRecognizer?.cancelsTouchesInView = false
        
        imageView.addGestureRecognizer(pinchRecognizer!)
        imageView.addGestureRecognizer(panRecognizer!)
        imageView.addGestureRecognizer(doubleTapRecognizer!)
        imageView.addGestureRecognizer(singleTapRecognizer!)
        
        panRecognizer?.isEnabled = false
        panRecognizer?.delegate = self
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
        
        if isPad() == false && detailsVisible {

            if isPortrait() {
                showVerticalDetails(animate: false, reset: true)
            } else {
                showHorizontalDetails(animate: false, reset: true)
            }
        }
    }
    
    private func detailsScrolled() -> Bool {
        if isPortrait() {
            return imageViewHeightConstraint.constant < view.frame.height / 2
        } else {
            return detailViewTopConstraint?.constant ?? 0 < -(view.frame.height)
        }
    }
    
    @objc private func handleSingleTap(tapGesture: UITapGestureRecognizer) {

        if isPad() {
            
            if presentedViewController == nil {
                
                center = imageView.center
                
                delegate?.singleTapped()
                setImageViewBackgroundColor()
                toggleControlsVisibility()
            }
        } else {
            
            delegate?.singleTapped()
            
            if detailsVisible() {
                center = nil
                hideDetails(animate: true, status: .title)
                setImageViewBackgroundColor()
            } else {
                
                if imageView.transform.a == 1.0 {
                    center = imageView.center
                }
                
                setImageViewBackgroundColor()
                
                if metadata.video {
                    if currentStatus() == .fullscreen {
                        hideControls()
                    } else {
                        showControls()
                    }
                }
            }
        }
    }
    
    @objc private func handleDoubleTap() {
        
        let details = detailsVisible()
        guard !details || isPad() else { return }
        
        if imageView.transform.isIdentity {
            
            panRecognizer?.isEnabled = true
            center = nil
            
            if isPad() {
                if !details {
                    hideAll()
                }
            } else {
                hideAll()
            }
            
            UIView.animate(withDuration: 0.3, delay: 0.0, animations: { [weak self] in
                self?.imageView.transform = CGAffineTransformMakeScale(2, 2)
                self?.imageView.center = self?.view.center ?? .zero
            }, completion: { [weak self] _ in
                if self?.isPad() == true {
                    self?.setImageViewBackgroundColor()
                }
            })
        } else {
            panRecognizer?.isEnabled = false
            setImageViewIdentity()
            
            if isPad() {
                
                if details {
                    setImageViewBackgroundColor()
                } else {
                    center = nil
                    updateStatus(.title)
                    showControls()
                }
            } else {
                center = nil
                updateStatus(.title)
                showControls()
            }
        }
    }
    
    @objc private func handlePan(panGesture: UIPanGestureRecognizer) {

        if let view = panGesture.view {
            
            switch panGesture.state {
            case .began:
                break
            case .changed:
                
                let translation = panGesture.translation(in: view)
                
                // Get the current scale of the image view
                let currentScale = imageView.transform.a // Since the transform is a CGAffineTransform, the 'a' value represents the x scale.

                // Move the image view, adjusting for the current scale
                imageView.center = CGPoint(
                    x: imageView.center.x + (translation.x * currentScale),
                    y: imageView.center.y + (translation.y * currentScale)
                )
                
                // Reset the translation to zero
                panGesture.setTranslation(.zero, in: self.view)

            case .ended, .cancelled:
                adjustImageView()
            default:
                break
            }
        }
    }
    
    @objc private func handlePinch(pinchGesture: UIPinchGestureRecognizer) {
        
        guard let view = pinchGesture.view else { return }

        let currentScale : CGFloat = view.layer.value(forKeyPath: "transform.scale.x") as! CGFloat
        
        if pinchGesture.state == .began {
            hideAll()
        }
        
        if pinchGesture.state == .changed {
            
            var center: CGPoint = .zero
            let touches = pinchGesture.numberOfTouches
            
            for i in 0 ..< touches {
                let pinch = pinchGesture.location(ofTouch: i, in: view)
                center.x += pinch.x
                center.y += pinch.y
            }
            center.x /= CGFloat(touches)
            center.y /= CGFloat(touches)
            
            let anchorPoint = CGPoint(x: center.x / view.bounds.size.width, y: center.y / view.bounds.size.height)
            setAnchorPoint(anchorPoint, forView: view)

            let minScale: CGFloat = 1.0
            let maxScale: CGFloat = 8.0
            let zoomSpeed: CGFloat = 0.5

            var deltaScale = pinchGesture.scale

            // translate the zoom to 0 (origin) so can multiply a speed factor and then translate back to "zoomSpace" around 1
            deltaScale = ((deltaScale - 1) * zoomSpeed) + 1
            
            // Limit to min/max size (i.e maxScale = 2, current scale = 2, 2/2 = 1.0)
            //  A deltaScale is ~0.99 for decreasing or ~1.01 for increasing
            //  A deltaScale of 1.0 will maintain the zoom size
            deltaScale = min(deltaScale, maxScale / currentScale)
            deltaScale = max(deltaScale, minScale / currentScale)
            
            let transform = view.transform.scaledBy(x: deltaScale, y: deltaScale)
            view.transform = transform
            
            pinchGesture.scale = 1.0

        } else if pinchGesture.state == .ended || pinchGesture.state == .cancelled || pinchGesture.state == .failed {
            
            if view.transform.isIdentity {
                panRecognizer?.isEnabled = false //panning doesn't work with paging
                center = nil
                updateStatus(.title)
            } else {
                panRecognizer?.isEnabled = true
            }

            adjustImageView()
        }
    }
    
    private func setImageViewIdentity() {
        UIView.animate(withDuration: 0.2, delay: 0.0, animations: { [weak self] in
            self?.imageView.transform = .identity
            self?.imageView.center = self?.view.center ?? .zero
            self?.imageView.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        })
    }
    
    private func adjustImageView() {
        
        //guard let image = imageView.image else { return }
        let imageSize: CGSize
        
        if imageView.image == nil {
            if mediaPlayer?.videoSize == nil {
                return
            } else {
                imageSize = mediaPlayer!.videoSize
            }
        } else {
            imageSize = imageView.image!.size
        }
        
        let bounds = imageView.bounds
        let scale: CGFloat = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = (bounds.width - size.width) / 2.0
        let y = (bounds.height - size.height) / 2.0
        let rect = CGRect(x: x, y: y, width: size.width, height: size.height)
        let diff = bounds.width - rect.width

        if diff < 1 { //can't rely on equals. using diff instead
            adjustImageViewHorizontal(imageBounds: rect)
        } else {
            adjustImageViewVertical(imageBounds: rect)
        }
    }
    
    private func adjustImageViewVertical(imageBounds: CGRect) {
        
        let imageViewWidth = imageView.bounds.width
        let imageViewHeight = imageView.bounds.height
        let transform = imageView.transform.a
        let imageHeight = imageBounds.height * transform
        let imageWidth = imageBounds.width * transform
        
        let newBounds = imageBounds.applying(imageView.transform)
        
        let imageRight = newBounds.width + newBounds.minX + imageView.frame.minX
        let imageBottom = (newBounds.height + newBounds.minY) + imageView.frame.minY
        
        var centerX: CGFloat = imageView.frame.midX
        var centerY: CGFloat = imageView.frame.midY
        
        if imageView.frame.origin.y > 0 {
            //panned to the up beyond limit.
            centerY = imageHeight / 2.0
        } else if imageBottom < imageViewHeight {
            //panned to the down beyond the limit
            centerY = centerY + (imageViewHeight - imageBottom)
        }
        
        if imageWidth > imageViewWidth {
            //zoomed in wider than viewable area
            if imageView.frame.minX + newBounds.minX > 0 {
                //panned to the right past the limit. snap back to left edge.
                centerX = imageWidth / 2.0
            } else if imageRight < imageViewWidth {
                //panned up past bottom limit. align bottom to image within image view
                centerX = centerX + (imageViewWidth - imageRight)
            }
        } else {
            //zoomed in, but not wider than viewable area. back to center
            centerX = view.center.x
        }
        
        setImageViewCenter(CGPoint(x: centerX, y: centerY))
    }
    
    private func adjustImageViewHorizontal(imageBounds: CGRect) {
        
        let imageViewWidth = imageView.bounds.width
        let imageViewHeight = imageView.bounds.height
        let transform = imageView.transform.a
        let imageHeight = imageBounds.height * transform
        let imageWidth = imageBounds.width * transform
        
        let newBounds = imageBounds.applying(imageView.transform)
        
        let imageTop = -newBounds.minY
        let imageRight = newBounds.width + newBounds.minX + imageView.frame.minX
        let imageBottom = (newBounds.height + newBounds.minY) + imageView.frame.minY
        
        var centerX: CGFloat = imageView.frame.midX
        var centerY: CGFloat = imageView.frame.midY
        
        if imageView.frame.origin.x > 0 {
            //panned to the right beyond limit.
            centerX = imageWidth / 2.0
        } else if imageRight < imageViewWidth {
            //panned to the left beyond the limit
            centerX = centerX + (imageViewWidth - imageRight)
        }
        
        if imageHeight > imageViewHeight {
            //zoomed in taller than viewable area
            if imageView.frame.minY > imageTop {
                //panned down past top limit. align to top of image within image view
                centerY = imageHeight / 2.0
            } else if imageBottom < imageViewHeight {
                //panned up past bottom limit. align bottom to image within image view
                centerY = centerY + (imageViewHeight - imageBottom)
            }
        } else {
            //zoomed in, but not taller than viewable area. back to center
            centerY = imageView.bounds.midY
        }
        
        setImageViewCenter(CGPoint(x: centerX, y: centerY))
    }
    
    private func setImageViewCenter(_ center: CGPoint) {
        
        self.center = center
        
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.imageView.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self?.imageView.center = center
        }, completion: nil)
    }
    
    //https://www.hackingwithswift.com/example-code/calayer/how-to-change-a-views-anchor-point-without-moving-it
    private func setAnchorPoint(_ anchorPoint: CGPoint, forView view: UIView) {
        
        var newPoint = CGPoint(x: view.bounds.size.width * anchorPoint.x, y: view.bounds.size.height * anchorPoint.y)
        var oldPoint = CGPoint(x: view.bounds.size.width * view.layer.anchorPoint.x, y: view.bounds.size.height * view.layer.anchorPoint.y)
        
        newPoint = newPoint.applying(view.transform)
        oldPoint = oldPoint.applying(view.transform)
        
        var position = view.layer.position
        position.x -= oldPoint.x
        position.x += newPoint.x
        
        position.y -= oldPoint.y
        position.y += newPoint.y
        
        view.center = position
        view.layer.anchorPoint = anchorPoint
    }
    
    private func handleVideoPlaying() {
        
        controlsView?.setPlaying(playing: true)
        
        if mediaPlayer?.isSeekable ?? false {
            controlsView?.enableSeek()
        }
        
        if let volume = controlsView?.getVolume() {
            mediaPlayer?.audio?.volume = Int32(volume)
        }
        
        controlsView?.initCaptionsMenu(currentSubtitleIndex: mediaPlayer!.currentVideoSubTitleIndex,
                                       subtitleIndexes: mediaPlayer!.videoSubTitlesIndexes,
                                       subtitleNames: mediaPlayer!.videoSubTitlesNames)
    
        controlsView?.initAudioTrackMenu(currentAudioTrackIndex: mediaPlayer!.currentAudioTrackIndex,
                                         audioTrackIndexes: mediaPlayer!.audioTrackIndexes,
                                         audioTrackNames: mediaPlayer!.audioTrackNames)
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
    
    private func hideAll() {
        hideControls()
        updateStatus(.fullscreen)
    }
    
    private func updateStatus(_ status: Global.ViewerStatus) {
        delegate?.updateStatus(status: status)
        setImageViewBackgroundColor()
    }
    
    private func isPad() -> Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isCompact = traitCollection.horizontalSizeClass == .compact
            return isCompact == false
        }
        return false
    }
    
    private func isPortrait() -> Bool {
        return view.frame.size.height >= view.frame.size.width
    }
    
    private func detailsVisible() -> Bool {
        if isPad() {
            return presentedViewController != nil
        } else {
            //Size of zero = haven't laid out subviews. Details not really visible.
            if size == .zero || detailView == nil {
                return false
            } else {
                if isPortrait() {
                    return verticalDetailsVisible()
                } else {
                    return horizontalDetailsVisible()
                }
            }
        }
    }
    
    private func verticalDetailsVisible() -> Bool {
        if let constant = imageViewHeightConstraint?.constant {
            return constant != view.frame.height
        }
        return false
    }
    
    private func horizontalDetailsVisible() -> Bool {
        return detailViewTopConstraint?.constant ?? -1 != 0
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
        
        guard let details = detailView else { return }
        
        let controller = initDetailController()
        let height = view.frame.height - details.frame.minY
        
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.custom { _ in
                return height
               }, .large()]
            sheet.preferredCornerRadius = .zero
        }
        
        present(controller, animated: true)
    }
    
    func showDetails(animate: Bool, reset: Bool, recenter: Bool) {

        updateStatus(.details)
        hideControls()
        
        if isPad() {

            hideVerticalDetails(animate: false)
            
            if imageView.transform.a == 1.0 {
                panRecognizer?.isEnabled = false
            } else {
                if recenter {
                    center = imageView.center
                }
            }

            imageViewHeightConstraint?.constant = view.frame.height
            
        } else {

            pinchRecognizer?.isEnabled = false
            panRecognizer?.isEnabled = false
            
            if !detailsVisible() {
                imageView.transform = .identity
                imageView.center = view.center
                center = nil
            }
            
            if detailView == nil {
                initDetailView()
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
            
            if let details = detailView {
                
                details.metadata = metadata

                if path == nil {
                    details.url = nil
                } else {
                    details.url = getUrl()
                }

                details.populateDetails()

                UIAccessibility.post(notification: .screenChanged, argument: details.fileDateLabel)
            }
        }
    }
    
    private func initDetailView() {
        
        guard let detailView = Bundle.main.loadNibNamed("DetailView", owner: self, options: nil)?.first as? DetailView else { return }
        
        detailView.delegate = self
        
        self.detailView = detailView

        view.addSubview(detailView)
        
        detailView.translatesAutoresizingMaskIntoConstraints = false
        
        detailViewTopConstraint = detailView.topAnchor.constraint(equalTo: imageView.bottomAnchor)
        detailViewWidthConstraint = detailView.widthAnchor.constraint(equalToConstant: imageView.frame.width)
        detailViewHeightConstraint = detailView.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        detailViewLeadingConstraint = detailView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 0)
        
        detailViewTopConstraint?.isActive = true
        detailViewWidthConstraint?.isActive = true
        detailViewHeightConstraint?.isActive = true
        detailViewLeadingConstraint?.isActive = true
        
        detailViewHeightConstraint?.priority = .defaultLow
        
        view.layoutIfNeeded()
    }
    
    private func scrollDownDetails() {
        
        if isPad() == false {
            
            if isPortrait() {
                scrollDownVerticalDetails()
            } else {
                scrollDownHorizontalDetails()
            }
        }
    }
    
    private func hideDetails(animate: Bool, status: Global.ViewerStatus) {
        
        pinchRecognizer?.isEnabled = true

        updateStatus(status)
        
        if metadata.video && status == .title {
            showControls()
        }
        
        if isPad() == false {
            
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
        let visible = verticalDetailsVisible()
        
        if visible {

            //details visible. snap to half or full detail
            if Int(detailView.frame.origin.y) > Int(halfHeight) || reset == true {
                //not up to half height. snap to half height
                heightOffset = halfHeight
            } else {
                
                let detailViewHeight = detailView.frame.height - 16 //fillerView's padding
                
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
        }
        
        view.layoutIfNeeded()

        if animate && !UIAccessibility.isReduceMotionEnabled {

            UIView.animate(withDuration: 0.2, delay: 0, options: .curveLinear, animations: { [weak self] in
                self?.calculateVerticalConstraintsShow(transformImage: allowTransform, size: CGSize(width: self?.view.frame.width ?? 0, height: heightOffset))
            })
            
        } else {
            calculateVerticalConstraintsShow(transformImage: allowTransform, size: CGSize(width: view.frame.width, height: heightOffset))
        }
    }
    
    private func calculateVerticalConstraintsShow(transformImage: Bool, size: CGSize) {

        guard let originalSize = imageView.image?.size else {
            updateVerticalConstraintsShow(heightOffset: size.height, size: size)
            return
        }

        let renderSize = CGSize(width: size.width, height: size.height)
        
        let scaleW: CGFloat = renderSize.width / originalSize.width
        let scaleH: CGFloat = renderSize.height / originalSize.height
        
        let scale: CGFloat = scaleW > scaleH ? scaleW : scaleH
        let resizeSize: CGSize = CGSize(width: round(originalSize.width * scale), height: round(originalSize.height * scale))
        
        let diff = resizeSize.height - renderSize.height
        
        var newScale = 1.0
        var shiftOnly = false
        
        if (resizeSize.height > renderSize.height) && diff >= 1.0 {

            if resizeSize.width == renderSize.width {
                shiftOnly = true //don't transform, just shift up when details appear
            } else {
                newScale = resizeSize.height / renderSize.height
            }
            
        } else if resizeSize.width > renderSize.width {

            newScale = resizeSize.width / renderSize.width
        }

        if transformImage {
            imageView.transform = CGAffineTransform(scaleX: newScale, y: newScale)
        }
        
        if shiftOnly && transformImage {
            let top = -(resizeSize.height - renderSize.height) / 2
            imageViewTopConstraint.constant = top
            updateVerticalConstraintsShow(heightOffset: resizeSize.height, topOffset: top, size: size)
        } else {
            updateVerticalConstraintsShow(heightOffset: size.height, size: size)
        }
    }
    
    private func scrollDownVerticalDetails() {
        
        let heightOffset = view.frame.height / 2
        let allowTransform = imageViewRatioWithinThreshold()
        
        if UIAccessibility.isReduceMotionEnabled {
            self.calculateVerticalConstraintsShow(transformImage: allowTransform, size: CGSize(width: view.frame.width, height: heightOffset))
        } else {
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: { [weak self] in
                self?.calculateVerticalConstraintsShow(transformImage: allowTransform, size: CGSize(width: self?.view.frame.width ?? 0, height: heightOffset))
            })
        }
    }

    private func hideVerticalDetails(animate: Bool) {
        
        view.layoutIfNeeded()
        
        if animate && !UIAccessibility.isReduceMotionEnabled {
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: { [weak self] in
                self?.updateVerticalConstraintsHide()
            }, completion: { [weak self] _ in
                self?.detailView?.removeFromSuperview()
                self?.detailView = nil
            })
            
        } else {
            updateVerticalConstraintsHide()
            detailView?.removeFromSuperview()
            detailView = nil
        }
    }
    
    private func updateVerticalConstraintsShow(heightOffset: CGFloat, topOffset: CGFloat = 0, size: CGSize) {
        
        imageViewLeadingConstraint?.constant = 0
        imageViewTrailingConstraint?.constant = 0
        
        imageViewHeightConstraint?.constant = heightOffset
        
        detailViewTopConstraint?.constant = topOffset
        detailViewLeadingConstraint?.constant = 0
        detailViewWidthConstraint?.constant = size.width
        detailViewHeightConstraint?.constant = size.height
        
        view.layoutIfNeeded()
    }
    
    private func updateVerticalConstraintsHide() {
        
        detailViewTopConstraint?.constant = 0
        
        imageViewHeightConstraint?.constant = view.frame.height
        imageViewTopConstraint.constant = 0
        
        imageView.transform = .identity
        
        if !metadata.video {
            imageView.backgroundColor = .systemBackground
        }
        
        view.layoutIfNeeded()
    }
    
    private func showHorizontalDetails(animate: Bool, reset: Bool) {
        
        guard let detailView = self.detailView else { return }
        
        let allowTransform = imageViewRatioWithinThreshold()
        let trailingOffset: CGFloat
        let topOffset: CGFloat
        let height = view.frame.height
        let halfWidth = view.frame.width / 2
        let visible = horizontalDetailsVisible()
        
        if visible && reset == false {
            //details visible. show more if can
            trailingOffset = (halfWidth)
            topOffset = max(detailView.frame.size.height, height)
        } else {
            //details not visible yet. snap top of detail visible
            trailingOffset = (halfWidth)
            topOffset = height
        }
        
        view.layoutIfNeeded()
        
        if animate && !UIAccessibility.isReduceMotionEnabled {

            UIView.animate(withDuration: 0.2, delay: 0, options: .curveLinear, animations: { [weak self] in
                self?.calculateHorizontalConstraintsShow(transformImage: allowTransform, height: height, topOffset: topOffset, trailingOffset: trailingOffset)
            })
            
        } else {
            calculateHorizontalConstraintsShow(transformImage: allowTransform, height: height, topOffset: topOffset, trailingOffset: trailingOffset)
        }
    }
    
    private func calculateHorizontalConstraintsShow(transformImage: Bool, height: CGFloat, topOffset: CGFloat, trailingOffset: CGFloat) {
        
        guard let originalSize = imageView.image?.size else {
            updateHorizontalConstraintsShow(height: height, topOffset: topOffset, trailingOffset: trailingOffset, shift: false)
            return
        }
        
        let renderSize = CGSize(width: trailingOffset, height: height)
        
        let scaleW: CGFloat = renderSize.width / originalSize.width
        let scaleH: CGFloat = renderSize.height / originalSize.height
        
        let scale: CGFloat = scaleW > scaleH ? scaleW : scaleH
        let resizeSize: CGSize = CGSize(width: round(originalSize.width * scale), height: round(originalSize.height * scale))
        let diff = abs(resizeSize.width - renderSize.width)
        
        var newScale = 1.0
        var shiftOnly = false
        
        if resizeSize.width == renderSize.width || (diff > 0 && diff < 1) {
            
            if resizeSize.height > renderSize.height {
                newScale = resizeSize.height / renderSize.height
            }
        } else if resizeSize.height == renderSize.height {
            
            if resizeSize.width > renderSize.width {
                shiftOnly = true
            }
        }
        
        if transformImage && newScale != 1.0 {
            imageView.transform = CGAffineTransform(scaleX: newScale, y: newScale)
        }
        
        if shiftOnly && transformImage {
            imageView.transform = .identity
            updateHorizontalConstraintsShow(height: height, topOffset: topOffset, trailingOffset: trailingOffset, shift: true)
        } else {
            updateHorizontalConstraintsShow(height: height, topOffset: topOffset, trailingOffset: trailingOffset, shift: false)
        }
    }
    
    private func scrollDownHorizontalDetails() {
        
        self.detailViewTopConstraint?.constant = -(view.frame.height)
        
        if UIAccessibility.isReduceMotionEnabled {
            self.view.layoutIfNeeded()
        } else {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveLinear, animations: { [weak self] in
                self?.view.layoutIfNeeded()
            })
        }
    }
    
    private func hideHorizontalDetails(animate: Bool) {
        
        view.layoutIfNeeded()
        
        if animate && !UIAccessibility.isReduceMotionEnabled {
            
            if imageView.contentMode != .scaleAspectFit {
                UIView.transition(with: imageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
                    self.updateContentMode(contentMode: .scaleAspectFit)
                })
            }
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: { [weak self] in
                self?.updateHorizontalConstraintsHide()
            }, completion: { [weak self] _ in
                self?.detailView?.removeFromSuperview()
                self?.detailView = nil
            })
        } else {
            
            if imageView.contentMode != .scaleAspectFit {
                updateContentMode(contentMode: .scaleAspectFit)
            }
            
            updateHorizontalConstraintsHide()
            detailView?.removeFromSuperview()
            detailView = nil
        }
    }
    
    private func updateHorizontalConstraintsShow(height: CGFloat, topOffset: CGFloat, trailingOffset: CGFloat, shift: Bool) {

        detailViewTopConstraint?.constant = -topOffset
        imageViewHeightConstraint?.constant = height
                         
        if shift {
            imageViewLeadingConstraint?.constant = -trailingOffset
            imageViewTrailingConstraint?.constant = 0
            detailViewLeadingConstraint?.constant = trailingOffset * 2
        } else {
            imageViewTrailingConstraint?.constant = -trailingOffset
            detailViewLeadingConstraint?.constant = trailingOffset
        }

        detailViewWidthConstraint?.constant = trailingOffset
        detailViewHeightConstraint?.constant = height

        imageViewTopConstraint.constant = 0

        view.layoutIfNeeded()
    }
    
    private func updateHorizontalConstraintsHide() {
        
        detailViewTopConstraint?.constant = 0
        
        imageViewLeadingConstraint?.constant = 0
        imageViewTrailingConstraint?.constant = 0
        
        imageView.transform = .identity
        
        if !metadata.video {
            imageView.backgroundColor = .systemBackground
        }
        
        view.layoutIfNeeded()
    }
    
    private func updateContentMode(contentMode: UIView.ContentMode) {
        imageView.contentMode = contentMode
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

extension ViewerController: ControlsDelegate {
    
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
    
    func speedRateChanged(rate: Float) {
        mediaPlayer?.rate = rate
    }
    
    func volumeButtonTapped() {
        toggleMute()
    }

    func captionsSelected(subtitleIndex: Int32) {
        
        guard mediaPlayer != nil else { return }
        
        mediaPlayer!.currentVideoSubTitleIndex = subtitleIndex
        controlsView?.selectCaption(currentSubtitleIndex: mediaPlayer!.currentVideoSubTitleIndex)
    }
    
    func audioTrackSelected(audioTrackIndex: Int32) {
        
        guard mediaPlayer != nil else { return }
        
        mediaPlayer!.currentAudioTrackIndex = audioTrackIndex
        controlsView?.selectAudioTrack(currentAudioTrackIndex: mediaPlayer!.currentAudioTrackIndex)
    }
    
    func playButtonTapped() {
        playPause()
    }
    
    func fullScreenButtonTapped() {
        hideAll()
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
    
    func close() {}
    func detailsLoaded() {}
    
    func showAllDetails(metadata: Metadata) {
        presentAllDetailsSheet()
    }
}

extension ViewerController: VLCMediaThumbnailerDelegate {
    
    nonisolated func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer) {}
    
    nonisolated func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) {

        DispatchQueue.main.async { [weak self] in
            
            if let metadata = self?.metadata {
                autoreleasepool {
                    let image = UIImage(cgImage: thumbnail)
                    self?.imageView.image = image
                    self?.viewModel.saveVideoPreview(metadata: metadata, image: image)
                }
            }
        }
    }
}
