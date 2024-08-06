//
//  DetailView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 7/25/24.
//

import UIKit
import AVFoundation

class DetailView: UIView {
    
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
    
    weak var metadata: tableMetadata?
    var path: String?
    var url: URL?
    
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
    }
    
    private func loadViewFromNib() -> UIView? {
        let nib = UINib(nibName: "DetailView", bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
    
    func populateDetails() {
        
        print("populateDetails()")
        
        guard metadata != nil else { return }
        
        fileNameLabel.text = metadata!.fileNameView
        fileDateLabel.text = formatDate(metadata!.date as Date)
        
        if metadata!.video {
            populateVideoDetails()
        } else {
            populateImageDetails()
        }
    }
    
    private func populateVideoDetails() {

        guard url != nil else { return }
        
        //print("populateVideoDetails() - url: \(self.url!)")
        
        //let url = URL(string: path!)
        let asset = AVAsset(url: url!)
        
        Task {
        
            let duration = try? await asset.load(.duration)
            print("populateVideoDetails() - duration: \(duration?.seconds ?? 0)")
            
            if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
                
                let frameRate = try? await videoTrack.load(.nominalFrameRate)
                
                if frameRate != nil && frameRate! > 0 {
                    let displayFrameRate = Float(round(100 * frameRate!) / 100)
                    print("populateVideoDetails() - frameRate: \(frameRate ?? 0) displayFrameRate: \(displayFrameRate) FPS")
                }
                
                let size = try? await videoTrack.load(.naturalSize).applying(videoTrack.load(.preferredTransform))
                //let actualSize = CGSize(width: abs(size.width), height: abs(size.height))
                print("populateVideoDetails() - size: \(size?.debugDescription ?? "")")
                
                
                
                //let (naturalSize, formatDescriptions, mediaCharacteristics) = try? await videoTrack.load(.naturalSize, .formatDescriptions, .mediaCharacteristics)
                
                /*let formatDescriptions = try? await videoTrack.load(.formatDescriptions)
                
                if formatDescriptions != nil {
                    for descr in formatDescriptions! {
                        descr.
                    }
                }*/
                
            } else {
                print("populateVideoDetails() - no video tracks found")
            }
        }
        
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
            //print("No pixel info")
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
        
        if let lensMake = exif[kCGImagePropertyExifLensMake] as? String {
            print("lensMake: \(lensMake)")
        }
        
        if let lensModel = exif[kCGImagePropertyExifLensModel] as? String {
            print("lensModel: \(lensModel)")
        }
        
        if let lensSpecification = exif[kCGImagePropertyExifLensSpecification] as? String {
            print("lensSpecification: \(lensSpecification)")
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
    
    private func populateVideoMetadata(asset: AVAsset) {
        
        Task.detached { [weak self] in

            let avMetadataItems: [AVMetadataItem]? = try? await asset.load(.metadata)
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
            
            await self?.displayCameraMakeModel(make: make, model: model)
        }
    }
    
    private func displayCameraMakeModel(make: String?, model: String?) {
        
        var makeModel: String?
        print("displayCameraMakeModel() - camera make: \(make ?? "") model: \(model ?? "")")
        DispatchQueue.main.async {
            if model != nil && !model!.isEmpty {
                makeModel = model
                
                if make != nil && !make!.isEmpty {
                    makeModel = "\(make!) \(model!)"
                }
                
                //cameraMakeLabel.text = makeModel
            } else {
                //cameraMakeLabel.text = "No camera information"
            }
            
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

        formatter.dateFormat = "h:mm:ss a"
        let timeString = formatter.string(from: date)
        formattedDate.append(timeString)
        
        return formattedDate
    }
}
