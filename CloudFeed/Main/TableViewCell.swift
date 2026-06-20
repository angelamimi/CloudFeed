//
//  TableViewCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 5/27/26.
//  Copyright © 2026 Angela Jarosz. All rights reserved.
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

import UIKit
import AVFoundation
import VLCKitSPM

@MainActor
protocol TableViewCellDelegate: AnyObject {
    func toggleFavoriteForMetadata(metadataId: String)
    func shareForMetadata(metadataId: String)
    func commentForMetadata(metadataId: String)
    func videoForMetadata(metadataId: String)
}

class TableViewCell: UITableViewCell {
    
    @IBOutlet weak var ownerImageView: UIImageView!
    @IBOutlet weak var ownerLabel: UILabel!
    
    @IBOutlet weak var previewImageView: UIImageView!
    
    @IBOutlet weak var livePhotoImageView: UIImageView!
    @IBOutlet weak var videoButton: UIButton!
    
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var commentButton: UIButton!
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    
    @IBOutlet weak var pixelSizeLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var infoStackView: UIStackView!
    
    @IBOutlet weak var previewImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var previewImageViewSecondaryHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var metadataId: String?
    weak var delegate: TableViewCellDelegate?
    
    private var avpLayer: AVPlayerLayer?
    private var mediaPlayer: VLCMediaPlayer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        MainActor.assumeIsolated { [weak self] in
            self?.initCell()
            self?.initActions()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        stopVideo()
        
        delegate = nil
        metadataId = nil
        
        previewImageView.image = nil
        ownerImageView.image = nil
        
        livePhotoImageView.isHidden = true
        videoButton.isHidden = true
        
        dateLabel.text = ""
        nameLabel.text = ""
        
        sizeLabel.text = ""
        pixelSizeLabel.text = ""
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            previewImageViewSecondaryHeightConstraint?.constant = 900
            previewImageViewHeightConstraint?.constant = 900
        } else {
            previewImageViewSecondaryHeightConstraint?.constant = 500
            previewImageViewHeightConstraint?.constant = 500
        }
        
        previewImageViewHeightConstraint?.priority = .defaultLow
        
        previewImageView.contentMode = .scaleAspectFill
        
