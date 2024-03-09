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

class ViewerController: UIViewController {
    
    var viewModel: ViewerViewModel!
    
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusContainerView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    
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
            statusLabel.text = "LIVE" //TODO: Externalize text
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

        if self.children.count == 0 {
            addChild(avpController)
        }
        
        //titleView, live photo container, and activity indicator
        if self.view.subviews.count == 3 {
            self.view.addSubview(avpController.view)
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
            showDetails()
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
    
    private func setDetailTableVisibility(visible: Bool) {

        if (visible) {
            let detailViewController = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailViewController") as! DetailController
            detailViewController.metadata = metadata
            self.present(detailViewController, animated: true, completion: nil)
        }
    }
    
    private func showDetails() {
        
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
}
