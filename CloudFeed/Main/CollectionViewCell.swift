//
//  CollectionViewCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/17/23.
//

import os.log
import UIKit

class CollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CollectionViewCell.self)
    )
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initCell()
    }
    
    override func prepareForReuse() {
        imageView.image = nil
        initCell()
    }
    
    func resetStatusIcon() {
        imageStatus.image = nil
    }
    
    func showVideoIcon() {
        imageStatus.image = UIImage(systemName: "video.fill")
    }
    
    func showLivePhotoIcon() {
        imageStatus.image = UIImage(systemName: "livephoto")
    }
    
    func showFavorite() {
        imageFavorite.isHidden = false
    }
    
    func selectMode(_ status: Bool) {
        if status {
            imageFavorite.isHidden = false
        } else {
            imageFavorite.isHidden = true
        }
    }
    
    func selected(_ status: Bool) {
        if status {
            imageFavorite.image = UIImage(systemName: "star")
        } else {
            imageFavorite.image = UIImage(systemName: "star.fill")
        }
    }
    
    func setImage(_ image: UIImage?) {
        imageView.image = image
    }
    
    func setContentMode(isLongImage: Bool) {
        if isLongImage {
            imageView.contentMode = .scaleAspectFit
        } else {
            imageView.contentMode = .scaleAspectFill
        }
    }
    
    private func initCell() {
        
        imageStatus.image = nil
        imageView.image = nil
        imageFavorite.image = nil
        
        if (self.reuseIdentifier == "MainCollectionViewCell") {
            imageFavorite.image = UIImage(systemName: "star.fill")
            imageFavorite.isHidden = true
        }
    }
}
