//
//  Global.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import UIKit

class Global: NSObject {
    
    static let shared: Global = {
        let instance = Global()
        return instance
    }()
    
    let keyChain                      = "com.angelamimi.cloudfeed"
    let userAgent                     = "CloudFeed-iOS"
    
    // MARK: - Remote
    //
    let davLocation                   = "/remote.php/dav/files/"
    let loginLocation                 = "/index.php/login/flow"
    let prefix                        = "nc://"
    let urlValidation                 = "login"
    let http                          = "http://"
    let https                         = "https://"
    
    // MARK: - Storage
    //
    let providerStorage               = "File Provider Storage"
    let groupIdentifier               = "group.com.angelamimi.cloudfeed"
    let userDataDirectory             = "Library/Application Support/UserData"
    let databaseDirectory             = "Library/Application Support/CloudFeed"
    let databaseDefault               = "cloudfeed.realm"
    
    let databaseSchemaVersion: UInt64 = 1
    
    
    // MARK: - Capabilities
    //
    let capabilitiesVersionMajor: Array = ["ocs", "data", "version", "major"]
    
    
    // MARK: - Icon/Preview
    //
    let extensionPreview        = "jpeg"
    let sizePreview: Int        = 1024
    let sizeIcon: Int           = 512
    let avatarSize: Int         = 128 * Int(UIScreen.main.scale)
    let avatarSizeRounded: Int  = 128
    
    
    // MARK: - Metadata download status
    //
    let metadataStatusNormal: Int = 0
    
    
    // MARK: - Video
    //
    let maxHTTPCache: Int64 = 10000000000   // 10 GB
    
    // MARK: - Error
    //
    let errorNotModified: Int = 304
    
    // MARK: - Search
    //
    let pageSize: Int         = 200
    let metadataPageSize: Int = 1000
}
