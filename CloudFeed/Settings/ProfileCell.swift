//
//  ProfileCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/4/23.
//

import UIKit

class ProfileCell: UITableViewCell {
    
    @IBOutlet weak var profileBackground: UIView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var profileEmailLabel: UILabel!
    @IBOutlet weak var profileNameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        profileBackground.layer.cornerRadius = 20
        profileBackground.layer.masksToBounds = true
        profileBackground.layer.borderColor = UIColor.label.cgColor
        profileBackground.layer.borderWidth = 1
        
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.layer.masksToBounds = true
        profileImageView.layer.borderColor = UIColor.label.cgColor
        profileImageView.layer.borderWidth = 1
    }

    func updateProfileImage(_ image: UIImage?) {
        if image == nil {
            let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .ultraLight)
            let sysImage = UIImage(systemName: "person.crop.circle.fill", withConfiguration: configuration)?.withTintColor(.label, renderingMode: .alwaysOriginal)
            profileImageView.image = sysImage
            profileImageView.layer.borderWidth = 0
            profileImageView.layer.cornerRadius = 0
        } else {
            profileImageView.image = image
        }
    }
    
    func updateProfile(_ email: String, fullName name: String) {
        profileNameLabel.text = name
        profileEmailLabel.text = email
    }
}

