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
import NextcloudKit
import os.log
import UIKit

class PreviewController: UIViewController {
    
    private var imageView = UIImageView()
    private var activityIndicator = UIActivityIndicatorView(style: .large)
    private var metadata: tableMetadata!
    
    var viewModel: ViewerViewModel!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PreviewController.self)
    )
    
    init(metadata: tableMetadata) {
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
        
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            loadVideo()
        } else if metadata.livePhoto {
            loadLiveVideo()
        } else if metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
            viewImage(metadata: metadata)
        }
    }
    
    func playLivePhoto(_ url: URL) {
        //let avpController = viewModel.loadVideoFromUrl(url, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
        
        let player = AVPlayer(url: url)
        let avpController = AVPlayerViewController()
        
        avpController.player = player
        
        setupVideoController(avpController: avpController, autoPlay: true)
        activityIndicator.stopAnimating()
    }
    
    private func loadVideo() {
        //guard let avpController = viewModel.loadVideo(viewWidth: self.view.frame.width, viewHeight: self.view.frame.height) else { return }
        //setupVideoController(avpController: avpController, autoPlay: true)
        //TODO: weak self
        Task {
            /*let result = await viewModel.loadVideo(viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
            
            if result.playerController != nil {
                setupVideoController(avpController: result.playerController!, autoPlay: true)
            }
            
            activityIndicator.stopAnimating()*/
            
            
            guard let videoURL = await viewModel.getVideoURL(metadata: self.metadata) else {
                activityIndicator.stopAnimating()
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                let player = AVPlayer(url: videoURL)
                let avpController = AVPlayerViewController()
                
                avpController.player = player
                avpController.showsPlaybackControls = false
                
                self.setupVideoController(avpController: avpController, autoPlay: false)
                
                self.activityIndicator.stopAnimating()
            }
        }
    }
    
    private func loadLiveVideo() {
        
        if let videoMetadata = viewModel.getMetadataLivePhoto(metadata: metadata) {
            
            if viewModel.dataService.store.fileExists(videoMetadata) {
                playLiveVideoFromMetadata(videoMetadata)
            } else {
                Task { [weak self] in
                    await self?.viewModel.downloadLivePhotoVideo(metadata: videoMetadata)
                    self?.playLiveVideoFromMetadata(videoMetadata)
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func playLiveVideoFromMetadata(_ metadata: tableMetadata) {
        
        let urlVideo = self.getVideoURL(metadata: metadata)
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if let url = urlVideo {
                self.playLivePhoto(url)
            }
        }
    }
    
    private func getVideoURL(metadata: tableMetadata) -> URL? {
        
        if viewModel.dataService.store.fileExists(metadata) {
            return URL(fileURLWithPath: viewModel.dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!)
        }

        return nil
    }
    
    private func setupVideoController(avpController: AVPlayerViewController, autoPlay: Bool) {

        //DispatchQueue.main.async { [weak self] in
         //   guard let self else { return }

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
        //}
    }
    
    private func viewImage(metadata: tableMetadata) {
        
        if metadata.gif {
            processGIF(metadata: metadata)
            return
        }
        
        if metadata.svg {
            processSVG(metadata: metadata)
            return
        }
        
        if viewModel.dataService.store.previewExists(metadata.ocId, metadata.etag) {

            if let image = UIImage(contentsOfFile: viewModel.dataService.store.getPreviewPath(metadata.ocId, metadata.etag)) {
                imageView.image = image
                showImage()
            }
        }
    }
    
    private func processGIF(metadata: tableMetadata) {
        
        Task { [weak self] in
            guard let self else { return }
            guard let image = await viewModel.loadImage(metadata: metadata, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height) else { return }
            
            DispatchQueue.main.async { [weak self] in
                self?.imageView.image = image
                self?.showImage()
            }
        }
    }
    
    private func processSVG(metadata: tableMetadata) {
        
        guard let imagePath = viewModel.dataService.store.getCachePath(metadata.ocId, metadata.fileNameView) else { return }
        let previewPath = viewModel.dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
        
        if viewModel.dataService.store.fileExists(metadata) {
            guard let image = ImageUtility.loadSVGPreview(metadata: metadata, imagePath: imagePath, previewPath: previewPath) else { return }
            imageView.image = image
            self.showImage()
        } else {
            Task { [weak self] in
                guard let self else { return }
                
                _ = await viewModel.loadImage(metadata: metadata, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
                
                guard let image = ImageUtility.loadSVGPreview(metadata: metadata, imagePath: imagePath, previewPath: previewPath) else { return }
                
                DispatchQueue.main.async { [weak self] in
                    self?.imageView.image = image
                    self?.showImage()
                }
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
