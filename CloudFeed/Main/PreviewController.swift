//
//  PreviewController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/26/23.
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
        let avpController = viewModel.loadVideoFromUrl(url, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
        setupVideoController(avpController: avpController, autoPlay: true)
        activityIndicator.stopAnimating()
    }
    
    private func loadVideo() {
        guard let avpController = viewModel.loadVideo(viewWidth: self.view.frame.width, viewHeight: self.view.frame.height) else { return }
        setupVideoController(avpController: avpController, autoPlay: true)
        activityIndicator.stopAnimating()
    }
    
    private func loadLiveVideo() {
        
        let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
        
        //Self.logger.debug("loadLiveVideo() - fileName: \(fileName)")
        
        if let metadata = viewModel.getMetadata(account: metadata.account, serverUrl: metadata.serverUrl, fileName: fileName) {
            
            if StoreUtility.fileProviderStorageExists(metadata) {
                playLiveVideoFromMetadata(metadata)
            } else {
                Task { [weak self] in
                    await self?.viewModel.downloadLivePhotoVideo(fileName: fileName, metadata: metadata)
                    self?.playLiveVideoFromMetadata(metadata)
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func playLiveVideoFromMetadata(_ metadata: tableMetadata) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            let urlVideo = self.getVideoURL(metadata: metadata)

            if let url = urlVideo {
                self.playLivePhoto(url)
            }
        }
    }
    
    private func getVideoURL(metadata: tableMetadata) -> URL? {
        
        if StoreUtility.fileProviderStorageExists(metadata) {
            return URL(fileURLWithPath: StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        }

        return nil
    }
    
    private func setupVideoController(avpController: AVPlayerViewController, autoPlay: Bool) {

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if self.children.count == 0 {
                self.addChild(avpController)
            }
            
            if self.view.subviews.count == 1 {
                self.view.addSubview(avpController.view)
            }
            
            avpController.didMove(toParent: self)
            
            if autoPlay {
                avpController.player?.play()
            }
        }
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
        
        if StoreUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {

            if let image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)) {
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
        
        if StoreUtility.fileProviderStorageExists(metadata) {
            guard let image = NextcloudUtility.shared.loadSVGPreview(metadata: metadata) else { return }
            imageView.image = image
            self.showImage()
        } else {
            Task { [weak self] in
                guard let self else { return }
                
                _ = await viewModel.loadImage(metadata: metadata, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
                
                guard let image = NextcloudUtility.shared.loadSVGPreview(metadata: metadata) else { return }
                
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
