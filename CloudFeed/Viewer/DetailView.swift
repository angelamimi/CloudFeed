//
//  DetailView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 7/25/24.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
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
@preconcurrency import AVFoundation
import os.log

@MainActor
protocol DetailViewDelegate: AnyObject {
    func layoutUpdated(height: CGFloat)
}

class DetailView: UIView {
    
    @IBOutlet weak var metadataStackView: UIStackView!
    
    @IBOutlet weak var fileDateLabel: UILabel!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var cameraLabel: UILabel!
    
    @IBOutlet weak var typeView: UIView!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var typeImageView: UIImageView!
    
    @IBOutlet weak var lensLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    @IBOutlet weak var isoLabel: UILabel!
    @IBOutlet weak var focalLengthLabel: UILabel!
    @IBOutlet weak var exposureLabel: UILabel!
    @IBOutlet weak var aperatureLabel: UILabel!
    @IBOutlet weak var exposureTimeLabel: UILabel!
    
    @IBOutlet weak var fpsLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    @IBOutlet weak var isoLabelWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var exposureTimeLabelWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var fpsLabelWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var durationLabelWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var divider1Label: UILabel!
    @IBOutlet weak var divider2Label: UILabel!
    @IBOutlet weak var divider3Label: UILabel!
    @IBOutlet weak var divider4Label: UILabel!
    @IBOutlet weak var divider5Label: UILabel!
    
    var metadata: Metadata?
    var url: URL?
    
