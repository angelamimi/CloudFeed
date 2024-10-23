//
//  CacheManager.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/2/24.
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

@MainActor
final class CacheManager {
    
    private let dataService: DataService
    private let cache: NSCache<NSString, UIImage>
    private let queue: OperationQueue
        
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CacheManager.self))
    
    init(dataService: DataService) {
        self.dataService = dataService
        
        cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        
        queue = OperationQueue()
        queue.name = "downloadQueue"
        queue.maxConcurrentOperationCount = 5
        queue.qualityOfService = .background
    }
    
    func clear() {
        cache.removeAllObjects()
    }
    
    func cancelAll() {
        queue.cancelAllOperations()
    }
    
    func cache(metadata: Metadata, image: UIImage) {
        cache.setObject(image, forKey: (metadata.ocId + metadata.etag) as NSString)
    }
    
    func cached(ocId: String, etag: String) -> UIImage? {
        return cache.object(forKey: ocId + etag as NSString)
    }
    
    func fetch(metadata: Metadata, delegate: DownloadOperationDelegate) {
        let operation = DownloadOperation(metadata, dataService: dataService, delegate: delegate)
        queue.addOperation(operation)
    }
}
