//
//  AvatarCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/23/25.
//  Copyright © 2025 Angela Jarosz. All rights reserved.
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

import UIKit

class AvatarCell: UITableViewCell {
    
    @IBOutlet weak var avatarImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        MainActor.assumeIsolated {
            
            avatarImageView.layer.cornerRadius = avatarImageView.frame.size.width / 2
            avatarImageView.layer.masksToBounds = true
        }
    }
    
    func updateAvatarImage(_ image: UIImage?) {

        if image == nil {
            let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .ultraLight)
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill", withConfiguration: configuration)?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
        } else {
            avatarImageView.image = image
        }
    }
}
