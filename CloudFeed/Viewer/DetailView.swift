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

@preconcurrency import AVFoundation
import MapKit
import os.log
import UIKit

@MainActor
protocol DetailViewDelegate: AnyObject {
    func showAllDetails(metadata: Metadata)
    func detailsLoaded()
}

class DetailView: UIView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var contentStackViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentStackViewBottomConstraint: NSLayoutConstraint!

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var metadataButton: UIButton!
    
    @IBOutlet weak var fillerView: UIView!
    
    @IBOutlet weak var metadataStackView: UIStackView!
    
    @IBOutlet weak var fileDateLabel: UILabel!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var cameraStackView: UIStackView!
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
    
    override func awakeFromNib() {
        super.awakeFromNib()

        MainActor.assumeIsolated {
            commonInit()
        }
    }
    
    func height() -> CGFloat {
        guard subviews.count > 0 else { return 0 }
        return contentStackView.frame.height
    }
    
    func populateDetails() {
        
        guard metadata != nil && subviews.count > 0 else { return }
        
        populateMetadataDetails()

        if metadata!.video {
            setVideoLabelVisibility()
            populateVideoDetails()
        } else {
            setImageLabelVisibility()
            Task.detached { [weak self] in
                await self?.populateImageDetails()
            }
        }
    }
    
    private func commonInit() {
        
        initElements()
 
        if metadata != nil {
            populateDetails()
        }
    }
    
    private func initElements() {
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            //needed to get the actual height of detail view for popover. See layoutSubviews.
            contentStackViewHeightConstraint?.isActive = false
            contentStackViewBottomConstraint?.isActive = true
        }
        
        metadataButton.setTitle(Strings.DetailAll, for: .normal)
        metadataButton.addTarget(self, action: #selector(showAllDetails), for: .touchUpInside)

        cameraStackView.clipsToBounds = true
        cameraStackView.layer.cornerRadius = 8
        
        typeView.clipsToBounds = true
        typeView.layer.cornerRadius = 3
        
        fileNameLabel.text = Strings.DetailNameNone
        fileNameLabel.accessibilityLabel = Strings.DetailName
        fileNameLabel.accessibilityValue = Strings.DetailNameNone
        
        fileDateLabel.text = Strings.DetailDateNone
        fileDateLabel.accessibilityLabel = Strings.DetailFileDate
        fileDateLabel.accessibilityValue = Strings.DetailDateNone

        resetLabels()

        isoLabel.isAccessibilityElement = false
        focalLengthLabel.isAccessibilityElement = false
        exposureLabel.isAccessibilityElement = false
        aperatureLabel.isAccessibilityElement = false
        exposureTimeLabel.isAccessibilityElement = false
        fpsLabel.isAccessibilityElement = false
        durationLabel.isAccessibilityElement = false
        
        mapView.layer.cornerRadius = 8
        mapView.delegate = self
        mapView.alpha = 0
        
        metadataStackView.maximumContentSizeCategory = .accessibilityMedium
        
        mapView.setCameraZoomRange(.init(maxCenterCoordinateDistance: 500), animated: false)
    }
    
    private func resetLabels() {
        
        cameraLabel.text = Strings.DetailCameraNone
        cameraLabel.accessibilityLabel = Strings.DetailCameraDescription
        cameraLabel.accessibilityValue = Strings.DetailCameraNone
        
        sizeLabel.text = Strings.DetailSizeNone
        sizeLabel.accessibilityLabel = Strings.DetailSizeDescription
        sizeLabel.accessibilityValue = Strings.DetailSizeNone
        
        lensLabel.text = Strings.DetailLensNone
        lensLabel.accessibilityLabel = Strings.DetailLensDescription
        lensLabel.accessibilityValue = Strings.DetailLensNone
        
        isoLabel.text = "-"
        focalLengthLabel.text = "-"
        exposureLabel.text = "-"
        aperatureLabel.text = "-"
        exposureTimeLabel.text = "-"
        fpsLabel.text = "-"
        durationLabel.text = "-"
    }
    
    @objc private func showAllDetails() {
        if metadata != nil {
            delegate?.showAllDetails(metadata: metadata!)
        }
    }
    
    private func populateMetadataDetails() {
        
        guard metadata != nil else { return }
        
        let name = (metadata!.fileNameView as NSString).deletingPathExtension
        fileNameLabel.text = name
        fileNameLabel.accessibilityLabel = Strings.DetailName
        fileNameLabel.accessibilityValue = name
        
        let formattedDate = formatDate(metadata!.datePhotosOriginal as Date)
        fileDateLabel.text = formattedDate
        fileDateLabel.accessibilityLabel = Strings.DetailFileDate
        fileDateLabel.accessibilityValue = formattedDate
        
        let type = metadata!.fileExtension.uppercased()
        typeLabel.text = type
        typeLabel.accessibilityLabel = Strings.DetailFileFormat
        typeLabel.accessibilityValue = type
        
        if metadata!.video {
            typeImageView.image = UIImage(systemName: "video")
            typeImageView.accessibilityLabel = Strings.DetailVideoTypeVideo
        } else if metadata!.livePhoto {
            typeImageView.image = UIImage(systemName: "livephoto")
            typeImageView.accessibilityLabel = Strings.DetailVideoTypeLive
        } else {
            typeImageView.isHidden = true
        }
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
    
    func initDetails(metadata: Metadata, url: URL?) {
        self.metadata = metadata
        self.url = url
    }
    
    private func populateVideoDetails() {

        guard url != nil else { return }
        
        resetLabels()
        
        let asset = AVAsset(url: url!)
                
        populateVideoDetail(metadata: metadata!, asset: asset)
        populateVideoMetadata(asset: asset)
    }
    
    private func populateImageDetails() async {

        resetLabels()
        
        guard url != nil else {
            populateImageSizeInfo(pixelProperties: [:], sizeProperties: [:])
            populateLocationFromMetadata()
            //populateExifFromMetadata()
            return
        }

        guard let originalSource = CGImageSourceCreateWithURL(url! as CFURL, nil),
              let fileProperties = CGImageSourceCopyProperties(originalSource, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) else {
            populateLocationFromMetadata()
            return
        }
        
        let properties = NSMutableDictionary(dictionary: fileProperties)
        let imagePropertyDict = NSMutableDictionary(dictionary: imageProperties)
        
        populateImageSizeInfo(pixelProperties: imagePropertyDict, sizeProperties: properties)
        await populateImageLocationInfo(imageProperties: imagePropertyDict)
        
        var camera: String? = ""
        if let tiff = imagePropertyDict[kCGImagePropertyTIFFDictionary] as? [NSString: AnyObject] {
            camera = populateImageTiffInfo(tiff)
        }
        
        if let exif = imagePropertyDict[kCGImagePropertyExifDictionary] as? [NSString: AnyObject] {
            populateImageExifInfo(exif, camera)
        }
    }
    
    private func populateLocationFromMetadata() {
        
        if let latitude = metadata?.latitude, let longitude = metadata?.longitude {
            Task.detached { [weak self] in
                await self?.showLocation(latitudeValue: latitude, longitudeValue: longitude)
            }
        }
    }
    
    private func populateExifFromMetadata() {
        
        if let exifArray = metadata?.exifPhotos {
            var dict: [NSString:AnyObject] = [:]
            for exif in exifArray {
                _ = exif.map { dict[$0.key as NSString] = $0.value as AnyObject }
            }
            
            populateImageExifInfo(dict, nil)
        }
    }
    
    private func populateImageLocationInfo(imageProperties: NSMutableDictionary) async {
        
        guard let gpsData = imageProperties[kCGImagePropertyGPSDictionary] as? [NSString: AnyObject] else {
            populateLocationFromMetadata()
            return
        }
        
        let latitudeValue = gpsData[kCGImagePropertyGPSLatitude] as? Double
        let longitudeValue = gpsData[kCGImagePropertyGPSLongitude] as? Double
        let latitudeReferencValue = gpsData[kCGImagePropertyGPSLatitudeRef] as? String
        let longitudeReferenceValue = gpsData[kCGImagePropertyGPSLongitudeRef] as? String
        
        let results = calculateLocationFromProperties(latitude: latitudeValue, longitude: longitudeValue,
                                                      latitudeReference: latitudeReferencValue, longitudeReference: longitudeReferenceValue)

        Task.detached { [weak self] in
            await self?.showLocation(latitudeValue: results.latitude, longitudeValue: results.longitude)
        }
    }
    
    private func calculateLocationFromProperties(latitude: Double?, longitude: Double?, latitudeReference: String?, longitudeReference: String?) -> (latitude: Double?, longitude: Double?){
        
        guard latitude != nil && longitude != nil else { return (latitude: nil, longitude: nil) }
        
        var latitudeDirection: Double = 1, longitudeDirection: Double = 1
        
        if latitude! > 0 && latitudeReference != nil && latitudeReference!.starts(with: "S") {
            latitudeDirection = -1
        }
        
        if longitude! > 0 && longitudeReference != nil && longitudeReference!.starts(with: "W") {
            longitudeDirection = -1
        }
        
        return (latitude: latitude! * latitudeDirection, longitude: longitude! * longitudeDirection)
    }
    
    private func populateImageTiffInfo(_ tiff: [NSString: AnyObject]) -> String? {
        
        let make = tiff[kCGImagePropertyTIFFMake] as? String
        let model = tiff[kCGImagePropertyTIFFModel] as? String
        let label: String?
        
        if make != nil && model != nil {
            if model!.starts(with: make!) {
                label = model
            } else {
                label = "\(make!) \(model!)"
            }
        } else if make == nil && model != nil {
            label = model
        } else if make != nil && model == nil {
            label = make
        } else {
            label = ""
        }
        
        if label != nil && !label!.isEmpty {
            setMakeModelText(label!)
        } else {
            setMakeModelText(Strings.DetailCameraNone)
        }
        
        return label
    }
    
    private func populateImageSizeInfo(pixelProperties: NSMutableDictionary, sizeProperties: NSMutableDictionary) {

        var width: Double? = pixelProperties[kCGImagePropertyPixelWidth] as? Double
        var height: Double? = pixelProperties[kCGImagePropertyPixelHeight] as? Double
        var formattedPixels: String?
        var formattedMegaPixels: String?
        var formattedFileSize: String?
        
        if width == nil || height == nil {
            width = metadata!.width
            height = metadata!.height
        }
        
        if width == nil || height == nil || width == 0 || height == 0 {
            //Self.logger.debug("No pixel info")
            sizeLabel.text = Strings.DetailSizeNone
            sizeLabel.accessibilityValue = Strings.DetailSizeNone
        } else {
            
            let formattedWidth = String(format: "%.0f", width!)
            let formattedHeight = String(format: "%.0f", height!)
            
            formattedPixels = "\(formattedWidth) x \(formattedHeight)"
            
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
        sizeLabel.accessibilityValue = finalFormattedSize
    }
    
    private func populateImageExifInfo(_ exif: [NSString: AnyObject], _ camera: String?) {
        
        let make = exif[kCGImagePropertyExifLensMake] as? String
        let model = exif[kCGImagePropertyExifLensModel] as? String
        let lens: String?
        let lensText: String
        
        if make != nil && model != nil {
            if model!.starts(with: make!) {
                lens = model
            } else {
                lens = "\(make!) \(model!)"
            }
        } else if make == nil && model != nil {
            lens = model
        } else if make != nil && model == nil {
            lens = make
        } else {
            lens = ""
        }
        
        if lens != nil && !lens!.isEmpty {
            if camera != nil && !camera!.isEmpty && lens!.starts(with: camera!) {
                let text = lens!.suffix(from: camera!.endIndex).description.trimmingCharacters(in: .whitespaces)
                lensText = text.prefix(1).uppercased() + text.dropFirst()
            } else {
                lensText = lens!
            }
        } else {
            lensText = Strings.DetailLensNone
        }

        lensLabel.text = lensText
        lensLabel.accessibilityValue = lensText
        
        if let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int] {
            if iso.isEmpty || iso.count == 0 {

            } else {
                isoLabel.text = "ISO \(iso[0].description)"
                isoLabel.isAccessibilityElement = true
                isoLabel.accessibilityLabel = "ISO"
                isoLabel.accessibilityValue = iso[0].description
            }
        }
        
        if let focalLength = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Int {
            let formattedFocalLength = "\(focalLength.description) mm"
            focalLengthLabel.text = formattedFocalLength
            focalLengthLabel.isAccessibilityElement = true
            focalLengthLabel.accessibilityLabel = Strings.DetailFocalLength
            focalLengthLabel.accessibilityValue = formattedFocalLength
        }
        
        if let exposure = exif[kCGImagePropertyExifExposureBiasValue] as? Int {
            exposureLabel.text = "\(exposure.description) ev"
            exposureLabel.isAccessibilityElement = true
            exposureLabel.accessibilityLabel = Strings.DetailExposure
            exposureLabel.accessibilityValue = "\(exposure.description) e v"
        }
        
        if let apertureValue = exif[kCGImagePropertyExifFNumber] as? Double {
            let formattedApertureValue = apertureValue.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...2)))
            aperatureLabel.text = "ƒ\(formattedApertureValue)"
            aperatureLabel.isAccessibilityElement = true
            aperatureLabel.accessibilityLabel = Strings.DetailAperture
            aperatureLabel.accessibilityValue = "f \(formattedApertureValue)"
        }
        
        if let exposureTimeValue = exif[kCGImagePropertyExifExposureTime] as? Double {
            
            let formattedExposureTime: String
            
            if exposureTimeValue >= 1 {
                formattedExposureTime = String(format:"%.0f", exposureTimeValue) + " s"
            } else {
                formattedExposureTime = "1/" + String(format:"%.0f", 1/exposureTimeValue) + " s"
            }
            
            exposureTimeLabel.text = formattedExposureTime
            exposureTimeLabel.isAccessibilityElement = true
            exposureTimeLabel.accessibilityLabel = Strings.DetailExposureTime
            exposureTimeLabel.accessibilityValue = formattedExposureTime
        }
    }
    
    private func populateVideoDetail(metadata: Metadata, asset: AVAsset) {
        
        Task { [weak self] in
        
            let duration = try? await asset.load(.duration)
            
            self?.populateDisplayTime(duration?.seconds)
            
            if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
                
                let frameRate = try? await videoTrack.load(.nominalFrameRate)
                
                if frameRate != nil && frameRate! > 0 {
                    let displayFrameRate = Float(round(100 * frameRate!) / 100)
                    self?.setFrameRateText("\(displayFrameRate) FPS")
                }
                
                await self?.populateVideoSize(metadata: metadata, videoTrack: videoTrack)
            }
        }
    }
    
    private func populateVideoMetadata(asset: AVAsset) {
        
        Task { [weak self] in
            
            guard let avMetadataItems: [AVMetadataItem]? = try? await asset.load(.metadata) else { return }
            var make: String?
            var model: String?
            //var software: String?
            var location: CLLocation?
            
            for item in avMetadataItems! {
                
                guard let keyName = item.commonKey else { continue }
                
                switch keyName {
                case .commonKeyLocation:
                    location = await self?.parseLocation(item: item)
                //case .commonKeySoftware:
                    //software = try? await item.load(.stringValue)
                //case .commonKeyCreationDate:
                case .commonKeyMake:
                    make = try? await item.load(.stringValue)
                case .commonKeyModel:
                    model = try? await item.load(.stringValue)
                default: ()
                }
            }

            self?.populateVideoCameraMakeModel(make: make, model: model)
            await self?.populateVideoLocation(location: location)
        }
    }
    
    private func parseLocation(item: AVMetadataItem) async -> CLLocation? {
        
        if let locationString = try? await item.load(.stringValue) {
            
            let indexLat = locationString.index(locationString.startIndex, offsetBy: 8)
            let indexLong = locationString.index(indexLat, offsetBy: 9)
            
            let lat = String(locationString[locationString.startIndex..<indexLat])
            let long = String(locationString[indexLat..<indexLong])
            
            if let lattitude = Double(lat), let longitude = Double(long) {
                return CLLocation(latitude: lattitude, longitude: longitude)
            }
        }
        
        return nil
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
        } else {
            setMakeModelText(Strings.DetailCameraNone)
        }
    }
    
    private func populateVideoLocation(location: CLLocation?) async {
        
        if let videoLocation = location {
            await showLocation(latitudeValue: videoLocation.coordinate.latitude, longitudeValue: videoLocation.coordinate.longitude)
        } else {
            await setMapHidden(true)
        }
    }
     
    private func setMakeModelText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraLabel.text = text
            self?.cameraLabel.accessibilityLabel = Strings.DetailCameraDescription
            self?.cameraLabel.accessibilityValue = text
        }
    }
    
    private func setFrameRateText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.fpsLabel.text = text
            self?.fpsLabel.isAccessibilityElement = true
            self?.fpsLabel.accessibilityLabel = Strings.DetailVideoSpeed
            self?.fpsLabel.accessibilityValue = text
        }
    }
    
    private func setDurationText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.durationLabel.text = text
            self?.durationLabel.isAccessibilityElement = true
            self?.durationLabel.accessibilityLabel = Strings.DetailVideoLength
            self?.durationLabel.accessibilityValue = text
        }
    }
    
    private func setFileSizeText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.sizeLabel.text = text
            self?.sizeLabel.accessibilityValue = text
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

    private func showLocation(latitudeValue: Double?, longitudeValue: Double?) async {

        guard let latitude = latitudeValue, let longitude = longitudeValue, !(latitude == 0 && longitude == 0) else {
            await setMapHidden(true)
            return
        }
        
        await setMapHidden(false)
        await addMapAnnotation(latitude: latitude, longitude: longitude)
    }
    
    private func setMapHidden(_ hidden: Bool) async {

        if mapView.isHidden == hidden {
            delegate?.detailsLoaded()
            return
        }
        
        mapView.isHidden = hidden
        contentStackView.setNeedsLayout()

        await withCheckedContinuation { continuation in
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                self?.contentStackView.layoutIfNeeded()
            }, completion: { [weak self] _ in
                UIView.animate(withDuration: 0.4, animations: { [weak self] in
                    self?.mapView.alpha = 1
                })
                self?.delegate?.detailsLoaded()
                continuation.resume()
            })
        }
    }
    
    private func addMapAnnotation(latitude: Double, longitude: Double) async {
        
        let annotation = MKPointAnnotation()
        
        annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let region = MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        let geocoder = CLGeocoder()
        let placemarks = try? await geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        let placemark = placemarks?.first
        let locationComponents: [String] = placemark == nil ? [] : [placemark!.name, placemark!.locality, placemark!.country].compactMap { $0 }
        let locationName = locationComponents.joined(separator: ", ")
        
        if locationName.isEmpty == false {
            annotation.title = locationName
        }

        mapView.removeAnnotations(mapView.annotations)
        mapView.setRegion(region, animated: false)
        mapView.addAnnotation(annotation)
    }
}

extension DetailView: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {

        mapView.deselectAnnotation(annotation, animated: false)
        
        let placemark = MKPlacemark(coordinate: annotation.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        if annotation.title != nil && annotation.title!?.isEmpty == false {
            mapItem.name = annotation.title!
        }
        
        mapItem.openInMaps()
    }
}
