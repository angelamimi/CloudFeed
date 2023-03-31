//
//  NextcloudUtility.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/19/23.
//

import Foundation


import NextcloudKit
import UIKit
import AVFoundation
import KTVHTTPCache
import os.log

class NextcloudUtility: NSObject {
    @objc static let shared: NextcloudUtility = {
        let instance = NextcloudUtility()
        return instance
    }()
    
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
            //Self.logger.error("imageFromVideo() - Error: \(error) url: \(url)")
            return nil
        }
        
        return UIImage(cgImage: thumbnailImageRef)
    }
}
