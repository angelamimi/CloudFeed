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
        
        print("populateVideoDetails() - url: \(self.url!)")
        
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
        
        //guard path != nil else { return }
        
        //let imageSourceURL = URL(fileURLWithPath: path!)
        
        guard url != nil else { return }
        
        guard let originalSource = CGImageSourceCreateWithURL(url! as CFURL, nil) else { return }
        guard let fileProperties = CGImageSourceCopyProperties(originalSource, nil) else { return }
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
