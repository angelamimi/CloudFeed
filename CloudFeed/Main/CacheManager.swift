//
//  CacheManager.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/2/24.
//

import UIKit
import os.log

@MainActor
final class CacheManager {
    
    private let dataService: DataService
    
    private let cache: NSCache<NSString, UIImage>
    /*private var cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        return cache
    }()*/
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CacheManager.self))
    
    init(dataService: DataService) {
        self.dataService = dataService
        
        cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300 //TODO: Very low limit
    }
    
    func clear() {
        cache.removeAllObjects()
    }
    
    func cache(metadata: Metadata, image: UIImage) {
        cache.setObject(image, forKey: (metadata.ocId + metadata.etag) as NSString)
    }
    
    func cached(ocId: String, etag: String) -> UIImage? {
        return cache.object(forKey: ocId + etag as NSString)
    }
    
    func fetch(metadata: Metadata, indexPath: IndexPath) async -> UIImage? {
        
        //Self.logger.debug("fetch() - downloading file: \(metadata.fileNameView)")
        
        if metadata.video {
            await self.dataService.downloadVideoPreview(metadata: metadata)
        } else if metadata.svg {
            await self.loadSVG(metadata: metadata)
        } else {
            await self.dataService.downloadPreview(metadata: metadata)
        }

        //Self.logger.debug("fetch() - downloading complete. file: \(metadata.fileNameView)")
        
        let path = dataService.store.getIconPath(metadata.ocId, metadata.etag)
        
        if FileManager().fileExists(atPath: path) {
            let image = UIImage(contentsOfFile: path)
            if image != nil { cache(metadata: metadata, image: image!) }
            return image
        }
         
        return nil
    }
    
    private func loadSVG(metadata: Metadata) async {
        
        if !dataService.store.fileExists(metadata) && metadata.image {
            
            await dataService.download(metadata: metadata, selector: "")
            
            let iconPath = dataService.store.getIconPath(metadata.ocId, metadata.etag)
            let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!
            
            ImageUtility.loadSVGPreview(metadata: metadata, imagePath: imagePath, previewPath: iconPath)
        }
    }
}
