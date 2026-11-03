//
//  ModeCell.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 5/6/25.
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

class ModeCell: UITableViewCell {

    @IBOutlet weak var darkCheckImageView: UIImageView!
    @IBOutlet weak var lightCheckImageView: UIImageView!
    @IBOutlet weak var darkLabel: UILabel!
    @IBOutlet weak var lightLabel: UILabel!
    @IBOutlet weak var darkStackView: UIStackView!
    @IBOutlet weak var lightStackView: UIStackView!

    var style: UIUserInterfaceStyle?

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()

        MainActor.assumeIsolated { [weak self] in
            self?.initCell()
        }
    }

    func setStyle(style: UIUserInterfaceStyle) {

        self.style = style

        if style == .light {
            setLightChecked()
            accessibilityLabel = Strings.SettingsLabelLight
        } else if style == .dark {
            setDarkChecked()
            accessibilityLabel = Strings.SettingsLabelDark
        }
    }

    func setDarkChecked() {
        darkCheckImageView.image = UIImage(systemName: "checkmark.circle.fill")
        lightCheckImageView.image = UIImage(systemName: "circle")
    }

    func setLightChecked() {
        darkCheckImageView.image = UIImage(systemName: "circle")
        lightCheckImageView.image = UIImage(systemName: "checkmark.circle.fill")
    }

    private func initCell() {

        darkLabel.text = Strings.SettingsLabelDark
        lightLabel.text = Strings.SettingsLabelLight

        isAccessibilityElement = true
        accessibilityTraits = [.button]
        accessibilityHint = Strings.SettingsDisplayModeToggleHint
    }
}