        activityIndicator.isHidden = true
    }
    
    @objc func favoriteButtonTouched() {
        delegate?.toggleFavoriteForMetadata(metadataId: metadataId ?? "")
    }
    
    @objc func shareButtonTouched() {
        delegate?.shareForMetadata(metadataId: metadataId ?? "")
    }
    
    @objc func commentButtonTouched() {
        delegate?.commentForMetadata(metadataId: metadataId ?? "")
    }
    
    @objc func videoButtonTouched() {
        if let player = mediaPlayer {
            if player.isPlaying {
                videoButton.configuration?.image = UIImage(systemName: "play")
                player.pause()
            } else {
                videoButton.configuration?.image = UIImage(systemName: "pause")
                player.play()
            }
        } else {
            videoButton.configuration?.image = UIImage(systemName: "pause")
            activityIndicator.isHidden = false
            delegate?.videoForMetadata(metadataId: metadataId ?? "")
        }
    }
    
    func setPreviewImage(_ image: UIImage?) {
        
        if ImageUtility.ratioWithinThreshold(image?.size ?? .zero) == true {
            previewImageView.contentMode = .scaleAspectFill
        } else {
            previewImageView.contentMode = .scaleAspectFit
        }
        
        if image == nil {
            previewImageView.image = nil
        } else {
            UIView.transition(with: previewImageView,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: { [weak self] in self?.previewImageView.image = image })
        }
    }
    
    func forVideo(_ video: Bool) {
        videoButton.isHidden = !video
    }
    
    func forLivePhoto(_ live: Bool) {
        livePhotoImageView.isHidden = !live
    }
    
    func setFavorite(_ favorite: Bool) {
        if favorite {
            favoriteButton.configuration?.image = UIImage(systemName: "heart.fill")
        } else {
            favoriteButton.configuration?.image = UIImage(systemName: "heart")
        }
    }
    
    func setInfoVisibility(_ visible: Bool) {
        
        dateLabel.isHidden = !visible
        nameLabel.isHidden = !visible
        sizeLabel.isHidden = !visible
        pixelSizeLabel.isHidden = !visible
        infoStackView.isHidden = !visible
        
        dateLabel.alpha = visible ? 1 : 0
        nameLabel.alpha = visible ? 1 : 0
        infoStackView.alpha = visible ? 1 : 0
    }
    
    func setSystemImage(name: String) {
        
        let config = UIImage.SymbolConfiguration(pointSize: 50)
        previewImageView.image = UIImage(systemName: name, withConfiguration: config)
        
        previewImageView.contentMode = .center
        previewImageViewHeightConstraint?.priority = .required
        previewImageViewHeightConstraint?.constant = 500
    }
    
    func playVideo(_ url: URL) {
        
        mediaPlayer = VLCMediaPlayer()
        
        let media = VLCMedia(url: url)
        
        mediaPlayer?.media = media
        mediaPlayer?.drawable = previewImageView
        mediaPlayer?.delegate = self
        
        mediaPlayer?.play()
        
        contentView.bringSubviewToFront(activityIndicator)
    }
    
    func stopVideo() {
        
        if mediaPlayer != nil {
            videoButton.configuration?.image = UIImage(systemName: "play")
        }
        
        mediaPlayer?.stop()
    }
    
    func playLiveVideo(_ url: URL) {
        
        let player = AVPlayer(url: url)
        
        avpLayer = AVPlayerLayer(player: player)
        
        avpLayer?.frame = previewImageView.bounds.offsetBy(dx: 0, dy: previewImageView.frame.minY)
        avpLayer?.videoGravity = .resizeAspectFill
        
        contentStackView.layer.addSublayer(avpLayer!)
        
        UIView.animate(withDuration: 0.4, animations: { [weak self] in
            self?.previewImageView.alpha = 0
            self?.livePhotoImageView.isHidden = true
        }, completion: { _ in
            player.play()
        })
    }
    
    func stopLiveVideo() {
        
        if let playerLayer = avpLayer {
            playerLayer.player?.pause()
            playerLayer.removeFromSuperlayer()
        }
        
        avpLayer = nil
        
        previewImageView.alpha = 1
        livePhotoImageView.isHidden = false
    }
 
    private func initActions() {
        favoriteButton.addTarget(self, action: #selector(favoriteButtonTouched), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTouched), for: .touchUpInside)
        commentButton.addTarget(self, action: #selector(commentButtonTouched), for: .touchUpInside)
        videoButton.addTarget(self, action: #selector(videoButtonTouched), for: .touchUpInside)
    }
    
    private func initCell() {
        
        livePhotoImageView.isHidden = true
        videoButton.isHidden = true
        
        if #available(iOS 26, *) {
            videoButton.configuration = .glass()
        } else {
            videoButton.configuration = .filled()
            videoButton.tintColor = .label
            videoButton.configuration?.baseBackgroundColor = .systemBackground.withAlphaComponent(0.3)
            videoButton.layer.cornerRadius = videoButton.frame.size.height / 2
            videoButton.layer.masksToBounds = true
        }
        
        videoButton.configuration?.image = UIImage(systemName: "play")
        videoButton.configuration?.baseForegroundColor = .label

        ownerImageView.layer.cornerRadius = ownerImageView.frame.size.width / 2
        ownerImageView.layer.masksToBounds = true
        
        dateLabel.font = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: UITraitCollection(legibilityWeight: .bold))
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            previewImageViewSecondaryHeightConstraint?.constant = 900
            previewImageViewHeightConstraint?.constant = 900
        } else {
            previewImageViewSecondaryHeightConstraint?.constant = 500
            previewImageViewHeightConstraint?.constant = 500
        }
    }
}

extension TableViewCell: VLCMediaPlayerDelegate {
    
    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor [weak self] in
            self?.activityIndicator.isHidden = true
        }
    }
    
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        
        Task { @MainActor [weak self] in
            
            guard let player = self?.mediaPlayer else { return }
            
            let state = player.state
            
            //print("mediaPlayerStateChanged() - state: \(VLCMediaPlayerStateToString(state))")
            
            if state == .playing || state == .paused || (state == .buffering && player.isPlaying) {
                self?.activityIndicator.isHidden = true
            } else {
                self?.activityIndicator.isHidden = false
            }
            
            if state == .stopped {
                self?.activityIndicator.isHidden = true
                self?.mediaPlayer?.delegate = nil
                self?.mediaPlayer = nil
                self?.videoButton.configuration?.image = UIImage(systemName: "play")
                return
            }
            
            let currentScaleFactor = self?.mediaPlayer?.scaleFactor ?? 0
            let playing = self?.mediaPlayer?.isPlaying ?? false
            
            if state == .playing || (currentScaleFactor == 0 && playing), let videoSize = self?.mediaPlayer?.videoSize {
                
                let w = self?.previewImageView.frame.width ?? 0
                let h = self?.previewImageView.frame.height ?? 0
                let videoAspect = videoSize.width / videoSize.height
                let aspect = w / h
                let scale: CGFloat
                
                if (aspect >= videoAspect) {
                    scale = w / videoSize.width
                } else {
                    scale = h / videoSize.height
                }

                self?.mediaPlayer?.scaleFactor = Float(scale * UIScreen.main.scale)
            }
        }
    }
}
