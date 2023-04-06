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
        
        profileImageView.layer.cornerRadius = 20
        profileImageView.layer.masksToBounds = true
    }

    func updateProfileImage(_ image: UIImage) {
        profileImageView.image = image
    }
    
    func updateProfile(_ email: String, fullName name: String) {
        profileNameLabel.text = name
        profileEmailLabel.text = email
    }
}

