//
//  HttpCache.swift
//  CloudFeed
//
//  Created by Marino Faggiana on 28/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import KTVHTTPCache

@MainActor
class HTTPCache: NSObject {
    
    @objc static let shared: HTTPCache = {
        let instance = HTTPCache()
        instance.setupHTTPCache()
        return instance
    }()
    
    func deleteAllCache() {

        KTVHTTPCache.cacheDeleteAllCaches()
    }
    
    func getProxyURL(url: URL) -> URL {

        return KTVHTTPCache.proxyURL(withOriginalURL: url)
    }
    
    func getProxyURL(stringURL: String) -> URL {

        return KTVHTTPCache.proxyURL(withOriginalURL: URL(string: stringURL))
    }

    private func setupHTTPCache() {

        KTVHTTPCache.cacheSetMaxCacheLength(Global.shared.maxHTTPCache)

        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            KTVHTTPCache.logSetConsoleLogEnable(false)
        }

        do {
            try KTVHTTPCache.proxyStart()
        } catch let error {
            print("Proxy Start error : \(error)")
        }

        KTVHTTPCache.encodeSetURLConverter { url -> URL? in
            //print("URL Filter received URL : " + String(describing: url))
            return url
        }

        KTVHTTPCache.downloadSetUnacceptableContentTypeDisposer { url, contentType -> Bool in
            print("Unsupport Content-Type Filter received URL : " + String(describing: url) + " " + String(describing: contentType))
            return false
        }
    }
}

