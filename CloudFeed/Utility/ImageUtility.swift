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

final class ImageUtility: NSObject {
    
    static func saveImageAtPaths(data: Data, previewPath: String, iconPath: String) {

        autoreleasepool {
            
            guard let image = UIImage(data: data) else { return }
            
            if let previewImage = image.preparingThumbnail(of: CGSize(width: Global.shared.sizePreview, height: Global.shared.sizePreview)),
               let data = previewImage.jpegData(compressionQuality: 0.5) {
                do {
                    try data.write(to: URL(fileURLWithPath: previewPath))
                } catch {
                    
                }
            }
            
            if let iconImage = image.preparingThumbnail(of: CGSize(width: Global.shared.sizeIcon, height: Global.shared.sizeIcon)),
               let data = iconImage.jpegData(compressionQuality: 0.7) {
                do {
                    try data.write(to: URL(fileURLWithPath: iconPath))
                } catch {
                    
                }
            }
        }
    }
    
    @discardableResult
    static func loadSVGPreview(metadata: Metadata, imagePath: String, previewPath: String) async -> UIImage? {
        
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
    
    static func imageFromVideo(url: URL, size: CGSize) async -> UIImage? {
        
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        let time = CMTimeMake(value: 2, timescale: 1)
        
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size

        let cgImage = try? await generator.image(at: time).image
        
        if cgImage == nil {
            return nil
        } else {
            return autoreleasepool { () -> UIImage? in
                return UIImage(cgImage: cgImage!)
            }
        }
    }
}
