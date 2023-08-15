//
//  DetailController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
//

import UIKit
import os.log

class DetailController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var closeButton: UIButton?
    
    //var metadata : tableMetadata = tableMetadata()
    weak var metadata : tableMetadata?
    private var details = [MetadataDetail]()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailController.self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Self.logger.debug("viewDidLoad()")
        
        tableView?.dataSource = self
        
        tableView?.layer.cornerRadius = 5
        tableView?.layer.masksToBounds = true

        closeButton?.layer.cornerRadius = 10
        closeButton?.layer.masksToBounds = true
        
        closeButton?.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        
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
        details.append(MetadataDetail(title: "Name", detail: metadata!.fileNameView))
        details.append(MetadataDetail(title: "Date", detail: (metadata!.date as Date).formatted(date: .abbreviated, time: .standard)))
                       
        //Self.logger.debug("appendData() - date: \(self.metadata?.date)")
        //Self.logger.debug("appendData() - uploadDate: \(self.metadata?.uploadDate)")
        //Self.logger.debug("appendData() - creationDate: \(self.metadata?.creationDate)")
        
        if let dateTaken = data[kCGImagePropertyExifDateTimeOriginal] {
            if let dateString = dateTaken as? String {
                
                //Self.logger.debug("appendData() - date taken: \(dateString)")
                
                let dateFormatterGet = DateFormatter()
                dateFormatterGet.dateFormat = "yyyy:MM:dd:HH:mm:ss"
                
                if let date = dateFormatterGet.date(from: dateString) {
                    details.append(MetadataDetail(title: "Date", detail: date.formatted(date: .abbreviated, time: .standard)))
                } else {
                    Self.logger.error("Error decoding date taken string")
                }
            }
        }
        
        if let rawFileSize = data[kCGImagePropertyFileSize] {
            if let fileSize = rawFileSize as? Int64 {
                let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                details.append(MetadataDetail(title: "File Size", detail: fileSizeString))
            }
        }
        
        if let width = data[kCGImagePropertyPixelWidth], let height = data[kCGImagePropertyPixelHeight] {
            details.append(MetadataDetail(title: "Size", detail: "\(width) x \(height)"))
        }
        
        if let lensModel = data[kCGImagePropertyExifLensModel] {
            details.append(MetadataDetail(title: "Lense Model", detail: lensModel as? String))
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

extension DetailController : UITableViewDataSource {
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

