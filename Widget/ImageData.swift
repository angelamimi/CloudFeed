//
//  ImageData.swift
//  Widget
//
//  Created by Angela Jarosz on 1/27/26.
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

import UIKit
import WidgetKit
import Intents
import NextcloudKit

struct ImageDataEntry: TimelineEntry {
    
    let date: Date
    let showDate: Bool
    
    var image: UIImage?
    var title: String
    var url: URL
    var message: String?
}

let placeholderEntry = ImageDataEntry(date: .now, showDate: false, image: nil, title: "", url: URL(string: Global.shared.widgetScheme + "://")!, message: "")
