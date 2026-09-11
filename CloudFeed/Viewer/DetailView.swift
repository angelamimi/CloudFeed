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
    @IBOutlet weak var contentStackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var metadataCollectionViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var metadataButton: UIButton!
    @IBOutlet weak var fillerView: UIView!
    @IBOutlet weak var metadataCollectionView: UICollectionView!
    @IBOutlet weak var fileDateLabel: UILabel!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var cameraStackView: UIStackView!
    @IBOutlet weak var cameraLabel: UILabel!
    @IBOutlet weak var typeView: UIView!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var typeImageView: UIImageView!
    @IBOutlet weak var lensLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    var mapView: MKMapView?
    var metadata: Metadata?
    var url: URL?

    weak var delegate: DetailViewDelegate?
    var popover: Bool = false

    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private var exifTitles: [Int: ExifTitle] = [:]

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailView.self)
    )

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()

        MainActor.assumeIsolated { [weak self] in
            self?.initView()
        }
    }

    @MainActor
    deinit {
        mapView?.delegate = nil
    }

    func height() -> CGFloat {
        guard subviews.count > 0 else { return 0 }
        return contentStackView.frame.height
    }

    func populateDetails() {

        guard metadata != nil && subviews.count > 0 else { return }

        populateMetadataDetails()

        if metadata!.video {
            populateVideoDetails()
        } else {
            populateImageDetails()
        }
    }

    private func initView() {

        initElements()

        if metadata != nil {
            populateDetails()
        }
    }

    private func initElements() {

        metadataButton.configuration?.baseForegroundColor = .tintColor
        metadataButton.configuration?.baseBackgroundColor = .systemGray5.withAlphaComponent(0.5)
        metadataButton.configuration?.title = Strings.DetailAll
        metadataButton.addTarget(self, action: #selector(showAllDetails), for: .touchUpInside)
        metadataButton.setContentHuggingPriority(.required, for: .vertical)

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

        initMetadataCollectionView()
    }

    private func initMetadataCollectionView() {

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { [weak self] cell, _, item in

            var content = cell.defaultContentConfiguration()
            let exifTitle = self?.exifTitles[item]
            let separation = exifTitle?.title == "|"

            content.text = exifTitle?.title
            content.textProperties.font = UIFont.preferredFont(forTextStyle: .footnote)
            content.textProperties.color = separation ? .systemGray4 : .secondaryLabel
            content.textProperties.alignment = .center

            if exifTitle?.accessibilityLabel == nil && exifTitle?.accessibilityValue == nil {
                cell.isAccessibilityElement = false
                cell.accessibilityElementsHidden = true
            } else {
                cell.isAccessibilityElement = true
                cell.accessibilityElementsHidden = false
                cell.accessibilityLabel = exifTitle?.accessibilityLabel
                cell.accessibilityValue = exifTitle?.accessibilityValue
            }
            cell.contentConfiguration = content
            cell.accessories = []
            cell.layoutMargins = separation ? .zero : .init(top: 0, left: 4, bottom: 0, right: 4)

            var backgroundConfig = cell.defaultBackgroundConfiguration()
            backgroundConfig.backgroundColor = .secondarySystemBackground
            cell.backgroundConfiguration = backgroundConfig

            cell.contentView.layoutMargins = .zero
        }

        dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: metadataCollectionView) { (collectionView: UICollectionView, indexPath: IndexPath, item: Int) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }

        if let layout = metadataCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionInset = .zero
        }

        metadataCollectionView.dataSource = dataSource
        metadataCollectionView.delegate = self
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

        let attributedValue = NSMutableAttributedString(string: name, attributes: [.accessibilitySpeechSpellOut: true])
        fileNameLabel.accessibilityAttributedValue = attributedValue

        let formattedDate = formatDate(metadata!.date)
        fileDateLabel.text = formattedDate
        fileDateLabel.accessibilityLabel = Strings.DetailFileDate
        fileDateLabel.accessibilityValue = formattedDate

        let type = metadata!.fileExtension.uppercased()
        typeLabel.text = type
        typeLabel.accessibilityLabel = Strings.DetailFileFormat
        typeLabel.accessibilityValue = type

        if metadata!.video {
            typeImageView.isHidden = false
            typeImageView.image = UIImage(systemName: "video")
            typeImageView.accessibilityLabel = Strings.DetailVideoTypeVideo
        } else if metadata!.livePhoto {
            typeImageView.isHidden = false
            typeImageView.image = UIImage(systemName: "livephoto")
            typeImageView.accessibilityLabel = Strings.DetailVideoTypeLive
        } else {
            typeImageView.isHidden = true
            typeImageView.image = nil
        }
    }

    func initDetails(metadata: Metadata, url: URL?) {
        self.metadata = metadata
        self.url = url
    }

    private func populateVideoDetails() {

        guard url != nil else {
            populateLocationFromMetadata(metadata!)
            return
        }

        if !popover {
            resetLabels()
        }

        layoutIfNeeded()

        let asset = AVAsset(url: url!)
        populateVideoDetail(metadata: metadata!, asset: asset)
        populateVideoMetadata(asset: asset)
    }

    private func populateImageDetails() {

        if !popover {
            resetLabels()
        }

        guard let metadata = self.metadata else { return }

        guard url != nil else {
            populateImageSizeInfoFromMetadata(metadata)
            populateLocationFromMetadata(metadata)
            populateExifFromMetadata(metadata)
            return
        }

        guard let originalSource = CGImageSourceCreateWithURL(url! as CFURL, nil),
              let fileProperties = CGImageSourceCopyProperties(originalSource, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) else {
            populateLocationFromMetadata(metadata)
            populateEmptyExif()
            return
        }

        let properties = NSMutableDictionary(dictionary: fileProperties)
        let imagePropertyDict = NSMutableDictionary(dictionary: imageProperties)

        populateImageSizeInfoFromProperties(pixelProperties: imagePropertyDict, sizeProperties: properties)
        populateImageLocationInfo(imageProperties: imagePropertyDict)

        var camera: String? = ""
        if let tiff = imagePropertyDict[kCGImagePropertyTIFFDictionary] as? [NSString: AnyObject] {
            camera = populateImageTiffInfo(tiff)
        }

        if let exif = imagePropertyDict[kCGImagePropertyExifDictionary] as? [NSString: AnyObject] {
            populateImageExifInfo(exif, camera)
        } else {
            setMakeModelText(Strings.DetailCameraNone)
            setLensText(Strings.DetailLensNone)
            populateEmptyExif()
        }
    }

    private func populateLocationFromMetadata(_ metadata: Metadata) {
        showLocation(latitudeValue: metadata.latitude, longitudeValue: metadata.longitude)
    }

    private func populateEmptyExif() {

        exifTitles.removeAll()

        exifTitles[0] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailISO, accessibilityValue: Strings.DetailNoValue)
        exifTitles[1] = ExifTitle(title: "|")
        exifTitles[2] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailFocalLength, accessibilityValue: Strings.DetailNoValue)
        exifTitles[3] = ExifTitle(title: "|")
        exifTitles[4] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailExposure, accessibilityValue: Strings.DetailNoValue)
        exifTitles[5] = ExifTitle(title: "|")
        exifTitles[6] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailAperture, accessibilityValue: Strings.DetailNoValue)
        exifTitles[7] = ExifTitle(title: "|")
        exifTitles[8] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailExposureTime, accessibilityValue: Strings.DetailNoValue)

        bind()
    }

    private func populateExifFromMetadata(_ metadata: Metadata) {

        populateEmptyExif()

        /*if let exifArray = metadata.exifPhotos {
            var dict: [NSString: AnyObject] = [:]
            for exif in exifArray {
                _ = exif.map { dict[$0.key as NSString] = $0.value as AnyObject }
            }

            //exif data doesn't appear to be standard yet. Commented out for now.
            //populateImageExifInfo(dict, nil)
        }*/
    }

    private func bind() {

        var snapshot = dataSource.snapshot()

        if snapshot.numberOfSections == 0 {
            snapshot.appendSections([0])
            snapshot.appendItems(exifTitles.keys.sorted(), toSection: 0)
        } else {
            snapshot.deleteAllItems()
            snapshot.appendSections([0])
            snapshot.appendItems(exifTitles.keys.sorted(), toSection: 0)
            snapshot.reloadSections([0])
        }

        dataSource.apply(snapshot, animatingDifferences: false, completion: { [weak self] in
            self?.resize()
        })
    }

    private func resize() {
        let height = metadataCollectionView.collectionViewLayout.collectionViewContentSize.height
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.metadataCollectionViewHeightConstraint.constant = height
        }, completion: { [weak self] _ in
            self?.delegate?.detailsLoaded()
        })
    }

    private func populateImageLocationInfo(imageProperties: NSMutableDictionary) {

        guard let gpsData = imageProperties[kCGImagePropertyGPSDictionary] as? [NSString: AnyObject] else {
            if metadata != nil {
                populateLocationFromMetadata(metadata!)
            }
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

    private func calculateLocationFromProperties(latitude: Double?, longitude: Double?, latitudeReference: String?, longitudeReference: String?) -> (latitude: Double?, longitude: Double?) {

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

    private func populateImageSizeInfoFromMetadata(_ metadata: Metadata) {
        populateImageSizeInfo(width: metadata.width, height: metadata.height, fileSize: metadata.size)
    }

    private func populateImageSizeInfoFromProperties(pixelProperties: NSMutableDictionary, sizeProperties: NSMutableDictionary) {

        var width: Double? = pixelProperties[kCGImagePropertyPixelWidth] as? Double
        var height: Double? = pixelProperties[kCGImagePropertyPixelHeight] as? Double

        if width == nil || height == nil {
            width = metadata!.width
            height = metadata!.height
        }

        let fileSize = sizeProperties[kCGImagePropertyFileSize] as? Int64

        populateImageSizeInfo(width: width, height: height, fileSize: fileSize)
    }

    private func populateImageSizeInfo(width: Double?, height: Double?, fileSize: Int64?) {

        var formattedPixels: String?
        var formattedMegaPixels: String?
        var formattedFileSize: String?

        if width == nil || height == nil || width == 0 || height == 0 {
            sizeLabel.text = Strings.DetailSizeNone
            sizeLabel.accessibilityValue = Strings.DetailSizeNone
        } else {

            let formattedWidth = String(format: "%.0f", width!)
            let formattedHeight = String(format: "%.0f", height!)

            formattedPixels = "\(formattedWidth) x \(formattedHeight)"

            formattedMegaPixels = formatMegaPixels(width: width!, height: height!)
        }

        if fileSize != nil {
            formattedFileSize = ByteCountFormatter.string(fromByteCount: fileSize!, countStyle: .file)
        } else if let size = metadata?.size, size > 0 {
            formattedFileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
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

        let sizeCategory = traitCollection.preferredContentSizeCategory

        exifTitles.removeAll()

        setLensText(lensText)

        if let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int] {
            if iso.isEmpty || iso.count == 0 {

            } else {
                let formattedISO = "\(Strings.DetailISO) \(iso[0].description)"
                exifTitles[0] = ExifTitle(title: formattedISO, accessibilityLabel: Strings.DetailISO, accessibilityValue: iso[0].description)
                exifTitles[1] = ExifTitle(title: "|")
            }
        }

        if let focalLength = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Int {

            let formattedFocalLength = "\(focalLength.description) mm"

            exifTitles[2] = ExifTitle(title: formattedFocalLength, accessibilityLabel: Strings.DetailFocalLength, accessibilityValue: formattedFocalLength)

            if sizeCategory <= .accessibilityLarge {
                exifTitles[3] = ExifTitle(title: "|")
            }
        }

        if let exposure = exif[kCGImagePropertyExifExposureBiasValue] as? Int {

            let formattedExposure = "\(exposure.description) ev"
            let accessibilityValue = "\(exposure.description) e v"

            exifTitles[4] = ExifTitle(title: formattedExposure, accessibilityLabel: Strings.DetailExposure, accessibilityValue: accessibilityValue)

            if sizeCategory <= .extraExtraLarge || sizeCategory > .accessibilityLarge {
                exifTitles[5] = ExifTitle(title: "|")
            }
        }

        if let apertureValue = exif[kCGImagePropertyExifFNumber] as? Double {

            let formattedApertureValue = apertureValue.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...2)))
            let formattedApertureValueTitle = "ƒ\(formattedApertureValue)"
            let accessibilityValue = "f \(formattedApertureValue)"

            exifTitles[6] = ExifTitle(title: formattedApertureValueTitle, accessibilityLabel: Strings.DetailAperture, accessibilityValue: accessibilityValue)

            if sizeCategory <= .accessibilityLarge {
                exifTitles[7] = ExifTitle(title: "|")
            }
        }

        if let exposureTimeValue = exif[kCGImagePropertyExifExposureTime] as? Double {

            let formattedExposureTime: String

            if exposureTimeValue >= 1 {
                formattedExposureTime = String(format: "%.0f", exposureTimeValue) + " s"
            } else {
                formattedExposureTime = "1/" + String(format: "%.0f", 1 / exposureTimeValue) + " s"
            }

            exifTitles[8] = ExifTitle(title: formattedExposureTime, accessibilityLabel: Strings.DetailExposureTime, accessibilityValue: formattedExposureTime)
        }

        let isEmpty = exifTitles.isEmpty

        if !exifTitles.keys.contains([0]) {
            exifTitles[0] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailISO, accessibilityValue: Strings.DetailNoValue)
            exifTitles[1] = ExifTitle(title: "|")
        }
        if !exifTitles.keys.contains([2]) {
            exifTitles[2] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailFocalLength, accessibilityValue: Strings.DetailNoValue)
            if isEmpty || sizeCategory <= .accessibilityLarge {
                exifTitles[3] = ExifTitle(title: "|")
            }
        }
        if !exifTitles.keys.contains([4]) {
            exifTitles[4] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailExposure, accessibilityValue: Strings.DetailNoValue)
            if isEmpty || sizeCategory <= .extraExtraLarge || sizeCategory > .accessibilityLarge {
                exifTitles[5] = ExifTitle(title: "|")
            }
        }

        if !exifTitles.keys.contains([6]) {
            exifTitles[6] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailAperture, accessibilityValue: Strings.DetailNoValue)
            if isEmpty || sizeCategory <= .accessibilityLarge {
                exifTitles[7] = ExifTitle(title: "|")
            }
        }
        if !exifTitles.keys.contains([8]) {
            exifTitles[8] = ExifTitle(title: "-", accessibilityLabel: Strings.DetailExposureTime, accessibilityValue: Strings.DetailNoValue)
        }

        bind()
    }

    private func populateVideoDetail(metadata: Metadata, asset: AVAsset) {

        exifTitles.removeAll()

        let videoLengthLabel = Strings.DetailVideoLength
        let videoSpeedLabel = Strings.DetailVideoSpeed

        Task.detached { [weak self] in

            let duration = try? await asset.load(.duration)

            let seconds = duration?.seconds
            var titles: [Int: ExifTitle] = [:]

            if seconds == nil || seconds! == 0 {
                titles[0] = ExifTitle(title: "-")
            } else {
                let duration = Duration.seconds(seconds!)
                let formatted = duration.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow))
                //let formatted = duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 1, fractionalSecondsLength: 0)))

                titles[0] = ExifTitle(title: formatted, accessibilityLabel: videoLengthLabel, accessibilityValue: formatted)
            }

            titles[1] = ExifTitle(title: "|")

            if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {

                let frameRate = try? await videoTrack.load(.nominalFrameRate)

                if frameRate != nil && frameRate! > 0 {
                    let displayFrameRate = Float(round(100 * frameRate!) / 100)
                    let formatted = "\(displayFrameRate) FPS"

                    titles[2] = ExifTitle(title: formatted, accessibilityLabel: videoSpeedLabel, accessibilityValue: formatted)
                }

                await self?.populateVideoSize(metadata: metadata, videoTrack: videoTrack)
            } else {
                titles[2] = ExifTitle(title: "-")
            }

            await MainActor.run { [weak self] in
                self?.exifTitles = titles
                self?.bind()
            }
        }
    }

    private func populateVideoMetadata(asset: AVAsset) {

        Task.detached { [weak self] in

            guard let track = try await asset.loadTracks(withMediaType: .video).first else { return }

            var lens: String?

            if #available(iOS 26, *),
               let metadata = try? await track.load(.metadata),
               let first = metadata.first(where: { $0.identifier == .quickTimeMetadataCameraLensModel }) {

                lens = try? await first.load(.stringValue)
            }

            await MainActor.run { [weak self] in
                self?.populateVideoLens(lens: lens)
            }

            if let descriptions = try? await track.load(.formatDescriptions), let desc = descriptions.first {

                var codec: String?
                let code = CMFormatDescriptionGetMediaSubType(desc)

                switch code {
                case kCMVideoCodecType_HEVC: codec = "HEVC"
                case kCMVideoCodecType_HEVCWithAlpha: codec = "HEVC"
                case kCMVideoCodecType_DolbyVisionHEVC: codec = "HEVC"
                case kCMVideoCodecType_H264: codec = "H.264"
                case kCMVideoCodecType_VP9: codec = "VP9"
                case kCMVideoCodecType_AV1: codec = "AV1"
                case kCMVideoCodecType_MPEG2Video: codec = "MPEG-2"
                case kCMVideoCodecType_MPEG4Video: codec = "MPEG-4"
                default:
                    let b3 = UInt8((code >> 24) & 0xFF)
                    let b2 = UInt8((code >> 16) & 0xFF)
                    let b1 = UInt8((code >> 8) & 0xFF)
                    let b0 = UInt8(code & 0xFF)
                    codec = String(bytes: [b3, b2, b1, b0], encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
                }

                if codec != nil && codec?.isEmpty == false {
                    await MainActor.run { [weak self] in
                        self?.typeLabel.text = codec
                        self?.typeLabel.accessibilityValue = codec
                    }
                }
            }
        }

        Task.detached { [weak self] in

            guard let avMetadataItems: [AVMetadataItem]? = try? await asset.load(.metadata) else { return }
            var make: String?
            var model: String?
            var location: CLLocation?

            for item in avMetadataItems! {

                guard let keyName = item.commonKey else { continue }

                switch keyName {
                case .commonKeyLocation:
                    location = await self?.parseLocation(item: item)
                case .quickTimeMetadataKeyMake:
                    make = try? await item.load(.stringValue)
                case .commonKeyMake:
                    make = try? await item.load(.stringValue)
                case .quickTimeMetadataKeyModel:
                    model = try? await item.load(.stringValue)
                case .commonKeyModel:
                    model = try? await item.load(.stringValue)
                default:
                    continue
                }
            }

            await MainActor.run { [weak self] in
                self?.populateVideoCameraMakeModel(make: make, model: model)
                self?.populateVideoLocation(location: location)
            }
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

    @concurrent private func populateVideoSize(metadata: Metadata, videoTrack: AVAssetTrack) async {

        var formattedFileSize: String?
        var rawSize = try? await videoTrack.load(.naturalSize).applying(videoTrack.load(.preferredTransform))

        if rawSize == nil {
            rawSize = CGSize(width: metadata.width, height: metadata.height)
        } else {
            rawSize = CGSize(width: abs(rawSize!.width), height: abs(rawSize!.height))
        }

        if metadata.size > 0 {
            formattedFileSize = ByteCountFormatter.string(fromByteCount: metadata.size, countStyle: .file)
        }

        if !hasText(formattedFileSize) && !hasSize(rawSize) {

        } else if hasText(formattedFileSize) && !hasSize(rawSize) {
            setFileSizeText(formattedFileSize!)
        } else if !hasText(formattedFileSize) && hasSize(rawSize) {
            let resolution = formatResolution(rawSize!.width, rawSize!.height)
            setFileSizeText("\(resolution) • \(abs(Int(rawSize!.width))) x \(abs(Int(rawSize!.height)))")
        } else {
            let resolution = formatResolution(rawSize!.width, rawSize!.height)
            setFileSizeText("\(resolution) • \(abs(Int(rawSize!.width))) x \(abs(Int(rawSize!.height))) • \(formattedFileSize!)")
        }
    }

    private func populateVideoLens(lens: String?) {
        let text = lens == nil || lens?.isEmpty == true ? Strings.DetailLensNone : lens
        setLensText(text!)
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

    private func populateVideoLocation(location: CLLocation?) {
        if let videoLocation = location {
            showLocation(latitudeValue: videoLocation.coordinate.latitude, longitudeValue: videoLocation.coordinate.longitude)
        } else {
            removeMap()
            delegate?.detailsLoaded()
        }
    }

    private func setMakeModelText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraLabel.text = text
            self?.cameraLabel.accessibilityLabel = Strings.DetailCameraDescription
            self?.cameraLabel.accessibilityValue = text
        }
    }

    private func setLensText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lensLabel.text = text
            self?.lensLabel.accessibilityLabel = Strings.DetailLensDescription
            self?.lensLabel.accessibilityValue = text
        }
    }

    nonisolated private func setFileSizeText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.sizeLabel.text = text
            self?.sizeLabel.accessibilityValue = text
        }
    }

    nonisolated private func hasText(_ value: String?) -> Bool {
        return value != nil && !value!.isEmpty
    }

    nonisolated private func hasSize(_ size: CGSize?) -> Bool {
        return size != nil && size!.width > 0 && size!.height > 0
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

    private func showLocation(latitudeValue: Double?, longitudeValue: Double?) {

        guard let latitude = latitudeValue, let longitude = longitudeValue, !(latitude == 0 && longitude == 0) else {
            removeMap()
            delegate?.detailsLoaded()
            return
        }

        createMap(latitude: latitude, longitude: longitude)
    }

    private func removeMap() {
        if let map = mapView {
            contentStackView.removeArrangedSubview(map)
            map.removeFromSuperview()
        }
        mapView = nil
    }

    private func createMap(latitude: Double, longitude: Double) {

        if mapView == nil {

            mapView = MKMapView()

            guard let mapView = self.mapView else {
                delegate?.detailsLoaded()
                return
            }

            mapView.isPitchEnabled = false
            mapView.isZoomEnabled = false
            mapView.isScrollEnabled = false

            mapView.translatesAutoresizingMaskIntoConstraints = false
            mapView.heightAnchor.constraint(equalToConstant: 140).isActive = true
            mapView.setContentCompressionResistancePriority(.required, for: .vertical)

            mapView.layer.cornerRadius = 8
            mapView.delegate = self
            mapView.setCameraZoomRange(.init(maxCenterCoordinateDistance: 500), animated: false)

            if contentStackView.arrangedSubviews.count == 4 {
                contentStackView.insertArrangedSubview(mapView, at: 2)
            }
        }

        Task.detached { [weak self] in

            await self?.addMapAnnotation(latitude: latitude, longitude: longitude)

            await MainActor.run { [weak self] in
                self?.delegate?.detailsLoaded()
            }
        }
    }

    @concurrent private func addMapAnnotation(latitude: Double, longitude: Double) async {

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

        await MainActor.run { [weak self] in
            if let annotations = self?.mapView?.annotations {
                self?.mapView?.removeAnnotations(annotations)
                self?.mapView?.setRegion(region, animated: false)
                self?.mapView?.addAnnotation(annotation)
            }
        }
    }

    private func getSizeForVideoAt(_ indexPath: IndexPath, _ collectionView: UICollectionView) -> CGSize {

        let sizeCategory = traitCollection.preferredContentSizeCategory
        let dividerWidth: CGFloat = 4.0
        var height: CGFloat = 30

        if sizeCategory > .extraExtraLarge {
            if sizeCategory > .accessibilityLarge {
                height = 60
            } else {
                height = 40
            }
        }

        guard indexPath.item < exifTitles.keys.count else { return CGSize(width: dividerWidth, height: height) }

        let keys = exifTitles.keys.sorted()
        let key = keys[indexPath.item]

        if !key.isMultiple(of: 2) {
            return CGSize(width: dividerWidth, height: height)
        }

        if collectionView.frame.width == 0 {
            return .zero
        } else {
            let width: CGFloat = floor((collectionView.frame.width - dividerWidth) / 2)
            let size = CGSize(width: width, height: height)
            return size
        }
    }

    private func getSizeForImageAt(_ indexPath: IndexPath, _ collectionView: UICollectionView) -> CGSize {

        let sizeCategory = traitCollection.preferredContentSizeCategory
        let dividerWidth: CGFloat = 4.0
        var divisor: CGFloat = 5.0
        var height: CGFloat = 30.0
        var dividers: CGFloat = 0

        if hasData() && sizeCategory > .extraExtraLarge {
            if sizeCategory > .accessibilityLarge {
                height = 60
                divisor = 2
                dividers = dividerWidth
            } else {
                height = 40
                divisor = 3
                dividers = dividerWidth * 2
            }
        } else {
            if sizeCategory > .extraExtraLarge {
                height = sizeCategory > .accessibilityLarge ? 60 : 40
            }
            dividers = dividerWidth * 4
        }

        guard indexPath.item < exifTitles.keys.count else { return  CGSize(width: dividerWidth, height: height) }

        let keys = exifTitles.keys.sorted()
        let key = keys[indexPath.item]

        if !key.isMultiple(of: 2) {
            return CGSize(width: dividerWidth, height: height)
        }

        if collectionView.frame.width == 0 {
            return .zero
        } else {
            let width: CGFloat = floor((collectionView.frame.width - dividers) / divisor)
            return CGSize(width: width, height: height)
        }
    }

    private func hasData() -> Bool {
        if exifTitles[0]?.title == "-" && exifTitles[2]?.title == "-" && exifTitles[4]?.title == "-"
            && exifTitles[6]?.title == "-" && exifTitles[8]?.title == "-" {
            return false
        } else {
            return true
        }
    }

    nonisolated private func formatMegaPixels(width: Double, height: Double) -> String {

        let megaPixels: Double = Double(width * height) / 1000000

        return megaPixels < 1 ? String(format: "%.1f MP", megaPixels) : "\(Int(megaPixels)) MP"
    }

    nonisolated private func formatResolution(_ width: CGFloat, _ height: CGFloat) -> String {

        let resolution: String
        let pixels = width * height

        switch pixels {
        case _ where pixels >= 33_177_600: //7680×4320 or higher
            resolution = "8K"
        case _ where pixels >= 8_294_400: //3840×2160
            resolution = "4K"
        case _ where pixels >= 3_686_400: //2560×1440
            resolution = "1440p"
        case _ where pixels >= 2_073_600: //1920×1080
            resolution = "1080p"
        case _ where pixels >= 921_600: //1280×720
            resolution = "720p"
        case _ where pixels >= 307_200: //640×480
            resolution = "480p"
        case _ where pixels >= 230_400: //640×360
            resolution = "360p"
        case _ where pixels >= 76_800: //320×240
            resolution = "240p"
        default:
            resolution = "120p"
        }

        return resolution
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

extension DetailView: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if metadata?.video == true {
            return getSizeForVideoAt(indexPath, collectionView)
        } else {
            return getSizeForImageAt(indexPath, collectionView)
        }
    }
}

nonisolated private class ExifTitle {

    var title: String?
    var accessibilityLabel: String?
    var accessibilityValue: String?

    init(title: String? = nil, accessibilityLabel: String? = nil, accessibilityValue: String? = nil) {
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }
}