    weak var delegate: DetailViewDelegate?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailView.self)
    )
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    private func commonInit() {
        
        guard let view = loadViewFromNib() else { return }
        
        view.frame = bounds
        addSubview(view)

        cameraView.clipsToBounds = true
        cameraView.layer.cornerRadius = 8
        
        typeView.clipsToBounds = true
        typeView.layer.cornerRadius = 3

        fileNameLabel.text = Strings.DetailNameNone
        fileDateLabel.text = Strings.DetailDateNone
        cameraLabel.text = Strings.DetailCameraNone
        sizeLabel.text = Strings.DetailSizeNone
        lensLabel.text = Strings.DetailLensNone
        
        isoLabel.text = "-"
        focalLengthLabel.text = "-"
        exposureLabel.text = "-"
        aperatureLabel.text = "-"
        exposureTimeLabel.text = "-"
        fpsLabel.text = "-"
        durationLabel.text = "-"
    }
    
    private func loadViewFromNib() -> UIView? {
        let nib = UINib(nibName: "DetailView", bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
    
    func populateDetails() {
        
        guard metadata != nil else { return }
        
        populateMetadataDetails()
        
        if metadata!.video {
            setVideoLabelVisibility()
            populateVideoDetails()
        } else {
            setImageLabelVisibility()
            populateImageDetails()
        }
    }
    
    func populateMetadataDetails() {
        
        guard metadata != nil else { return }
        
        fileNameLabel.text = (metadata!.fileNameView as NSString).deletingPathExtension
        fileDateLabel.text = formatDate(metadata!.date as Date)
        
        typeLabel.text = metadata!.fileExtension.uppercased()
        
        if metadata!.video {
            typeImageView.image = UIImage(systemName: "video")
        } else if metadata!.livePhoto {
            typeImageView.image = UIImage(systemName: "livephoto")
        } else {
            typeImageView.isHidden = true
        }
    }
    
    override func layoutSubviews() {
        delegate?.layoutUpdated(height: self.frame.height)
    }
    
    private func setImageLabelVisibility() {
        
        isoLabel.isHidden = false
        focalLengthLabel.isHidden = false
        exposureLabel.isHidden = false
        aperatureLabel.isHidden = false
        exposureTimeLabel.isHidden = false
        
        fpsLabel.isHidden = true
        durationLabel.isHidden = true
        
        fpsLabelWidthConstraint.constant = 0
        durationLabelWidthConstraint.constant = 0
        
        divider1Label.isHidden = false
        divider2Label.isHidden = false
        divider3Label.isHidden = false
        divider4Label.isHidden = false
        
        divider5Label.isHidden = true
    }
    
    private func setVideoLabelVisibility() {
        
        isoLabel.isHidden = true
        focalLengthLabel.isHidden = true
        exposureLabel.isHidden = true
        aperatureLabel.isHidden = true
        exposureTimeLabel.isHidden = true
        
        isoLabelWidthConstraint.constant = 0
        exposureTimeLabelWidthConstraint.constant = 0
        
        fpsLabel.isHidden = false
        durationLabel.isHidden = false
        
        let half = (metadataStackView.frame.width / 2) - 48 //padding
        fpsLabelWidthConstraint.constant = half
        durationLabelWidthConstraint.constant = half
        
        divider1Label.isHidden = true
        divider2Label.isHidden = true
        divider3Label.isHidden = true
        divider4Label.isHidden = true
        
        divider5Label.isHidden = false
    }
    
    private func populateVideoDetails() {

        guard url != nil else { return }
        
        let asset = AVAsset(url: url!)
                
        populateVideoDetail(metadata: metadata!, asset: asset)
        populateVideoMetadata(asset: asset)
    }
    
    private func populateImageDetails() {
        
        guard url != nil else { return }
        
        guard let originalSource = CGImageSourceCreateWithURL(url! as CFURL, nil) else { return }
        guard let fileProperties = CGImageSourceCopyProperties(originalSource, nil) else { return }
        let properties = NSMutableDictionary(dictionary: fileProperties)

        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) else { return }
        let imagePropertyDict = NSMutableDictionary(dictionary: imageProperties)
        
        populateImageSizeInfo(pixelProperties: imagePropertyDict, sizeProperties: properties)
        
        if let exif = imagePropertyDict[kCGImagePropertyExifDictionary] as? [NSString: AnyObject] {
            populateImageExifInfo(exif)
        }

        if let tiff = imagePropertyDict[kCGImagePropertyTIFFDictionary] as? [NSString: AnyObject] {
            populateImageTiffInfo(tiff)
        }
    }
    
    private func populateImageTiffInfo(_ tiff: [NSString: AnyObject]) {
        
        let make = tiff[kCGImagePropertyTIFFMake] as? String
        let model = tiff[kCGImagePropertyTIFFModel] as? String
        
        if make != nil && model != nil {
            if model!.starts(with: make!) {
                cameraLabel.text = model
            } else {
                cameraLabel.text = "\(make!) \(model!)"
            }
        } else if make == nil && model != nil {
            cameraLabel.text = model
        } else if make != nil && model == nil {
            cameraLabel.text = make
        }
    }
    
    private func populateImageSizeInfo(pixelProperties: NSMutableDictionary, sizeProperties: NSMutableDictionary) {
        
        var width: Int? = pixelProperties[kCGImagePropertyPixelWidth] as? Int
        var height: Int? = pixelProperties[kCGImagePropertyPixelHeight] as? Int
        var formattedPixels: String?
        var formattedMegaPixels: String?
        var formattedFileSize: String?
        
        if width == nil || height == nil {
            width = metadata!.width
            height = metadata!.height
        }
        
        if width == nil || height == nil || width == 0 || height == 0 {
            //Self.logger.debug("No pixel info")
        } else {
            
            formattedPixels = "\(width!) x \(height!)"
            
            let megaPixels: Double = Double(width! * height!) / 1000000
            formattedMegaPixels = megaPixels < 1 ? String(format: "%.1f MP", megaPixels) : "\(Int(megaPixels)) MP"
        }
        
        if let rawFileSize = sizeProperties[kCGImagePropertyFileSize], let fileSize = rawFileSize as? Int64 {
            formattedFileSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        } else if metadata!.size > 0 {
            formattedFileSize = ByteCountFormatter.string(fromByteCount: metadata!.size, countStyle: .file)
        }
        
        let finalFormattedSize: String
        
        if formattedFileSize == nil && formattedPixels == nil {
            finalFormattedSize = Strings.DetailSizeNone
        } else if formattedFileSize != nil && formattedPixels == nil {
            finalFormattedSize = formattedFileSize!
        } else if formattedFileSize == nil && formattedPixels != nil {
            finalFormattedSize = "\(formattedMegaPixels!) • \(formattedPixels!)"
        } else {
            finalFormattedSize = "\(formattedMegaPixels!) • \(formattedPixels!) • \(formattedFileSize!)"
        }
        
        sizeLabel.text = finalFormattedSize
    }
    
    private func populateImageExifInfo(_ exif: [NSString: AnyObject]) {
        
        let make = exif[kCGImagePropertyExifLensMake] as? String
        let model = exif[kCGImagePropertyExifLensModel] as? String
        
        if make != nil && model != nil {
            if model!.starts(with: make!) {
                lensLabel.text = model
            } else {
                lensLabel.text = "\(make!) \(model!)"
            }
        } else if make == nil && model != nil {
            lensLabel.text = model
        } else if make != nil && model == nil {
            lensLabel.text = make
        }
        
        if let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int] {
            if iso.isEmpty || iso.count == 0 {

            } else {
                isoLabel.text = "ISO \(iso[0].description)"
            }
        }
        
        if let focalLength = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Int {
            focalLengthLabel.text = "\(focalLength.description) mm"
        }
        
        if let exposure = exif[kCGImagePropertyExifExposureBiasValue] as? Int {
            exposureLabel.text = "\(exposure.description) ev"
        }
        
        if let apertureValue = exif[kCGImagePropertyExifFNumber] as? Double {
            aperatureLabel.text = "ƒ\(apertureValue.description)"
        }
        
        if let exposureTimeValue = exif[kCGImagePropertyExifExposureTime] as? Double {
            exposureTimeLabel.text = "1/" + String(format:"%.0f", 1/exposureTimeValue) + " s"
        }
    }
    
    private func populateVideoDetail(metadata: Metadata, asset: AVAsset) {
        
        Task {
        
            let duration = try? await asset.load(.duration)
            
            populateDisplayTime(duration?.seconds)
            
            if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
                
                let frameRate = try? await videoTrack.load(.nominalFrameRate)
                
                if frameRate != nil && frameRate! > 0 {
                    let displayFrameRate = Float(round(100 * frameRate!) / 100)
                    setFrameRateText("\(displayFrameRate) FPS")
                }
                
                await populateVideoSize(metadata: metadata, videoTrack: videoTrack)

            } else {
                //Self.logger.debug("populateVideoDetails() - no video tracks found")
            }
        }
    }
    
    private func populateVideoMetadata(asset: AVAsset) {
        
        Task { [weak self] in
            
            guard let avMetadataItems: [AVMetadataItem]? = try? await asset.load(.metadata) else { return }
            var make: String?
            var model: String?
            
            for item in avMetadataItems! {
                
                guard let keyName = item.commonKey else { continue }

                switch keyName {
                //case .commonKeyLocation:
                //case .commonKeyCreationDate:
                case .commonKeyMake:
                    make = try? await item.load(.stringValue)
                case .commonKeyModel:
                    model = try? await item.load(.stringValue)
                default: ()
                }
            }
            
            self?.populateVideoCameraMakeModel(make: make, model: model)
        }
    }
    
    private func populateVideoSize(metadata: Metadata, videoTrack: AVAssetTrack) async {
        
        var formattedFileSize: String?
        var rawSize = try? await videoTrack.load(.naturalSize).applying(videoTrack.load(.preferredTransform))
        
        if rawSize == nil {
            rawSize = CGSize(width: metadata.width, height: metadata.height)
        }
        
        if metadata.size > 0 {
            formattedFileSize = ByteCountFormatter.string(fromByteCount: metadata.size, countStyle: .file)
        }
        
        if !hasText(formattedFileSize) && !hasSize(rawSize) {

        } else if hasText(formattedFileSize) && !hasSize(rawSize) {
            setFileSizeText(formattedFileSize!)
        } else if !hasText(formattedFileSize) && hasSize(rawSize) {
            setFileSizeText("\(abs(Int(rawSize!.width))) x \(abs(Int(rawSize!.height)))")
        } else {
            setFileSizeText("\(abs(Int(rawSize!.width))) x \(abs(Int(rawSize!.height))) • \(formattedFileSize!)")
        }
    }
    
    private func populateVideoCameraMakeModel(make: String?, model: String?) {
        
        if hasText(make) && hasText(model) {
            setMakeModelText("\(make!) \(model!)")
        } else if hasText(make) && !hasText(model) {
            setMakeModelText(make!)
        } else if !hasText(make) && hasText(model) {
            setMakeModelText(model!)
        }
    }
     
    private func setMakeModelText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraLabel.text = text
        }
    }
    
    private func setFrameRateText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.fpsLabel.text = text
        }
    }
    
    private func setDurationText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.durationLabel.text = text
        }
    }
    
    private func setFileSizeText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.sizeLabel.text = text
        }
    }
    
    private func hasText(_ value: String?) -> Bool {
        return value != nil && !value!.isEmpty
    }
    
    private func hasSize(_ size: CGSize?) -> Bool {
        return size != nil && size!.width > 0 && size!.height > 0
    }
    
    private func populateDisplayTime(_ seconds: Double?) {
        
        if seconds == nil || seconds! == 0 {
            //Self.logger.debug("getDisplayTime() - nothing to convert")
        } else {
            let duration = Duration.seconds(seconds!)
            let formatted = duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 1, fractionalSecondsLength: 0)))
        
            setDurationText(formatted)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        
        var formattedDate = ""
        let formatter = DateFormatter()
        
        formatter.dateFormat = "EEEE"
        let dayString = formatter.string(from: date)
        formattedDate.append(dayString)
        formattedDate.append(" • ")

        formatter.dateFormat = "MMM d, yyyy"
        let dateString = formatter.string(from: date)
        formattedDate.append(dateString)
        formattedDate.append(" • ")

        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: date)
        formattedDate.append(timeString)
        
        return formattedDate
    }
}
