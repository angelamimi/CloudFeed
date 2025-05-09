//
//  DisplayViewModel.swift
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

@MainActor
class DisplayViewModel {
    
    let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
    }
    
    func getStyle() -> UIUserInterfaceStyle? {
        return dataService.getDisplayStyle()
    }
    
    func setStyle(style: UIUserInterfaceStyle?) {
        dataService.saveDisplayStyle(style: style)
    }
}
