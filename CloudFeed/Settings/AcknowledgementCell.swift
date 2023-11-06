//
//  AcknowledgementCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/4/23.
//

import UIKit

class AcknowledgementCell: UITableViewCell {

    @IBOutlet weak var licenseLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        licenseLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
    }
}
