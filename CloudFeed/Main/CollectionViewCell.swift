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
    @IBOutlet weak var imageSelected: UIImageView!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CollectionViewCell.self)
    )
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        MainActor.assumeIsolated { [weak self] in
            self?.initCell()
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
    
    func selected(_ status: Bool, removal: Bool) {

        if status {
            let color: UIColor = removal ? .systemRed : UIColor.tintColor
            let sysImage: String = removal ? "x.square" : "checkmark.square"
            imageSelected.image = UIImage(systemName: sysImage)?.withTintColor(.white, renderingMode: .alwaysOriginal)
            imageSelected.backgroundColor = color
            imageSelected.tintColor = color
            imageSelected.isHidden = false
            layer.borderColor = color.cgColor
            layer.borderWidth = 3
        } else {
            imageSelected.image = nil
            imageSelected.isHidden = true
            layer.borderWidth = 0
        }
    }
    
    func setImage(_ image: UIImage?) {
        
        DispatchQueue.main.async { [weak self] in
            
            guard image != nil else {
                self?.imageView.image = nil
                self?.imageView.backgroundColor = .secondarySystemBackground
                return
            }

            let backgroundColor: UIColor
            
            if ImageUtility.ratioWithinThreshold(self?.imageView.image?.size ?? .zero) == true {
                self?.imageView.contentMode = .scaleAspectFill
                backgroundColor = .secondarySystemBackground
            } else {
                self?.imageView.contentMode = .scaleAspectFit
                backgroundColor = .systemBackground
            }

            if let imageView = self?.imageView {
                UIView.transition(with: imageView,
                                  duration: 0.5,
                                  options: .transitionCrossDissolve,
                                  animations: { [weak self] in self?.imageView.image = image },
                                  completion: { [weak self] _ in self?.imageView.backgroundColor = backgroundColor })
            }
        }
    }
    
    private func initCell() {
        
        imageStatus.image = nil
        imageView.image = nil
        imageSelected.image = nil
        
        imageView.backgroundColor = .secondarySystemBackground
        
        imageSelected.isHidden = true
        imageStatus.isHidden = true
        imageStatus.tintColor = .white
        
        layer.borderWidth = 0
    }
}
