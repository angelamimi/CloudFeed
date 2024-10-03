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
    //static func loadSVGPreview(metadata: tableMetadata, imagePath: String, previewPath: String) -> UIImage? {
    static func loadSVGPreview(metadata: Metadata, imagePath: String, previewPath: String) -> UIImage? {
        
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
    
    static func getPreviewSize(width: Int, height: Int) -> CGSize {
        
        var previewWidth = Double(Global.shared.sizePreview)
        var previewHeight = Double(Global.shared.sizePreview)
        
        guard width > 0 && height > 0 else {
            return CGSize(width: previewWidth, height: previewHeight)
        }

        let ratio: Double
        
        if width >= height {
            ratio = Double(width) / Double(height)
            previewHeight = previewWidth / ratio
        } else {
            ratio = Double(height) / Double(width)
            previewWidth = previewHeight / ratio
        }
        
        return CGSize(width: previewWidth, height: previewHeight)
    }
    
    static func imageFromVideo(url: URL, size: CGSize) async -> UIImage? {
        
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        let time = CMTimeMake(value: 2, timescale: 1)
        
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size

        //let cgImage = try? await generator.image(at: .zero).image
        let cgImage = try? await generator.image(at: time).image
        
        if cgImage == nil {
            return nil
        } else {
            return UIImage(cgImage: cgImage!)
        }
    }
    
    /*static func imageFromVideo(url: URL, size: CGSize) async -> UIImage? {
        
        return await withCheckedContinuation { continuation in
            getThumbnailImageFromVideoUrl(url: url, size: size) { (thumbNailImage) in
                continuation.resume(returning: (thumbNailImage))
            }
        }
    }
    
    private static func getThumbnailImageFromVideoUrl(url: URL, size: CGSize, completion: @escaping ((_ image: UIImage?) -> Void)) {
            
        DispatchQueue.global(qos: .background).async {
            
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            let thumnailTime = CMTimeMake(value: 2, timescale: 1)

            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = size
            
            do {
                let cgThumbImage = try imageGenerator.copyCGImage(at: thumnailTime, actualTime: nil)
                let thumbNailImage = UIImage(cgImage: cgThumbImage)
                
                completion(thumbNailImage)
            } catch {
                completion(nil)
            }
        }
    }*/
}
