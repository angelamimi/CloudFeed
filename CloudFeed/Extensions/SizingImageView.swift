//
//  SizingImageView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/20/26.
//

import UIKit

class SizingImageView: UIImageView {

    override var intrinsicContentSize: CGSize {

        guard let image = self.image else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }

        let imageWidth = image.size.width
        let imageHeight = image.size.height
        let viewWidth = frame.size.width

        let ratio = viewWidth / imageWidth
        let scaledHeight = imageHeight * ratio

        return CGSize(width: viewWidth, height: scaledHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        invalidateIntrinsicContentSize()
    }
}
