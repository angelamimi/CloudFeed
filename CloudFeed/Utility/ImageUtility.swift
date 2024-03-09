//
//  ImageUtility.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/7/24.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
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
import KTVHTTPCache
import SVGKit
import UIKit

class ImageUtility: NSObject {
    
    static func imageFromVideo(url: URL, at time: TimeInterval) -> UIImage? {
        
        let asset = AVAsset(url: url)
        let assetIG = AVAssetImageGenerator.init(asset: asset)
        
        assetIG.appliesPreferredTrackTransform = true
        assetIG.apertureMode = AVAssetImageGenerator.ApertureMode.encodedPixels
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 60)
        let thumbnailImageRef: CGImage
        do {
            thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
        } catch {
            return nil
        }
        
        return UIImage(cgImage: thumbnailImageRef)
    }
    
    @discardableResult
    static func loadSVGPreview(metadata: tableMetadata, imagePath: String, previewPath: String) -> UIImage? {
        
        guard metadata.svg else { return nil }
        guard let svgImage = SVGKImage(contentsOfFile: imagePath) else { return nil }
        
        if let image = svgImage.uiImage {
            
            if !FileManager().fileExists(atPath: previewPath) {
                do {
                    try image.jpegData(compressionQuality: 1)?.write(to: URL(fileURLWithPath: previewPath))
                } catch { }
            }
            
            return image
        }
        
        return nil
    }
}
