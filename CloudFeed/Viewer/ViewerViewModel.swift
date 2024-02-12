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

final class ViewerViewModel {
    
    let metadata: tableMetadata
    let dataService: DataService
    
    init(dataService: DataService, metadata: tableMetadata) {
        self.metadata = metadata
        self.dataService = dataService
    }

    func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {
        return dataService.getMetadataLivePhoto(metadata: metadata)
    }
    
    func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        return dataService.getMetadataFromOcId(ocId)
    }
    
    func loadVideo(viewWidth: CGFloat, viewHeight: CGFloat) -> AVPlayerViewController? {
        
        let urlVideo = getVideoURL(metadata: metadata)
        
        if let url = urlVideo {
            return loadVideoFromUrl(url, viewWidth: viewWidth, viewHeight: viewHeight)
        }
        
        return nil
    }
    
    func loadVideoFromUrl(_ url: URL, viewWidth: CGFloat, viewHeight: CGFloat) -> AVPlayerViewController {

        let player = AVPlayer(url: url)
        let avpController = AVPlayerViewController()
        
        avpController.player = player
        avpController.view.backgroundColor = UIColor.systemBackground
        
        avpController.view.frame.size.height = viewHeight
        avpController.view.frame.size.width = viewWidth
        
        avpController.videoGravity = .resizeAspect
        
        avpController.showsPlaybackControls = true
        
        return avpController
    }
    
    func loadImage(metadata: tableMetadata, viewWidth: CGFloat, viewHeight: CGFloat) async -> UIImage? {
        
        if !StoreUtility.fileProviderStorageExists(metadata) && metadata.classFile == NKCommon.TypeClassFile.image.rawValue {

            if metadata.livePhoto, let videoMetadata = getMetadataLivePhoto(metadata: metadata) {
                await downloadLivePhotoVideo(metadata: videoMetadata)
            }
            
            await dataService.download(metadata: metadata, selector: "")
            
            let image = getImageFromMetadata(metadata, viewWidth: viewWidth, viewHeight: viewHeight)
            return image
        }
        
        // Get image
        let image = getImageFromMetadata(metadata, viewWidth: viewWidth, viewHeight: viewHeight)
        return image
    }
    
    func downloadLivePhotoVideo(metadata: tableMetadata) async {
        await dataService.download(metadata: metadata, selector: "")
    }
}

extension ViewerViewModel {
    
    private func getVideoURL(metadata: tableMetadata) -> URL? {
        
        if StoreUtility.fileProviderStorageExists(metadata) {
            return URL(fileURLWithPath: StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        } else {
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return HTTPCache.shared.getProxyURL(stringURL: stringURL)
        }
    }
    
    private func getImageFromMetadata(_ metadata: tableMetadata, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage? {
        
        if let image = getImage(metadata: metadata, viewWidth: viewWidth, viewHeight: viewHeight) {
            return image
        }
        
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue && !metadata.hasPreview {
            NextcloudUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
        }
        
        if StoreUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
            let imagePreviewPath = StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
            return UIImage(contentsOfFile: imagePreviewPath)
        }

        return nil
    }
    
    private func getImage(metadata: tableMetadata, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage? {
        
        var image: UIImage?
        
        if StoreUtility.fileProviderStorageExists(metadata) && metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
            
            let previewPath = StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
            let imagePath = StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            
            if metadata.gif {
                if !FileManager().fileExists(atPath: previewPath) {
                    NextcloudUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                }
                
                if let fileData = FileManager().contents(atPath: imagePath) {
                    image = UIImage.gifImageWithData(fileData)
                } else {
                    image = UIImage(contentsOfFile: imagePath)
                }
            } else if metadata.svg {
                
                return NextcloudUtility.shared.loadSVGPreview(metadata: metadata)
                
            } else {
                NextcloudUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                image = UIImage(contentsOfFile: imagePath)
                
                let imageWidth : CGFloat = image?.size.width ?? 0
                let imageHeight : CGFloat = image?.size.height ?? 0
                
                if image != nil && (imageWidth > viewWidth || imageHeight > viewHeight) {
                    
                    let filePath = StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    let fileData = FileManager().contents(atPath: filePath)
                    
                    if fileData != nil {
                        var newSize : CGSize?
                        if imageWidth > imageHeight {
                            newSize = CGSize(width: viewWidth, height: viewWidth)
                        } else {
                            newSize = CGSize(width: viewHeight, height: viewHeight)
                        }

                        return UIImage.downsample(imageData: (fileData! as CFData), to: newSize!)
                    }
                }
                    
                return image
            }
        }
        
        return image
    }
}
