//
//  NextcloudService.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/13/23.
//

import Alamofire
import UIKit
import NextcloudKit
import os.log

class NextcloudService: NSObject {
    
    static let shared: NextcloudService = {
        let instance = NextcloudService()
        return instance
    }()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: NextcloudService.self)
    )
}
     
