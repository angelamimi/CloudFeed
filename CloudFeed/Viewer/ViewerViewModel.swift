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
    
    func loadImage(metadata: Metadata, viewWidth: CGFloat, viewHeight: CGFloat) async -> UIImage? {

        if !dataService.store.fileExists(metadata) {

            if metadata.livePhoto, let videoMetadata = await getMetadataLivePhoto(metadata: metadata) {
                await downloadLivePhotoVideo(metadata: videoMetadata)
            }
            
            
            await dataService.download(metadata: metadata, progressHandler: { _, _ in })
        }
        
        return await getImageFromMetadata(metadata, viewWidth: viewWidth, viewHeight: viewHeight)
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
        guard dataService.store.fileExists(metadata) else { return nil }
        return dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)
    }
    
    func fileExists(_ metadata: Metadata) -> Bool {
        return dataService.store.fileExists(metadata)
    }
}

extension ViewerViewModel {
    
    private func getImageFromMetadata(_ metadata: Metadata, viewWidth: CGFloat, viewHeight: CGFloat) async -> UIImage? {
        
        if let image = await getImage(metadata: metadata, viewWidth: viewWidth, viewHeight: viewHeight) {
            return image
        }
        
        if dataService.store.previewExists(metadata.ocId, metadata.etag) {
            let imagePreviewPath = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
            return UIImage(contentsOfFile: imagePreviewPath)
        }

        return nil
    }
    
    private func getImage(metadata: Metadata, viewWidth: CGFloat, viewHeight: CGFloat) async -> UIImage? {
        
        var image: UIImage?
        
        guard dataService.store.fileExists(metadata) && metadata.classFile == NKTypeClassFile.image.rawValue else { return nil }
            
        let previewPath = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
        let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!
        
        if metadata.gif {
            
            if !FileManager().fileExists(atPath: previewPath) {
                await createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
            }
            
            if let fileData = FileManager().contents(atPath: imagePath) {
                image = UIImage.gifImageWithData(fileData)
            } else {
                image = UIImage(contentsOfFile: imagePath)
            }
            
        } else if metadata.svg {
            
            return await ImageUtility.loadSVGPreview(metadata: metadata, imagePath: imagePath, previewPath: previewPath)
            
        } else {

            await createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
            image = UIImage(contentsOfFile: imagePath)
            
            /*let imageWidth : CGFloat = image?.size.width ?? 0
            let imageHeight : CGFloat = image?.size.height ?? 0
            
            if image != nil && (imageWidth > viewWidth || imageHeight > viewHeight) {
                
                let filePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!
                let fileData = FileManager().contents(atPath: filePath)
                
                if fileData != nil {
                    var newSize : CGSize?
                    if imageWidth > imageHeight {
                        newSize = CGSize(width: viewWidth, height: viewWidth)
                    } else {
                        newSize = CGSize(width: viewHeight, height: viewHeight)
                    }

                    return UIImage.downsample(imageData: (fileData! as CFData), to: newSize!, scale: UIScreen.main.scale)
                }
            }*/
                
            return image
        }
        
        return image
    }
    
    private func createImageFrom(fileNameView: String, ocId: String, etag: String, classFile: String) async {
        
        guard classFile == NKTypeClassFile.image.rawValue else { return }
        
        var originalImage, scaleImagePreview: UIImage?

        let fileNamePath = dataService.store.getCachePath(ocId, fileNameView)!
        let fileNamePathPreview = dataService.store.getPreviewPath(ocId, etag)

        if dataService.store.fileSize(ocId, fileNameView) > 0 && FileManager().fileExists(atPath: fileNamePathPreview) {
            return
        }
        
        originalImage = UIImage(contentsOfFile: fileNamePath)

        scaleImagePreview = await originalImage?.byPreparingThumbnail(ofSize: CGSize(width: Global.shared.sizePreview, height: Global.shared.sizePreview))

        try? scaleImagePreview?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
    }
}
