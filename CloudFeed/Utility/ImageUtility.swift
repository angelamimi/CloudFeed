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
import SVGKit
import UIKit

class ImageUtility: NSObject {
    
    @discardableResult
    static func loadSVGPreview(metadata: tableMetadata, imagePath: String, previewPath: String) -> UIImage? {
        
        guard metadata.svg else { return nil }
        guard let svgImage = SVGKImage(contentsOfFile: imagePath) else { return nil }
        
        if let image = svgImage.uiImage {
            
            if !FileManager().fileExists(atPath: previewPath) {
                try? image.jpegData(compressionQuality: 1)?.write(to: URL(fileURLWithPath: previewPath))
            }
            
            return image
        }
        
        return nil
    }
    
    static func imageFromVideo(url: URL) async -> UIImage? {
        
        return await withCheckedContinuation { continuation in
            getThumbnailImageFromVideoUrl(url: url) { (thumbNailImage) in
                continuation.resume(returning: (thumbNailImage))
            }
        }
    }
    
    private static func getThumbnailImageFromVideoUrl(url: URL, completion: @escaping ((_ image: UIImage?)->Void)) {
            
        DispatchQueue.global(qos: .background).async {
            
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            let thumnailTime = CMTimeMake(value: 2, timescale: 1)
            
            imageGenerator.appliesPreferredTrackTransform = true
            
            autoreleasepool {
                do {
                    let cgThumbImage = try imageGenerator.copyCGImage(at: thumnailTime, actualTime: nil)
                    let thumbNailImage = UIImage(cgImage: cgThumbImage)
                    
                    completion(thumbNailImage)
                } catch {
                    completion(nil)
                }
            }
        }
    }
}
