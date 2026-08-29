//
//  TableCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 7/29/26.
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
protocol TableCellDelegate: AnyObject {
    func toggleFavoriteForMetadata(metadataId: String)
    func shareForMetadata(metadataId: String)
    func commentForMetadata(metadataId: String)
    func videoForMetadata(metadataId: String)
}

class TableCell: UITableViewCell {

    @IBOutlet weak var ownerImageView: UIImageView!
    @IBOutlet weak var ownerLabel: UILabel!

    @IBOutlet weak var previewImageView: SizingImageView!

    @IBOutlet weak var livePhotoImageView: UIImageView!
    @IBOutlet weak var videoButton: UIButton!

    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var commentButton: UIButton!

    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var typeContainerView: UIView!

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var createDateLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    @IBOutlet weak var pixelSizeLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    @IBOutlet weak var dateStackView: UIStackView!
    @IBOutlet weak var createStackView: UIStackView!

    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var bottomStackView: UIStackView!
    @IBOutlet weak var infoStackView: UIStackView!
    @IBOutlet weak var dataStackView: UIStackView!

    @IBOutlet weak var previewImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var previewImageViewMinHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var metadataId: String?
    weak var delegate: TableCellDelegate?

    private var avpLayer: AVPlayerLayer?
    private var mediaPlayer: VLCMediaPlayer?

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()

        MainActor.assumeIsolated { [weak self] in
            self?.initCell()
            self?.initActions()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        stopVideo()
        stopLiveVideo()

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

        previewImageView.contentMode = .scaleAspectFill
        previewImageView.alpha = 0

        activityIndicator.startAnimating()
        activityIndicator.isHidden = false

        setImageViewHeightConstraint()
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

    func invalidate() {
        bottomStackView.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
    }

    func setPreviewImage(_ image: UIImage?) {

        activityIndicator.isHidden = true

        if image == nil {
            previewImageView.image = nil
        } else {

            if ImageUtility.ratioWithinThreshold(image!.size) {
                previewImageView.contentMode = .scaleAspectFill
            } else {
                previewImageView.contentMode = .scaleAspectFit
            }

            previewImageView.image = image

            UIView.animate(withDuration: 0.6, animations: { [weak self] in
                self?.previewImageView.alpha = 1
            })
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
            favoriteButton.configuration?.image = UIImage(systemName: "star.fill")
        } else {
            favoriteButton.configuration?.image = UIImage(systemName: "star")
        }
    }

    func setInfoVisibility(_ visible: Bool) {
        if dataStackView.isHidden != !visible {
            dataStackView.isHidden = !visible
        }
    }

    func setSystemImage(name: String) {

        activityIndicator.isHidden = true

        let config = UIImage.SymbolConfiguration(pointSize: 50)

        previewImageView.image = UIImage(systemName: name, withConfiguration: config)
        previewImageView.contentMode = .center
        previewImageView.alpha = 1
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

        avpLayer?.frame = previewImageView.bounds
        avpLayer?.videoGravity = .resizeAspectFill

        previewImageView.layer.addSublayer(avpLayer!)

        UIView.animate(withDuration: 0.4, animations: { [weak self] in
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

        livePhotoImageView.isHidden = false
    }

    private func initActions() {
        favoriteButton.addTarget(self, action: #selector(favoriteButtonTouched), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTouched), for: .touchUpInside)
        commentButton.addTarget(self, action: #selector(commentButtonTouched), for: .touchUpInside)
        videoButton.addTarget(self, action: #selector(videoButtonTouched), for: .touchUpInside)
    }

    private func initCell() {

        accessibilityElements = [ownerImageView!, ownerLabel!, previewImageView!, favoriteButton!, shareButton!,
                                 commentButton!, dateLabel!, createDateLabel!, nameLabel!, typeLabel!, sizeLabel!, pixelSizeLabel!]

        livePhotoImageView.isHidden = true
        videoButton.isHidden = true

        if #available(iOS 26, *) {
            videoButton.configuration = .glass()
        } else {
            videoButton.configuration = .filled()
            videoButton.tintColor = .label
            videoButton.configuration?.baseBackgroundColor = .systemBackground.withAlphaComponent(0.3)
            videoButton.layer.cornerRadius = 20
            videoButton.layer.masksToBounds = true
        }

        videoButton.configuration?.image = UIImage(systemName: "play")
        videoButton.configuration?.baseForegroundColor = .label

        ownerImageView.layer.cornerRadius = ownerImageView.frame.size.width / 2
        ownerImageView.layer.masksToBounds = true

        dateLabel.font = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: UITraitCollection(legibilityWeight: .bold))
        createDateLabel.font = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: UITraitCollection(legibilityWeight: .bold))

        actionStackView.layoutMargins = .zero
        actionStackView.insetsLayoutMarginsFromSafeArea = true
        actionStackView.isLayoutMarginsRelativeArrangement = false

        typeContainerView.layer.borderColor = UIColor.label.cgColor
        typeContainerView.layer.borderWidth = 1
        typeContainerView.layer.cornerRadius = 4
        typeContainerView.layer.backgroundColor = UIColor.systemBackground.cgColor

        setImageViewHeightConstraint()
    }

    private func setImageViewHeightConstraint() {

        var height: CGFloat = 550

        if let size = Environment.current.windowSize {
            height = max(size.width, size.height) * 0.65
        }

        previewImageViewHeightConstraint?.constant = height
        previewImageViewMinHeightConstraint?.constant = height
    }
}

extension TableCell: VLCMediaPlayerDelegate {

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor [weak self] in
            self?.activityIndicator.isHidden = true
        }
    }

    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {

        Task { @MainActor [weak self] in

            guard let player = self?.mediaPlayer else { return }

            let state = player.state

            //Self.logger.debug("mediaPlayerStateChanged() - state: \(VLCMediaPlayerStateToString(state))")

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

                if aspect >= videoAspect {
                    scale = w / videoSize.width
                } else {
                    scale = h / videoSize.height
                }

                self?.mediaPlayer?.scaleFactor = Float(scale * UIScreen.main.scale)
            }
        }
    }
}
