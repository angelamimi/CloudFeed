//
//  DetailCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
//

import UIKit

class DetailCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel : UILabel?
    @IBOutlet weak var detailLabel : UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func prepareForReuse() {
        titleLabel?.text = ""
        detailLabel?.text = ""
    }
}
