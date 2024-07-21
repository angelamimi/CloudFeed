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
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailView: UIView!
    @IBOutlet weak var statusContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var fileDateLabel: UILabel!
    @IBOutlet weak var fileNameLabel: UILabel!
    
    weak var delegate: ViewerDetailsDelegate?
    weak var videoView: UIView?
    weak var videoViewHeightConstraint: NSLayoutConstraint?
    
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    
    var detailsVisible = false
    
    private var panRecognizer: UIPanGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var initialCenter: CGPoint = .zero
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ViewerController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if viewModel.getMetadataLivePhoto(metadata: metadata) != nil {
            statusImageView.image = UIImage(systemName: "livephoto")?.withTintColor(.label, renderingMode: .alwaysOriginal)
            statusLabel.text = Strings.LiveTitle
            statusContainerView.isHidden = false
        } else {
            statusImageView.image = nil
            statusLabel.text = ""
            statusContainerView.isHidden = true
        }
        
        imageView.isUserInteractionEnabled = true
        
        initGestureRecognizers()

        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            loadVideo()
        } else {
            reloadImage()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if detailsVisible {
            showDetails(animate: false)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {

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
        
        //titleView, live photo container, and activity indicator
        if self.view.subviews.count == 4 && videoView != nil {
            self.view.addSubview(videoView!)
            
            videoView?.translatesAutoresizingMaskIntoConstraints = false
            let widthConstraint = NSLayoutConstraint(item: videoView!, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1, constant: 0)
            let heightConstraint = NSLayoutConstraint(item: videoView!, attribute: .height, relatedBy: .equal, toItem: self.view, attribute: .height, multiplier: 1, constant: 0)
            let topConstraint = NSLayoutConstraint(item: videoView!, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1, constant: 0)
            let leftConstraint = NSLayoutConstraint(item: videoView!, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1, constant: 0)
            let rightConstraint = NSLayoutConstraint(item: videoView!, attribute: .right, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1, constant: 0)
            NSLayoutConstraint.activate([widthConstraint, heightConstraint, topConstraint, leftConstraint, rightConstraint])
            NSLayoutConstraint.activate([widthConstraint])
            videoViewHeightConstraint = heightConstraint
        }
        
        avpController.didMove(toParent: self)
        
        if autoPlay {
            avpController.player?.play()
        }
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
            hideDetails()
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
    
    //TODO: CLEANUP
    /*private func setDetailTableVisibility(visible: Bool) {

        if (visible) {
            let detailViewController = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailViewController") as! DetailController
            detailViewController.metadata = metadata
            self.present(detailViewController, animated: true, completion: nil)
        }
    }*/

    /*
    private func showDetailsOLD() {
        
        let detailController = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailViewController") as! DetailController
        
        detailController.store = viewModel.dataService.store
        detailController.metadata = metadata
        
        if let sheet = detailController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
            sheet.prefersGrabberVisible = true
        }
        
        present(detailController, animated: true)
    }
    */
    
    private func showDetails(animate: Bool) {
        
        delegate?.detailVisibilityChanged(visible: true)
        
        let heightOffset: CGFloat
        let height = view.frame.height
        let halfHeight = height / 2
        
        //video view is added at runtime, which ends up in front of detail view. bring detail view back to front
        view.bringSubviewToFront(detailView)
        
        if detailView.frame.origin.y < height {
            
            //details visible. snap to half or full detail
            if detailView.frame.origin.y > halfHeight {
                //not up to half height. snap to half height
                heightOffset = -(halfHeight)
            } else {
                //more than half height. show full details
                heightOffset = -(max(detailView.frame.height, halfHeight))
            }
        } else {
            //details not visible yet. snap top of detail visible
            heightOffset = -(halfHeight)
        }

        if animate {
            
            UIView.transition(with: imageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
                self.imageView.contentMode = .scaleAspectFill
                self.videoView?.contentMode = .scaleAspectFill
            })
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                self.imageViewHeightConstraint?.constant = heightOffset
                self.videoViewHeightConstraint?.constant = heightOffset
                self.view.layoutIfNeeded()
            })
            
        } else {
            self.imageView.contentMode = .scaleAspectFill
            self.imageViewHeightConstraint?.constant = heightOffset
            
            self.videoView?.contentMode = .scaleAspectFill
            self.videoViewHeightConstraint?.constant = heightOffset
            
            self.view.layoutIfNeeded()
        }
        
        populateDetails()
    }
    
    private func hideDetails() {
        
        delegate?.detailVisibilityChanged(visible: false)
        
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
            self.imageViewHeightConstraint?.constant = 0
            self.videoViewHeightConstraint?.constant = 0
            self.view.layoutIfNeeded()
        })
        
        UIView.transition(with: imageView, duration: 0.5, options: .transitionCrossDissolve, animations: {
            self.imageView.contentMode = .scaleAspectFit
            self.videoView?.contentMode = .scaleAspectFit
        })
    }

    private func populateDetails() {
        
        fileNameLabel.text = metadata.fileNameView
        
        var formattedDate = ""
        let formatter = DateFormatter()
        let date = metadata.date as Date

        formatter.dateFormat = "EEEE"
        let dayString = formatter.string(from: date)
        formattedDate.append(dayString)
        formattedDate.append(" • ")

        formatter.dateFormat = "MMM d, yyyy"
        let dateString = formatter.string(from: date)
        formattedDate.append(dateString)
        formattedDate.append(" • ")

        formatter.dateFormat = "h:mm:ss a"
        let timeString = formatter.string(from: date)
        formattedDate.append(timeString)
        
        fileDateLabel.text = formattedDate
    }
}
