//
//  Global.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
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
    let limit: Int            = 1000
}
