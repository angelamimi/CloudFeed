//
//  ProfileCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/4/23.
//

import UIKit

class ProfileCell: UITableViewCell {
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var profileEmailLabel: UILabel!
    @IBOutlet weak var profileNameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.layer.masksToBounds = true
        
        profileNameLabel.font = UIFont.preferredFont(forTextStyle: .body)
        profileEmailLabel.font = UIFont.preferredFont(forTextStyle: .body)
    }

    func updateProfileImage(_ image: UIImage?) {
        
        if image == nil {
            let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .ultraLight)
            profileImageView.image = UIImage(systemName: "person.crop.circle.fill", withConfiguration: configuration)?.withTintColor(.secondarySystemBackground, renderingMode: .alwaysOriginal)
        } else {
            profileImageView.image = image
        }
    }
    
    func updateProfile(_ email: String, fullName name: String) {
        profileNameLabel.text = name
        profileEmailLabel.text = email
    }
}

