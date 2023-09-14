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
        //imageFavorite.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        //imageFavorite.layer.cornerRadius = 10
        //imageFavorite.layer.masksToBounds = true
        Self.logger.debug("selected() - ?: \(status)")
        if status {
            imageFavorite.image = UIImage(systemName: "star")
        } else {
            imageFavorite.image = UIImage(systemName: "star.fill")
        }
    }
    
    func setImage(_ image: UIImage?) {
        imageView.image = image
    }
    
    private func initCell() {
        
        //Self.logger.debug("initCell() - reuseIdentifier: \(self.reuseIdentifier ?? "NONE") width: \(self.frame.width) height \(self.frame.height)")
        imageView.backgroundColor = .secondarySystemBackground
        imageStatus.image = nil
        imageView.image = nil
        imageFavorite.image = nil
        
        //Self.logger.debug("initCell()")
        
        if (self.reuseIdentifier == "MainCollectionViewCell") {
            imageFavorite.image = UIImage(systemName: "star.fill")
            imageFavorite.isHidden = true
        }
    }
}
