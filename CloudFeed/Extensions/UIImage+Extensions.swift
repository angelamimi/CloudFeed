//
//  UIImage+Extensions.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/2/23.
//

import Foundation
import UIKit
import Accelerate

extension UIImage {

    /// Downsamles a image using ImageIO. Has better memory perfomance than redrawing using UIKit
    ///
    /// - [Source](https://swiftsenpai.com/development/reduce-uiimage-memory-footprint/)
    /// - [Original Source, WWDC18](https://developer.apple.com/videos/play/wwdc2018/416/?time=1352)
    /// - Parameters:
    ///   - imageURL: The URL path of the image
    ///   - pointSize: The target point size
    ///   - scale: The point to pixel scale (Pixeld per point)
    /// - Returns: The downsampled image, if successful
    static func downsample(imageAt imageURL: URL, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {

        // Create an CGImageSource that represent an image
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else { return nil }
        
        // Calculate the desired dimension
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale

        // Perform downsampling
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as [CFString : Any] as CFDictionary
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else { return nil }

        // Return the downsampled image as UIImage
        return UIImage(cgImage: downsampledImage)
    }
    
    static func downsample(imageData data: CFData, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        // Create an CGImageSource that represent an image
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data, imageSourceOptions) else { return nil }
                
        // Calculate the desired dimension
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale

        // Perform downsampling
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as [CFString : Any] as CFDictionary
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else { return nil }

        // Return the downsampled image as UIImage
        return UIImage(cgImage: downsampledImage)
    }
    
    func image(color: UIColor, size: CGFloat) -> UIImage {

        let size = CGSize(width: size, height: size)

        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        color.setFill()

        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0, y: size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.setBlendMode(CGBlendMode.normal)

        let rect = CGRect(origin: .zero, size: size)
        guard let cgImage = self.cgImage else { return self }
        context?.clip(to: rect, mask: cgImage)
        context?.fill(rect)

        let newImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()

        return newImage
    }
    
    func resizeImage(size: CGSize, isAspectRation: Bool = true) -> UIImage? {

        let originRatio = self.size.width / self.size.height
        let newRatio = size.width / size.height
        var newSize = size

        if isAspectRation {
            if originRatio < newRatio {
                newSize.height = size.height
                newSize.width = size.height * originRatio
            } else {
                newSize.width = size.width
                newSize.height = size.width / originRatio
            }
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let image = newImage {
            return image
        }
        return self
    }
}
