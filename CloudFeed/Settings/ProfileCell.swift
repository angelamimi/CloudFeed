//
//  ProfileCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/4/23.
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

import UIKit

class ProfileCell: UITableViewCell {
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var profileImageViewTopContraint: NSLayoutConstraint!
    @IBOutlet weak var profileEmailLabel: UILabel!
    @IBOutlet weak var profileNameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        MainActor.assumeIsolated {
            
            profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
            profileImageView.layer.masksToBounds = true
        
            profileNameLabel.font = UIFont.preferredFont(forTextStyle: .body)
            profileEmailLabel.font = UIFont.preferredFont(forTextStyle: .body)
        }
    }

    func updateProfileImage(_ image: UIImage?) {

        if image == nil {
            let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .ultraLight)
            profileImageView.image = UIImage(systemName: "person.crop.circle.fill", withConfiguration: configuration)?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
        } else {
            profileImageView.image = image
        }
    }
    
    func updateProfile(_ email: String, fullName name: String) {
        profileNameLabel.text = name
        profileEmailLabel.text = email
    }
}

