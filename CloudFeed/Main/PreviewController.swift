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
        imageView.tintColor = .label

        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .label
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {

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
            previewImage(metadata: metadata)
        }
    }

    private func loadVideo() {
        viewModel.loadVideoURL(metadata: metadata)
    }

    private func loadLiveVideo() {
        viewModel.playLiveVideo(metadata: metadata)
    }

    private func setupVideoController(avpController: AVPlayerViewController, autoPlay: Bool) {

        if children.count == 0 {
            addChild(avpController)
        }

        if view.subviews.count == 1 {
            view.addSubview(avpController.view)
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

    private func previewImage(metadata: Metadata) {

        if !metadata.gif && viewModel.previewExists(metadata) {
            if let image = UIImage(contentsOfFile: viewModel.getPreviewPath(metadata)) {
                imageView.image = image
                showImage()
            }
        } else if metadata.svg || metadata.gif {
            viewModel.downloadImage(ocId: metadata.ocId)
        } else {
            viewModel.downloadPreview(metadata)
        }
    }

    private func showImage() {

        view.addSubview(imageView)

        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        activityIndicator.stopAnimating()
    }

    func handlePlayLivePhoto(_ url: URL) {

        let player = AVPlayer(url: url)
        let avpController = AVPlayerViewController()

        avpController.player = player

        setupVideoController(avpController: avpController, autoPlay: true)
        activityIndicator.stopAnimating()
    }

    func handleImageDownloaded(metadata: Metadata?) {

        guard metadata?.svg == true || metadata?.gif == true else {
            activityIndicator.stopAnimating()
            return
        }

        Task.detached { [weak self] in

            if let image = await self?.viewModel.loadImage(metadata: metadata!) {

                await MainActor.run { [weak self] in
                    self?.imageView.image = image
                    self?.showImage()
                }
            }
        }
    }

    private func handlePreviewDownloaded(metadata: Metadata, path: String?) {
        if let previewPath = path,
           let image = UIImage(contentsOfFile: previewPath) {
            imageView.image = image
            showImage()
        } else {
            activityIndicator.stopAnimating() //load failed. stop the spinner
        }
    }

    private func handleVideoLoad(metadata: Metadata, url: URL?) {

        guard let videoURL = url else {
            imageView.image = UIImage(systemName: "play.slash")
            showImage()
            return
        }

        activityIndicator.stopAnimating()

        let player = AVPlayer(url: videoURL)
        let avpController = AVPlayerViewController()

        player.playImmediately(atRate: 1.0)
        player.automaticallyWaitsToMinimizeStalling = false

        avpController.player = player
        avpController.showsPlaybackControls = false

        setupVideoController(avpController: avpController, autoPlay: true)
    }
}

extension PreviewController: ViewerViewModelDelegate {

    func videoFrameDownloaded(metadata: Metadata) {

    }

    func imageDownloadStart(metadata: Metadata) {

    }

    func loadVideoFromUrl(metadata: Metadata, url: URL?) {
        handleVideoLoad(metadata: metadata, url: url)
    }

    func imageDownloaded(metadata: Metadata?) {
        handleImageDownloaded(metadata: metadata)
    }

    func playLiveVideo(url: URL) {
        handlePlayLivePhoto(url)
    }

    func previewDownloaded(metadata: Metadata, path: String?) {
        handlePreviewDownloaded(metadata: metadata, path: path)
    }
}
