//
//  PreviewController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/26/23.
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
import os.log
import UIKit

class PreviewController: UIViewController {
    
    private var imageView = UIImageView()
    private var activityIndicator = UIActivityIndicatorView(style: .large)
    private var metadata: Metadata!
    
    var viewModel: ViewerViewModel!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PreviewController.self)
    )
    
    init(metadata: Metadata) {
        super.init(nibName: nil, bundle: nil)
        
        self.metadata = metadata
        
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        
        view.addSubview(activityIndicator)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        activityIndicator.startAnimating()

        if metadata.video {
            loadVideo()
        } else if metadata.livePhoto {
            loadLiveVideo()
        } else if metadata.image {
            viewImage(metadata: metadata)
        }
    }
    
    func playLivePhoto(_ url: URL) {

        let player = AVPlayer(url: url)
        let avpController = AVPlayerViewController()
        
        avpController.player = player
        
        setupVideoController(avpController: avpController, autoPlay: true)
        activityIndicator.stopAnimating()
    }
    
    private func loadVideo() {

        Task { [weak self] in
            guard let self else { return }
            
            guard let videoURL = await self.viewModel.getVideoURL(metadata: self.metadata) else {
                self.activityIndicator.stopAnimating()
                return
            }

            let player = AVPlayer(url: videoURL)
            let avpController = AVPlayerViewController()

            player.playImmediately(atRate: 1.0)
            player.automaticallyWaitsToMinimizeStalling = false
            
            avpController.player = player
            avpController.showsPlaybackControls = false

            self.setupVideoController(avpController: avpController, autoPlay: true)
        }
    }
    
    private func loadLiveVideo() {
        
        Task { [weak self] in
            guard let self = self else { return }
            
            if let currentMetadata = self.metadata,
               let videoMetadata = await self.viewModel.getMetadataLivePhoto(metadata: currentMetadata) {
                
                if self.viewModel.dataService.store.fileExists(videoMetadata) {
                    playLiveVideoFromMetadata(videoMetadata)
                } else {
                    await self.viewModel.downloadLivePhotoVideo(metadata: videoMetadata)
                    self.playLiveVideoFromMetadata(videoMetadata)
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func playLiveVideoFromMetadata(_ metadata: Metadata) {
        
        let urlVideo = self.getVideoURL(metadata: metadata)
        
        if let url = urlVideo {
            playLivePhoto(url)
        }
    }
    
    private func getVideoURL(metadata: Metadata) -> URL? {
        
        if viewModel.dataService.store.fileExists(metadata) {
            return URL(fileURLWithPath: viewModel.dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!)
        }

        return nil
    }
    
    private func setupVideoController(avpController: AVPlayerViewController, autoPlay: Bool) {

        if self.children.count == 0 {
            self.addChild(avpController)
        }
        
        if self.view.subviews.count == 1 {
            self.view.addSubview(avpController.view)
        }
        
        avpController.didMove(toParent: self)
        
        avpController.view.backgroundColor = .clear
        
        avpController.view.frame.size.height = view.frame.height
        avpController.view.frame.size.width = view.frame.width
        
        avpController.videoGravity = .resizeAspect
        avpController.allowsPictureInPicturePlayback = false
        avpController.showsPlaybackControls = false
        
        if autoPlay {
            avpController.player?.play()
        }
    }
    
    private func viewImage(metadata: Metadata) {
        
        if metadata.svg || metadata.gif {
            loadImageFromMetadata(metadata: metadata)
            return
        }

        if viewModel.previewExists(metadata) {
            if let image = UIImage(contentsOfFile: viewModel.getPreviewPath(metadata)) {
                imageView.image = image
                showImage()
            }
        } else {
            loadImage(metadata: metadata)
        }
    }
    
    private func loadImage(metadata: Metadata) {

        Task { [weak self] in
            guard let self else { return }
            
            await self.viewModel.downloadPreview(metadata)
            
            if let image = UIImage(contentsOfFile: self.viewModel.getPreviewPath(metadata)) {
                DispatchQueue.main.async { [weak self] in
                    self?.imageView.image = image
                    self?.showImage()
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.stopAnimating() //load failed. stop the spinner
                }
            }
        }
    }
    
    private func loadImageFromMetadata(metadata: Metadata) {
        
        Task { [weak self] in
            guard let self else { return }
            
            guard let image = await viewModel.loadImage(metadata: metadata) else { return }
            
            DispatchQueue.main.async { [weak self] in
                self?.imageView.image = image
                self?.showImage()
            }
        }
    }
    
    private func showImage() {
        
        view.addSubview(imageView)

        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        activityIndicator.stopAnimating()
    }
}
