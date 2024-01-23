//
//  FilterController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 1/21/24.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
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


class FilterController: UIViewController {
    
    @IBOutlet weak var filterView: FilterView!
    
    func setFilterable(filterable: Filterable) {
        filterView.filterable = filterable
    }
    
    func initDateFilter(from: Date?, to: Date?) {
        if from != nil && to != nil {
            filterView.fromPicker.date = from!
            filterView.toPicker.date = to!
        } else {
            filterView.fromPicker.date = Date()
            filterView.toPicker.date = Date()
        }
    }
}
