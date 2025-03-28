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
        imageStatus.image = nil
    }
    
    func setStatusIcon(icon: UIImage) {
        imageStatus.image = icon
    }
    
    func showVideoIcon() {
        imageStatus.image = UIImage(systemName: "play.fill")
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
    }
}
