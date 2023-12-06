//
//  DetailController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
//

import UIKit
import os.log

class DetailController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var closeButton: UIButton!
    
    weak var metadata : tableMetadata?
    private var details = [MetadataDetail]()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailController.self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Self.logger.debug("viewDidLoad()")
        
        tableView.dataSource = self
        
        tableView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        tableView.layer.cornerRadius = 8
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 70;
        
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        closeButton.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        closeButton.layer.cornerRadius = 8
        
        buildDetailsDatasource()
    }
    
    @objc func handleClose() {
        self.dismiss(animated: true)
    }
    
    private func buildDetailsDatasource() {
        guard metadata != nil else { return }
        StoreUtility.setExif(metadata!) { ( data ) in
            self.appendData(data: data)
        }
    }
    
    private func appendData(data: NSMutableDictionary) {
        guard metadata != nil else { return }
        details.append(MetadataDetail(title: Strings.DetailName, detail: metadata!.fileNameView))
        details.append(MetadataDetail(title: Strings.DetailEditedDate, detail: (metadata!.date as Date).formatted(date: .abbreviated, time: .standard)))
                       
        //Self.logger.debug("appendData() - date: \(self.metadata?.date)")
        //Self.logger.debug("appendData() - uploadDate: \(self.metadata?.uploadDate)")
        //Self.logger.debug("appendData() - creationDate: \(self.metadata?.creationDate)")
        
        if let dateTaken = data[kCGImagePropertyExifDateTimeOriginal] {
            if let dateString = dateTaken as? String {
                
                //Self.logger.debug("appendData() - date taken: \(dateString)")
                
                let dateFormatterGet = DateFormatter()
                dateFormatterGet.dateFormat = "yyyy:MM:dd:HH:mm:ss"
                
                if let date = dateFormatterGet.date(from: dateString) {
                    details.append(MetadataDetail(title: Strings.DetailCreatedDate, detail: date.formatted(date: .abbreviated, time: .standard)))
                } else {
                    Self.logger.error("Error decoding date taken string")
                }
            }
        }
        
        if let rawFileSize = data[kCGImagePropertyFileSize] {
            if let fileSize = rawFileSize as? Int64 {
                let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                details.append(MetadataDetail(title: Strings.DetailFileSize, detail: fileSizeString))
            }
        }
        
        if let width = data[kCGImagePropertyPixelWidth], let height = data[kCGImagePropertyPixelHeight] {
            details.append(MetadataDetail(title: Strings.DetailDimensions, detail: "\(width) x \(height)"))
        }
        
        if let dpiWidth = data[kCGImagePropertyDPIWidth], let dpiHeight = data[kCGImagePropertyDPIHeight] {
            details.append(MetadataDetail(title: Strings.DetailDPI, detail: "\(dpiWidth) x \(dpiHeight)"))
        }
        
        if let colorSpace = data[kCGImagePropertyColorModel] {
            details.append(MetadataDetail(title: Strings.DetailColorSpace, detail: colorSpace as? String))
        }
        
        if let depth = data[kCGImagePropertyDepth] {
            if depth is String {
                let depthString = depth as! String
                if depthString.count > 0 {
                    details.append(MetadataDetail(title: Strings.DetailDepth, detail: depthString))
                }
            }
        }
        
        if let profile = data[kCGImagePropertyProfileName] {
            details.append(MetadataDetail(title: Strings.DetailProfile, detail: profile as? String))
        }
        
        if let lensMake = data[kCGImagePropertyExifLensMake] {
            details.append(MetadataDetail(title: Strings.DetailLenseMake, detail: lensMake as? String))
        }
        
        if let lensModel = data[kCGImagePropertyExifLensModel] {
            details.append(MetadataDetail(title: Strings.DetailLenseModel, detail: lensModel as? String))
        }
        
        if let aperture = data[kCGImagePropertyExifFNumber] as? Double {
            details.append(MetadataDetail(title: Strings.DetailAperture, detail: "ƒ\(aperture.description)"))
        }
        
        if let exposure = data[kCGImagePropertyExifExposureBiasValue] as? Int {
            details.append(MetadataDetail(title: Strings.DetailExposure, detail: "\(exposure.description) ev"))
        }
        
        if let iso = data[kCGImagePropertyExifISOSpeedRatings] as? Int {
            details.append(MetadataDetail(title: Strings.DetailISO, detail: iso.description))
        }
        
        if let brightness = data[kCGImagePropertyExifBrightnessValue] as? Double {
            details.append(MetadataDetail(title: Strings.DetailBrightness, detail: String(format: "%.\(2)f", brightness)))
        }
    
        tableView?.reloadData()
    }
}

class MetadataDetail {
    var title : String?
    var detail : String?
    
    init(title: String? = nil, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }
}

extension DetailController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return details.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell") as! DetailCell

        cell.titleLabel?.text = details[indexPath.row].title
        cell.detailLabel?.text = details[indexPath.row].detail
        
        return cell
    }
}

extension DetailController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
