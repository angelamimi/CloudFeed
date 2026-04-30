//
//  RouteView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/27/26.
//  Copyright © 2026 Angela Jarosz. All rights reserved.
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

import AVKit
import UIKit

class RouteView: UIView {
    
    var routePicker: AVRoutePickerView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        
        routePicker = AVRoutePickerView()

        addSubview(routePicker)
        
        routePicker.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            routePicker.topAnchor.constraint(equalTo: topAnchor),
            routePicker.leftAnchor.constraint(equalTo: leftAnchor),
            routePicker.widthAnchor.constraint(equalToConstant: 50),
            routePicker.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        routePicker.tintColor = .label
        routePicker.activeTintColor = .tintColor
        routePicker.prioritizesVideoDevices = true
    }
}
