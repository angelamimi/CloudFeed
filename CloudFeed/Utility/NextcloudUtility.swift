//
//  NextcloudUtility.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/19/23.
//

import AVFoundation
import KTVHTTPCache
import NextcloudKit
import os.log
import SVGKit
import UIKit

class NextcloudUtility: NSObject {
    @objc static let shared: NextcloudUtility = {
        let instance = NextcloudUtility()
        return instance
    }()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: NextcloudUtility.self)
    )
    
    func createImageFrom(fileNameView: String, ocId: String, etag: String, classFile: String) {
        var originalImage, scaleImagePreview, scaleImageIcon: UIImage?

        let fileNamePath = StoreUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)!
        let fileNamePathPreview = StoreUtility.getDirectoryProviderStoragePreviewOcId(ocId, etag: etag)
        let fileNamePathIcon = StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)

        if StoreUtility.fileProviderStorageSize(ocId, fileNameView: fileNameView) > 0
            && FileManager().fileExists(atPath: fileNamePathPreview)
            && FileManager().fileExists(atPath: fileNamePathIcon) {
            return
        }
        
        if classFile != NKCommon.TypeClassFile.image.rawValue
            && classFile != NKCommon.TypeClassFile.video.rawValue {
            return
        }

        if classFile == NKCommon.TypeClassFile.image.rawValue {

            originalImage = UIImage(contentsOfFile: fileNamePath)

            scaleImagePreview = originalImage?.resizeImage(size: CGSize(width: Global.shared.sizePreview, height: Global.shared.sizePreview))
            scaleImageIcon = originalImage?.resizeImage(size: CGSize(width: Global.shared.sizeIcon, height: Global.shared.sizeIcon))

            try? scaleImagePreview?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? scaleImageIcon?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))

        } else if classFile == NKCommon.TypeClassFile.video.rawValue {

            let videoPath = NSTemporaryDirectory()+"tempvideo.mp4"
            
            //Self.logger.debug("createImageFrom() - videoPath: \(videoPath)")
            //Self.logger.debug("createImageFrom() - fileNamePath: \(fileNamePath)")
            
            FileSystemUtility.shared.linkItem(atPath: fileNamePath, toPath: videoPath)

            originalImage = imageFromVideo(url: URL(fileURLWithPath: videoPath), at: 0)

            try? originalImage?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathPreview))
            try? originalImage?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))
        }
    }

    func imageFromVideo(url: URL, at time: TimeInterval) -> UIImage? {
        
        let asset = AVAsset(url: url)
        let assetIG = AVAssetImageGenerator.init(asset: asset)
        
        assetIG.appliesPreferredTrackTransform = true
        assetIG.apertureMode = AVAssetImageGenerator.ApertureMode.encodedPixels
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 60)
        let thumbnailImageRef: CGImage
        do {
            thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
        } catch let error {
            Self.logger.error("imageFromVideo() - Error: \(error) url: \(url)")
            return nil
        }
        
        return UIImage(cgImage: thumbnailImageRef)
    }
    
    func loadImage(named imageName: String, color: UIColor = UIColor.gray, size: CGFloat = 50, symbolConfiguration: Any? = nil) -> UIImage? {

        var image: UIImage?

        // see https://stackoverflow.com/questions/71764255
        let sfSymbolName = imageName.replacingOccurrences(of: "_", with: ".")
        if let symbolConfiguration = symbolConfiguration {
            image = UIImage(systemName: sfSymbolName, withConfiguration: symbolConfiguration as? UIImage.Configuration)?.withTintColor(color, renderingMode: .alwaysOriginal)
        } else {
            image = UIImage(systemName: sfSymbolName)?.withTintColor(color, renderingMode: .alwaysOriginal)
        }

        return image
    }
    
    @discardableResult
    func loadSVGPreview(metadata: tableMetadata) -> UIImage? {
        
        guard metadata.svg else { return nil }

        let imagePath = StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let previewPath = StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        let iconPath = StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
        
        guard let svgImage = SVGKImage(contentsOfFile: imagePath) else { return nil }
        
        if let image = svgImage.uiImage {
            
            if !FileManager().fileExists(atPath: iconPath) {
                do {
                    try image.jpegData(compressionQuality: 0.5)?.write(to: URL(fileURLWithPath: iconPath))
                } catch { }
            }
            
            if !FileManager().fileExists(atPath: previewPath) {
                do {
                    try image.jpegData(compressionQuality: 1)?.write(to: URL(fileURLWithPath: previewPath))
                } catch { }
            }
            
            return image
        }
        
        return nil
    }
    
    private func scale(imageSize: CGSize, targetSize: CGSize) -> CGSize {
        
        // Compute the scaling ratio for the width and height separately
        let widthScaleRatio = targetSize.width / imageSize.width
        let heightScaleRatio = targetSize.height / imageSize.height

        // To keep the aspect ratio, scale by the smaller scaling ratio
        let scaleFactor = min(widthScaleRatio, heightScaleRatio)

        // Multiply the original image’s dimensions by the scale factor
        // to determine the scaled image size that preserves aspect ratio
        return CGSize(width: imageSize.width * scaleFactor, height: imageSize.height * scaleFactor)
    }

    func getUserBaseUrl(_ account: tableAccount) -> String {
        return account.user + "-" + (URL(string: account.urlBase)?.host ?? "")
    }
    
    func loadImage(named imageName: String, color: UIColor = UIColor.gray, size: CGFloat = 50, symbolConfiguration: Any? = nil) -> UIImage {

        var image: UIImage?

        if let symbolConfiguration = symbolConfiguration {
            image = UIImage(systemName: imageName, withConfiguration: symbolConfiguration as? UIImage.Configuration)?.withTintColor(color, renderingMode: .alwaysOriginal)
        } else {
            image = UIImage(systemName: imageName)?.withTintColor(color, renderingMode: .alwaysOriginal)
        }

        if image == nil {
            return UIImage(systemName: "rectangle.slash")!.image(color: color, size: size)
        } else {
            return image!
        }
    }
    
    func adjustSize(imageSize: CGSize?) -> CGSize {
        if imageSize != nil {
            let ratio = imageSize!.width < imageSize!.height ? imageSize!.width / imageSize!.height : imageSize!.height / imageSize!.width
            
            if ratio < 0.5 {
                //too tall or too wide. adjust size so full image is visible
                return imageSize!.width < imageSize!.height ? CGSize(width: 250, height: 400) : CGSize(width: 400, height: 250)
            } else {
                return imageSize!
            }
        }
        
        return CGSize(width: 0, height: 0)
    }
    
    func isLongImage(imageSize: CGSize) -> Bool {
        
        let ratio = imageSize.width < imageSize.height ? imageSize.width / imageSize.height : imageSize.height / imageSize.width
        return ratio < 0.5
    }
}
