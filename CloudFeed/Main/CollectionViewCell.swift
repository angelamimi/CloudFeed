//
//  CollectionViewCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/17/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
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

import os.log
import UIKit

class CollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageFavoriteBackground: UIVisualEffectView!
    @IBOutlet weak var selectStatus: UIImageView!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CollectionViewCell.self)
    )
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        MainActor.assumeIsolated {
            self.initCell()
        }
    }
    
    override func prepareForReuse() {
        initCell()
    }
    
    func resetStatusIcon() {
        imageStatus.tintColor = .white
        imageStatus.isHidden = true
        imageStatus.image = nil
    }
    
    func showVideoIcon() {
        imageStatus.isHidden = false
        imageStatus.image = UIImage(systemName: "play.fill")
    }
    
    func showLivePhotoIcon() {
        imageStatus.isHidden = false
        imageStatus.image = UIImage(systemName: "livephoto")
    }
    
    func showFavorite() {
        imageFavorite.isHidden = false
        imageFavoriteBackground.isHidden = false
    }
    
    func selectMode(_ status: Bool) {
        if status {
            selectStatus.isHidden = false
        } else {
            selectStatus.isHidden = true
        }
    }
    
    func selected(_ status: Bool) {
        if status {
            selectStatus.image = UIImage(systemName: "checkmark.circle")
            selectStatus.layer.cornerRadius = selectStatus.frame.width / 2
            selectStatus.backgroundColor = .white
            selectStatus.tintColor = .tintColor
        } else {
            selectStatus.image = UIImage(systemName: "circle")
            selectStatus.backgroundColor = .clear
            selectStatus.tintColor = .white
        }
    }
    
    func favoriteMode(_ status: Bool) {
        if status {
            imageFavorite.isHidden = false
            imageFavoriteBackground.isHidden = false
        } else {
            imageFavorite.isHidden = true
            imageFavoriteBackground.isHidden = true
        }
    }
    
    func favorited(_ status: Bool) {
        
        if status {
            imageFavorite.image = UIImage(systemName: "star")?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        } else {
            imageFavorite.image = UIImage(systemName: "star.fill")?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        }
    }
    
    func setImage(_ image: UIImage?) {
        
        DispatchQueue.main.async { [weak self] in
            
            guard image != nil else {
                self?.imageView.image = nil
                self?.imageView.backgroundColor = .secondarySystemBackground
                return
            }

            self?.imageView.contentMode = .scaleAspectFill

            if let imageView = self?.imageView {
                UIView.transition(with: imageView,
                                  duration: 0.5,
                                  options: .transitionCrossDissolve,
                                  animations: { [weak self] in self?.imageView.image = image },
                                  completion: { [weak self] _ in self?.imageView.backgroundColor = .clear })
            }
        }
    }
    
    private func initCell() {
        
        imageStatus.image = nil
        imageView.image = nil
        imageFavorite.image = nil
        
        imageView.contentMode = .scaleAspectFill

        imageFavorite.isHidden = true
        imageStatus.isHidden = true
        imageStatus.tintColor = .white
        
        imageFavoriteBackground.isHidden = true
        imageFavoriteBackground.layer.cornerRadius = 8
        imageFavoriteBackground.clipsToBounds = true
    }
}
