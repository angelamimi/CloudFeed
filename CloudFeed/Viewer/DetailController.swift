//
//  DetailController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
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

import UIKit
import os.log

class DetailController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var store: StoreUtility?
    
    //weak var metadata: tableMetadata?
    var metadata: Metadata?
    
    private var details = [MetadataDetail]()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailController.self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        
        tableView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        tableView.layer.cornerRadius = 8
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 70;
        
        buildDetailsDatasource()
    }
    
    private func buildDetailsDatasource() {
        
        guard let metadata = metadata else { return }
        
        appendDetails(metadata: metadata)
        
        if metadata.image && store != nil && store!.fileExists(metadata) {
            
            let imageSourceURL = URL(fileURLWithPath: store!.getCachePath(metadata.ocId, metadata.fileNameView)!)
            
            guard let originalSource = CGImageSourceCreateWithURL(imageSourceURL as CFURL, nil) else { return }
            guard let fileProperties = CGImageSourceCopyProperties(originalSource, nil) else { return }
            
            Task { [weak self] in
                guard let self = self else { return }
                let detailDict = await self.buildExif(originalSource: originalSource, fileProperties: fileProperties)
                //self.appendDetails()
                self.appendData(data: detailDict)
            }
        }
        
        Self.logger.debug("buildDetailsDatasource() - size: \(self.metadata!.size)")
    }
    
    private func buildExif(originalSource: CGImageSource, fileProperties: CFDictionary) async -> NSMutableDictionary {
        
        let details = NSMutableDictionary()
        let properties = NSMutableDictionary(dictionary: fileProperties)

        if let valFileSize = properties[kCGImagePropertyFileSize] {
            details[kCGImagePropertyFileSize] = valFileSize
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) else { return details }
        let imageDict = NSMutableDictionary(dictionary: imageProperties)
        
        if let width = imageDict[kCGImagePropertyPixelWidth], let height = imageDict[kCGImagePropertyPixelHeight] {
            details[kCGImagePropertyPixelWidth] = width
            details[kCGImagePropertyPixelHeight] = height
        }
        
        if let dpiWidth = imageDict[kCGImagePropertyDPIWidth], let dpiHeight = imageDict[kCGImagePropertyDPIHeight] {
            details[kCGImagePropertyDPIWidth] = dpiWidth
            details[kCGImagePropertyDPIHeight] = dpiHeight
        }
        
        if let colorModel = imageDict[kCGImagePropertyColorModel] {
            details[kCGImagePropertyColorModel] = colorModel
        }
        
        if let depth = imageDict[kCGImagePropertyDepth] {
            details[kCGImagePropertyDepth] = depth
        }
        
        if let profile = imageDict[kCGImagePropertyProfileName] {
            details[kCGImagePropertyProfileName] = profile
        }
        
        /*for (key, value) in imageDict {
            print(key)
        }*/
        
        if let exif = imageDict[kCGImagePropertyExifDictionary] as? [NSString: AnyObject] {
            
            /*for (key, value) in exif {
                print(key)
            }*/
            
            if let date = exif[kCGImagePropertyExifDateTimeOriginal] {
                details[kCGImagePropertyExifDateTimeOriginal] = date
            }
            
            if let lensMake = exif[kCGImagePropertyExifLensMake] {
                details[kCGImagePropertyExifLensMake] = lensMake
            }
            
            if let lensModel = exif[kCGImagePropertyExifLensModel] {
                details[kCGImagePropertyExifLensModel] = lensModel
            }
            
            if let aperture = exif[kCGImagePropertyExifFNumber] as? Double {
                details[kCGImagePropertyExifFNumber] = aperture
            }
            
            if let exposure = exif[kCGImagePropertyExifExposureBiasValue] as? Int {
                details[kCGImagePropertyExifExposureBiasValue] = exposure
            }
            
            if let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Int])?[0] {
                details[kCGImagePropertyExifISOSpeedRatings] = iso
            }
            
            if let brightness = exif[kCGImagePropertyExifBrightnessValue] as? Double {
                details[kCGImagePropertyExifBrightnessValue] = brightness
            }
        }
        
        return details
    }
    
    private func appendDetails(metadata: Metadata) {
        
        details.append(MetadataDetail(title: Strings.DetailName, detail: metadata.fileNameView))
        details.append(MetadataDetail(title: Strings.DetailEditedDate, detail: (metadata.date as Date).formatted(date: .abbreviated, time: .standard)))
                       
        if metadata.size > 0 {
            let sizeString = ByteCountFormatter.string(fromByteCount: metadata.size, countStyle: .file)
            details.append(MetadataDetail(title: Strings.DetailFileSize, detail: sizeString))
        }
        
        //Self.logger.debug("appendData() - date: \(self.metadata?.date)")
        //Self.logger.debug("appendData() - uploadDate: \(self.metadata?.uploadDate)")
        //Self.logger.debug("appendData() - creationDate: \(self.metadata?.creationDate)")
    }
    
    private func appendData(data: NSMutableDictionary) {
        
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
        
        /*if let rawFileSize = data[kCGImagePropertyFileSize] {
            if let fileSize = rawFileSize as? Int64 {
                let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                details.append(MetadataDetail(title: Strings.DetailFileSize, detail: fileSizeString))
            }
        }*/
        
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
            details.append(MetadataDetail(title: Strings.DetailLensMake, detail: lensMake as? String))
        }
        
        if let lensModel = data[kCGImagePropertyExifLensModel] {
            details.append(MetadataDetail(title: Strings.DetailLensModel, detail: lensModel as? String))
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
        
        if let shutterSpeed = data[kCGImagePropertyExifShutterSpeedValue] as? Double {
            let result = pow(2.0, shutterSpeed)
            details.append(MetadataDetail(title: Strings.DetailShutterSpeed, detail: "1/\(String(format: "%.0f", result))"))
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
