//
//  ViewerViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/11/23.
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

import AVFoundation
import AVKit
import NextcloudKit
import UIKit

@MainActor
struct ViewerViewModel {
    
    let metadata: Metadata
    let dataService: DataService
    
    init(dataService: DataService, metadata: Metadata) {
        self.metadata = metadata
        self.dataService = dataService
    }
    
    func isLivePhoto() async -> Bool {
        return await getMetadataLivePhoto(metadata: metadata) != nil
    }
    
    func getMetadataLivePhoto(metadata: Metadata) async -> Metadata? {
        return await dataService.getMetadataLivePhoto(metadata: metadata)
    }
    
    func getMetadataFromOcId(_ ocId: String) async -> Metadata? {
        return await dataService.getMetadataFromOcId(ocId)
    }
    
    func getVideoURL(metadata: Metadata) async -> URL? {

        if let url = await dataService.getDirectDownload(metadata: metadata) {
            return url
        }
        
        return nil
    }
    
    func previewExists(_ metadata: Metadata) -> Bool {
        return dataService.store.previewExists(metadata.ocId, metadata.etag)
    }
    
    func getPreviewPath(_ metadata: Metadata) -> String {
        return dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
    }
    
    func downloadPreview(_ metadata: Metadata) async {
        await dataService.downloadPreview(metadata: metadata)
    }
    
    func loadImage(metadata: Metadata) async -> UIImage? {
        
        if metadata.livePhoto {
            
            if let videoMetadata = await getMetadataLivePhoto(metadata: metadata), !dataService.store.fileExists(videoMetadata) {
                await downloadLivePhotoVideo(metadata: videoMetadata)
            }
            
        } else if metadata.svg {
            
            if !dataService.store.fileExists(metadata) {
                await dataService.download(metadata: metadata, progressHandler: { _, _ in })
            }
            
            let previewPath = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
            let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!
            
            await ImageUtility.loadSVGPreview(metadata: metadata, imagePath: imagePath, previewPath: previewPath)
            
        } else if metadata.gif {
            
            if !dataService.store.fileExists(metadata) {
                await dataService.download(metadata: metadata, progressHandler: { _, _ in })
            }
    
            let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!

            return await ImageUtility.loadGIF(metadata: metadata, imagePath: imagePath)
            
        } else {
            
            //check for full res image
            if dataService.store.fileExists(metadata) {
                let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!
                return autoreleasepool { () -> UIImage? in
                    return UIImage(contentsOfFile: imagePath)
                }
            }
            
            //check for preview image
            if !dataService.store.previewExists(metadata.ocId, metadata.etag) {
                await dataService.downloadPreview(metadata: metadata)
            }
        }
        
        if dataService.store.previewExists(metadata.ocId, metadata.etag) {
            let imagePreviewPath = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
            return autoreleasepool { () -> UIImage? in
                return UIImage(contentsOfFile: imagePreviewPath)
            }
        }
        
        return nil
    }
    
    func saveVideoPreview(metadata: Metadata, image: UIImage) {
        return dataService.saveVideoPreview(metadata: metadata, image: image)
    }
    
    func getVideoFrame(metadata: Metadata) -> UIImage? {
        return dataService.getVideoFrame(metadata: metadata)
    }
    
    func downloadVideoFrame(metadata: Metadata, url: URL, size: CGSize) async -> UIImage? {
        return await dataService.downloadVideoFrame(metadata: metadata, url: url, size: size)
    }
    
    func downloadLivePhotoVideo(metadata: Metadata) async {
        await dataService.download(metadata: metadata, progressHandler: { _, _ in })
    }
    
    func getFilePath(_ metadata: Metadata) -> String? {
        if dataService.store.fileExists(metadata) {
            return dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)
        } else if dataService.store.previewExists(metadata.ocId, metadata.etag) {
            return dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
        }
        return nil
    }
    
    func fileExists(_ metadata: Metadata) -> Bool {
        return dataService.store.fileExists(metadata)
    }
    
    func getVideoControlsStyleGlass() -> Bool {
        return dataService.getVideoControlsStyleGlass() ?? true
    }
}
