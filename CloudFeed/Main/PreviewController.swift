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
    private var metadata: tableMetadata!
    
    var viewModel: ViewerViewModel!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PreviewController.self)
    )
    
    init(metadata: tableMetadata, image: UIImage) {
        super.init(nibName: nil, bundle: nil)
        
        self.metadata = metadata
        
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        
        imageView.image = image
    }
    
    override func loadView() {
        view = imageView
        
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            loadVideo()
        } else if metadata.livePhoto {
            loadLiveVideo()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func playLivePhoto(_ url: URL) {
        let avpController = viewModel.loadVideoFromUrl(url, viewWidth: self.view.frame.width, viewHeight: self.view.frame.height)
        setupVideoController(avpController: avpController, autoPlay: true)
    }
    
    private func loadVideo() {
        guard let avpController = viewModel.loadVideo(viewWidth: self.preferredContentSize.width, viewHeight: self.preferredContentSize.height) else { return }
        setupVideoController(avpController: avpController, autoPlay: true)
    }
    
    private func loadLiveVideo() {
        
        let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
        
        Self.logger.debug("loadLiveVideo() - fileName: \(fileName)")
        
        if let metadata = viewModel.getMetadata(account: metadata.account, serverUrl: metadata.serverUrl, fileName: fileName) {
            
            if StoreUtility.fileProviderStorageExists(metadata) {
                playLiveVideoFromMetadata(metadata)
            } else {
                Task { [weak self] in
                    await self?.viewModel.downloadLivePhotoVideo(fileName: fileName, metadata: metadata)
                    self?.playLiveVideoFromMetadata(metadata)
                }
            }
        }
    }
    
    private func playLiveVideoFromMetadata(_ metadata: tableMetadata) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            AudioServicesPlaySystemSound(1519) // peek feedback
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
            
            if self.view.subviews.count == 0 {
                self.view.addSubview(avpController.view)
            }
            
            avpController.didMove(toParent: self)
            
            if autoPlay {
                avpController.player?.play()
            }
        }
    }
}
