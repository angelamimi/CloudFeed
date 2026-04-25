//
//  FilterYearCell.swift
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

@MainActor
protocol YearCellDelegate: AnyObject {
    func yearSelected(year: Int, selected: Bool)
}

class FilterYearCell: UICollectionViewCell {
    
    @IBOutlet weak var yearButton: UIButton!
    
    weak var delegate: YearCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        MainActor.assumeIsolated { [weak self] in
            self?.initCell()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        yearButton.isSelected = false
        yearButton.configuration?.title = ""
    }
    
    func setSelected(selected: Bool) {
        yearButton.isSelected = selected
    }
    
    func setYear(_ year: Int) {
        yearButton.configuration?.title = year.description
    }
    
    @objc func yearButtonTouched(_ sender: UIButton) {
        delegate?.yearSelected(year: sender.tag, selected: sender.isSelected)
    }
    
    private func initCell() {
        
        yearButton.configuration = .plain()
        
        yearButton.addTarget(self, action: #selector(yearButtonTouched(_:)), for: .touchUpInside)
        
        yearButton.configuration?.baseForegroundColor = traitCollection.userInterfaceStyle == .dark ? .white : .black
        
        yearButton.configurationUpdateHandler = { [weak self] button in

            if button.isSelected {
                button.configuration?.background.strokeWidth = 2
                button.configuration?.background.strokeColor = .tintColor
                button.configuration?.background.backgroundColor = .tintColor.withAlphaComponent(0.2)
                button.configuration?.baseForegroundColor = .tintColor
            } else {
                button.configuration?.background.strokeWidth = 0
                if #available(iOS 26, *) {
                    button.configuration?.background.backgroundColor = .tertiarySystemFill.withAlphaComponent(0.3)
                } else {
                    button.configuration?.background.backgroundColor = .secondarySystemBackground
                }
                button.configuration?.baseForegroundColor = self?.traitCollection.userInterfaceStyle == .dark ? .white : .black //using .label here causes title to jump
            }
        }
    }
}
