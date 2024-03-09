//
//  CacheManager.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/2/24.
//

import UIKit
import os.log

class CacheManager {
    
    private let dispatchQueue = DispatchQueue(label: "downloads")
    private var downloads: [IndexPath: Operation] = [:]
        
    private var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "downloadQueue"
        queue.maxConcurrentOperationCount = 5
        return queue
    }()
    
    private var cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        return cache
    }()
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: CacheManager.self))
    
    func suspend() {
        queue.isSuspended = true
    }
    
    func resume() {
        queue.isSuspended = false
    }
    
    func dump() {
        dispatchQueue.sync {
            let count = downloads.count
            Self.logger.debug("dump() - current count: \(count)")

            for dl in downloads {
                let op = dl.value as Operation
                let key = dl.key as IndexPath
                Self.logger.debug("dump() - indexPath: \(key) isReady: \(op.isReady) isExecuting: \(op.isExecuting)")
            }
        }
    }
    
    func cached(metadataId: String) -> UIImage? {
        return cache.object(forKey: metadataId as NSString)
    }
    
    func fetch(metadata: tableMetadata, indexPath: IndexPath, completion: ((UIImage?) -> Void)? = nil) {
        
        Self.logger.debug("fetch() - beginning for \(indexPath) and id: \(metadata.ocId) suspended? \(self.queue.isSuspended)")
        
        /*if let cachedImage = cache.object(forKey: metadata.metadataId as NSString) {
            Self.logger.debug("fetch() - found image in cache. return. id: \(metadata.metadataId)")
            completion?(cachedImage)
            return
        }*/
        
        /*guard !queue.isSuspended else {
            Self.logger.debug("fetch() - operations suspended. return. id: \(metadata.ocId)")
            completion?(nil)
            return
        }*/
        
        guard let completion = completion else {
            return
        }

        var downloadOperation: Operation?
        
        dispatchQueue.sync {
            downloadOperation = downloads[indexPath]
        }
        
        guard downloadOperation == nil else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        /*guard let url = URL(string: metadata.metadataUrl) else {
            Self.logger.debug("fetch() - invalid url. return. id: \(metadata.metadataId)")
            completion?(nil)
            return
        }
        
        Self.logger.debug("fetch() - execute operation \(metadata.metadataId) url: \(metadata.metadataUrl)")
        
        let operation = ImageDownloadOperation(metadata.metadataId, url: url) { [weak self] (image: UIImage?) in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    Self.logger.debug("fetch() - can't download. return. id: \(metadata.metadataId)")
                    completion?(nil)
                    return
                }
                
                if image == nil {
                    Self.logger.debug("fetch() - download failed. return. id: \(metadata.metadataId)")
                    dispatchQueue.async {
                        self.downloads.removeValue(forKey: indexPath)
                    }
                    completion?(nil)
                    return
                }
                
                Self.logger.debug("fetch() - download successful. caching. id: \(metadata.metadataId)")
                
                self.cache.setObject(image!, forKey: metadata.metadataId as NSString)
                
                dispatchQueue.async {
                    self.downloads.removeValue(forKey: indexPath)
                }
                completion?(image)
            }
        }
        
        dispatchQueue.async {
            Self.logger.debug("fetch() - adding operation to downloads. id: \(metadata.ocId)")
            self.downloads[indexPath] = operation
        }
        
        dispatchQueue.sync {
            let count = downloads.count
            Self.logger.debug("fetch() - adding operation to queue. id: \(metadata.ocId) current count: \(count)")
        }
        
        queue.addOperation(operation)*/
    }
    
    func cancel(_ indexPath: IndexPath) {
        
        dispatchQueue.sync {
            downloads[indexPath]?.cancel()
        }
 
        dispatchQueue.async {
            self.downloads.removeValue(forKey: indexPath)
        }
    }
}

