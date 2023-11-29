//
//  ViewerViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/11/23.
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
    
    func getMetadata(account: String, serverUrl: String, fileName: String) -> tableMetadata? {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", account, serverUrl, fileName)
        return dataService.getMetadata(predicate: predicate)
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
            
            if metadata.livePhoto {
                let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
                await downloadLivePhotoVideo(fileName: fileName, metadata: metadata)
            }
            
            await dataService.download(metadata: metadata, selector: "")
            
            let image = getImageFromMetadata(metadata, viewWidth: viewWidth, viewHeight: viewHeight)
            return image
        }
        
        // Get image
        let image = getImageFromMetadata(metadata, viewWidth: viewWidth, viewHeight: viewHeight)
        return image
    }
    
    func downloadLivePhotoVideo(fileName: String, metadata: tableMetadata) async {
        
        if let metadata = dataService.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", 
                                                                         metadata.account, metadata.serverUrl, fileName)), !StoreUtility.fileProviderStorageExists(metadata) {

            await dataService.download(metadata: metadata, selector: "")
        }
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
        
        //TODO: Show generic image by type if missing a preview image
        /*if metadata.classFile == NKCommon.typeClassFile.video.rawValue {
        } else if metadata.classFile == NKCommon.typeClassFile.audio.rawValue {
        } else {
        }*/
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
                    
                    //TODO: Large images spike memory. Have to downsample in some way.
                    let filePath = StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    let fileData = FileManager().contents(atPath: filePath)
                    
                    if fileData != nil {
                        var newSize : CGSize?
                        if imageWidth > imageHeight {
                            newSize = CGSize(width: viewWidth, height: viewWidth)
                        } else {
                            newSize = CGSize(width: viewHeight, height: viewHeight)
                        }
                        //Self.logger.debug("downsample!!!!!!!!!!")
                        return UIImage.downsample(imageData: (fileData! as CFData), to: newSize!)
                    }
                }
                    
                return image
            }
        }
        
        return image
    }
}
