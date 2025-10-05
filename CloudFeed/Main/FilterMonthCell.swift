//
//  FilterMonthCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/7/25.
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

class FilterMonthCell: UICollectionViewCell {
    
    @IBOutlet weak var monthButton: UIButton!
    
    override func prepareForReuse() {
        super.prepareForReuse()

        monthButton.tintColor = .label
        monthButton.isSelected = false
        monthButton.configuration = UIButton.Configuration.gray()
    }
    
    func setMonth(index: Int, _ month: String) {
        monthButton.setTitle(month, for: [])
    }
}
