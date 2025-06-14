//
//  PickerCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 6/12/25.
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
final class PickerCoordinator {
    
    private let navigationController: UINavigationController
    private let dataService: DataService
    
    private var pickerNavigationController: UINavigationController!
    
    init(navigationController: UINavigationController, dataService: DataService) {
        self.navigationController = navigationController
        self.dataService = dataService
    }
    
    func start(_ serverUrl: String? = nil) {
        pickerNavigationController = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(identifier: "PickerNavController") as UINavigationController
        if let picker = pickerNavigationController.viewControllers[0] as? PickerController {
            picker.viewModel = PickerViewModel(coordinator: self, dataService: dataService)
            picker.delegate = self
            navigationController.present(pickerNavigationController, animated: true)
        }
    }
    
    func open(_ serverUrl: String, _ metadata: Metadata) {
        let picker = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(identifier: "PickerController") as PickerController
        picker.viewModel = PickerViewModel(coordinator: self, dataService: dataService)
        picker.serverUrl = serverUrl
        picker.metadata = metadata
        picker.delegate = self
        pickerNavigationController.pushViewController(picker, animated: true)
    }
}

extension PickerCoordinator: PickerDelegate {
    
    func cancel() {
        navigationController.dismiss(animated: true)
    }
    
    func select() {
        navigationController.dismiss(animated: true, completion: {
            NotificationCenter.default.post(name: Notification.Name("MediaPathChanged"), object: nil, userInfo: nil)
        })
    }
}
