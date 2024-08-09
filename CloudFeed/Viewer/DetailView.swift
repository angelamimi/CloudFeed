//
//  DetailView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 7/25/24.
//

import UIKit
import AVFoundation
import os.log

class DetailView: UIView {
    
    @IBOutlet weak var metadataStackView: UIStackView!
    
    @IBOutlet weak var fileDateLabel: UILabel!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var cameraLabel: UILabel!
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
    
    var metadata: tableMetadata?
    var url: URL?
    
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

        fileNameLabel.text = "No name information"
        fileDateLabel.text = "No date information"
        cameraLabel.text = "No camera information"
        sizeLabel.text = "No size information"
        lensLabel.text = "No lens information" //TODO: Externalize text
        
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
        
        //Self.logger.debug("populateDetails() - url? \(self.url != nil) file: \(self.metadata!.fileNameView)")
        
        guard metadata != nil else { return }
        
        //Self.logger.debug("populateDetails() - file: \(self.metadata!.fileNameView)")
                          
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
        
        //Self.logger.debug("populateMetadataDetails() - file: \(self.metadata!.fileNameView)")
                          
        fileNameLabel.text = metadata!.fileNameView
        fileDateLabel.text = formatDate(metadata!.date as Date)
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
        
        //TODO: Account for one or the other too
        if make != nil && make != nil {
            cameraLabel.text = "\(make ?? "") \(model ?? "")"
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
            finalFormattedSize = "No size information" //TODO: Externalize text
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
        
        /*if let lensMake = exif[kCGImagePropertyExifLensMake] as? String {
         Self.logger.debug("lensMake: \(lensMake)")
        }
        
        if let lensModel = exif[kCGImagePropertyExifLensModel] as? String {
         Self.logger.debug("lensModel: \(lensModel)")
        }
        
        if let lensSpecification = exif[kCGImagePropertyExifLensSpecification] as? String {
         Self.logger.debug("lensSpecification: \(lensSpecification)")
        }*/
        
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
    
    private func populateVideoDetail(metadata: tableMetadata, asset: AVAsset) {
        
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
        
        Task.detached { [weak self] in

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
            
            await self?.populateVideoCameraMakeModel(make: make, model: model)
        }
    }
    
    private func populateVideoSize(metadata: tableMetadata, videoTrack: AVAssetTrack) async {
        
        var formattedFileSize: String?
        var rawSize = try? await videoTrack.load(.naturalSize).applying(videoTrack.load(.preferredTransform))
        
        if rawSize == nil {
            rawSize = CGSize(width: metadata.width, height: metadata.height)
        }
        
        if metadata.size > 0 {
            formattedFileSize = ByteCountFormatter.string(fromByteCount: metadata.size, countStyle: .file)
        }
        
        if !hasText(formattedFileSize) && !hasSize(rawSize) {
            //TODO: Set text for missing size info?
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
        } /*else {
            setMakeModelText("No camera information") //TODO: externalize text
        }*/
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
            Self.logger.debug("getDisplayTime() - nothing to convert")
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
