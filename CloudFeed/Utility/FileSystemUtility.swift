//
//  FileSystemUtility.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/18/23.
//

import UIKit
import PhotosUI
import os.log

class FileSystemUtility: NSObject {
    @objc static let shared: FileSystemUtility = {
        let instance = FileSystemUtility()
        return instance
    }()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FileSystemUtility.self)
    )
    
    let fileManager = FileManager.default
    
    func getDirectorySize(directory: String) -> Int64 {
        
        Self.logger.debug("getDirectorySize() - directory: \(directory)")

        let url = URL(fileURLWithPath: directory)
        let manager = FileManager.default
        var totalSize: Int64 = 0

        if let enumerator = manager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? manager.attributesOfItem(atPath: fileURL.path) {
                    if let size = attributes[.size] as? Int64 {
                        totalSize += size
                    }
                }
            }
        }

        return totalSize
    }
    
}
