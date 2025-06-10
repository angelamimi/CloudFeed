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

final class Global: Sendable {
    
    static let shared = Global()
    
    let keyChain                      = "com.angelamimi.cloudfeed"
    let userAgent                     = "CloudFeed-iOS"
    
    // MARK: - Login
    //
    let minimumServerVersion          = 12
    
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
    let groupIdentifier               = "group.com.angelamimi.cloudfeed"
    let databaseDirectory             = "Library/Application Support/CloudFeed"
    
    let databaseSchemaVersion: UInt64 = 1
    
    
    // MARK: - Cache
    //
    let fileCacheLimit: UInt = 500 //megabytes
    
    
    // MARK: - Capabilities
    //
    let capabilitiesVersionMajor: Array = ["ocs", "data", "version", "major"]
    
    
    // MARK: - Layout
    //
    let layoutTypeSquare              = "layoutTypeSquare"
    let layoutTypeAspectRatio         = "layoutTypeAspectRatio"
    let layoutColumnCountDefaultPad   = 3
    let layoutColumnCountDefault      = 2
    
    
    // MARK: - Icon/Preview
    //
    let extensionPreview        = "jpeg"
    let sizePreview: Int        = 1024
    let sizeIcon: Int           = 512
    let avatarSizeBase: Int     = 128
    let avatarSizeRounded: Int  = 128
    
    
    // MARK: - Metadata download status
    //
    let metadataStatusNormal: Int = 0
    
    // MARK: - Error
    //
    let errorNotModified: Int    = 304
    let errorMaintenance: Int    = 503
    let errorConnectionLost: Int = -1005
    let errorTimeout: Int        = -1001
    let errorOffline: Int        = -1009
    
    // MARK: - Search
    //
    let pageSize: Int         = 200
    let limit: Int            = 200
    
    // MARK: - Title
    //
    let titleSize: CGFloat          = 50
    let titleSizeLarge: CGFloat     = 70
    
    // MARK: - Filter
    //
    enum FilterType {
        case image
        case video
        case all
    }
    
    // MARK: - Viewer
    //
    enum ViewerStatus: String {
        case fullscreen = "fullscreen"  //title hidden. details hidden.
        case details = "details"        //title hidden. details visible.
        case title = "title"            //title visible. details hidden.
    }
    
    // MARK: - Settings
    //
    enum SettingsMode {
        case all
        case account
        case display
        case information
        case data
    }
    
    // MARK: - File Types
    //
    enum FileType: String {
        case audio = "audio"
        case compress = "compress"
        case directory = "directory"
        case document = "document"
        case image = "image"
        case unknow = "unknow"
        case url = "url"
        case video = "video"
    }
}
