//
//  SettingsCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
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
protocol CacheDelegate: AnyObject {
    func cacheCleared()
    func clearUser()
    func reset()
}

@MainActor
final class SettingsCoordinator {
    
    weak var navigationController: UINavigationController!
    
    let dataService: DataService
    let cacheDelegate: CacheDelegate
    
    init(navigationController: UINavigationController, dataService: DataService, cacheDelegate: CacheDelegate) {
        self.navigationController = navigationController
        self.dataService = dataService
        self.cacheDelegate = cacheDelegate
    }
    
    func cacheCleared() {
        cacheDelegate.cacheCleared()
    }
    
    func showAcknowledgements() {
        let controller = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "Acknowledgements")
        navigationController.pushViewController(controller, animated: true)
    }
    
    func showProfile() {
        let controller = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "Profile") as! ProfileController
        controller.viewModel = ProfileViewModel(delegate: controller, accountDelegate: controller, dataService: dataService, coordinator: self)
        navigationController.pushViewController(controller, animated: true)
    }
    
    func showDisplay() {
        let controller = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "Display") as! DisplayController
        controller.viewModel = DisplayViewModel(dataService: dataService)
        navigationController.pushViewController(controller, animated: true)
    }
    
    func showPicker() {
        let pickerCoordinator = PickerCoordinator(navigationController: navigationController, dataService: dataService)
        pickerCoordinator.start()
    }
    
    func showProfileLoadfailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.ProfileErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
    
    func checkReset(reset: @escaping () -> Void) {
        
        let alert = UIAlertController(title: Strings.ResetTitle, message: Strings.ResetMessage, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: Strings.CancelAction, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.ResetAction, style: .destructive, handler: { _ in
            reset()
        }))
        
        navigationController.present(alert, animated: true)
    }
    
    func checkRemoveAccount(remove: @escaping () -> Void) {
        
        let alert = UIAlertController(title: Strings.ProfileRemoveTitle, message: Strings.ProfileRemoveMessage, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: Strings.CancelAction, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.ProfileRemoveAction, style: .destructive, handler: { _ in
            remove()
        }))
        
        navigationController.present(alert, animated: true)
    }
    
    func launchAddAccount() {
        let coordinator = LoginServerModalCoordinator(navigationController: navigationController, dataService: dataService)
        coordinator.delegate = self
        coordinator.start()
    }
    
    func applicationReset() {
        cacheDelegate.reset()
    }
    
    func clearUser() {
        cacheDelegate.clearUser()
    }
}

extension SettingsCoordinator: UserDelegate {
    
    func currentUserChanged() {
        cacheDelegate.clearUser()
    }
}
