//
//  Global.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import Foundation

class Global: NSObject {
    static let shared: Global = {
        let instance = Global()
        return instance
    }()
    
    let keyChain                      = "com.angelamimi.cloudfeed"
    let userAgent                     = "CloudFeed-iOS"
    
    // MARK: - Storage
    //
    let providerStorage               = "File Provider Storage"
    let groupIdentifier               = "group.com.angelamimi.cloudfeed"
    let databaseDirectory             = "Library/Application Support/CloudFeed"
    let databaseDefault               = "cloudfeed.realm"
    
    let databaseSchemaVersion: UInt64 = 1
    
    
    // MARK: - Capabilities
    //
    let capabilitiesVersionMajor: Array = ["ocs", "data", "version", "major"]
    
    
    // MARK: - Icon/Preview
    //
    let extensionPreview    = "ico"
    let sizePreview: Int    = 1024
    let sizeIcon: Int       = 512
    
    
    // MARK: - Metadata download status
    //
    // 1) wait download/upload
    // 2) in download/upload
    // 3) downloading/uploading
    // 4) done or error
    //
    let metadataStatusNormal: Int = 0
}
