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
}

@MainActor
final class SettingsCoordinator {
    
    weak var settingsController: SettingsController?
    
    let dataService: DataService
    let resetDelegate: ResetApplicationDelegate
    let cacheDelegate: CacheDelegate?
    
    init(settingsController: SettingsController, dataService: DataService, cacheDelegate: CacheDelegate?, resetDelegate: ResetApplicationDelegate) {
        self.settingsController = settingsController
        self.dataService = dataService
        self.cacheDelegate = cacheDelegate
        self.resetDelegate = resetDelegate
    }
    
    func cacheCleared() {
        cacheDelegate?.cacheCleared()
    }
    
    func showAcknowledgements() {
        let controller = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "Acknowledgements")
        settingsController?.navigationController?.pushViewController(controller, animated: true)
    }
    
    func showProfile() {
        let controller = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "Profile") as! ProfileController
        controller.viewModel = ProfileViewModel(delegate: controller, accountDelegate: controller, resetDelegate: resetDelegate, dataService: dataService, coordinator: self)
        settingsController?.navigationController?.pushViewController(controller, animated: true)
    }
    
    func showDisplay() {
        let controller = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "Display") as! DisplayController
        controller.viewModel = DisplayViewModel(dataService: dataService)
        settingsController?.navigationController?.pushViewController(controller, animated: true)
    }
    
    func showRemovePasscode() {
        let controller = UIStoryboard(name: "Passcode", bundle: nil).instantiateViewController(withIdentifier: "PasscodeController") as! PasscodeController
        controller.mode = .delete
        controller.viewModel = PasscodeViewModel(coordinator: self, dataService: dataService, resetDelegate: resetDelegate)
        settingsController?.navigationController?.pushViewController(controller, animated: true)
    }
    
    func showPasscode(_ passcodeToValidate: String? = nil, mode: Global.PasscodeMode? = nil, modal: Bool = false) {
        
        let controller = UIStoryboard(name: "Passcode", bundle: nil).instantiateViewController(withIdentifier: "PasscodeController") as! PasscodeController
        
        if passcodeToValidate == nil {
            if mode == nil {
                if let account = Environment.current.currentUser?.account,
                   let passcode = dataService.store.getPasscode(account) {
                    controller.mode = passcode.isEmpty ? .create : .unlock
                    
                    if controller.mode == .unlock {
                        controller.delegate = self
                    }
                } else {
                    controller.mode = .create
                }
            } else {
                controller.mode = mode!
            }
        } else {
            controller.mode = .validate
            controller.initialPasscode = passcodeToValidate
        }
        
        controller.viewModel = PasscodeViewModel(coordinator: self, dataService: dataService, resetDelegate: resetDelegate)
        
        if modal {
            controller.isModalInPresentation = true
            controller.modalPresentationStyle = .overFullScreen
            settingsController?.navigationController?.present(controller, animated: true)
        } else {
            settingsController?.navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    func showPicker() {
        if let nav = settingsController?.navigationController {
            let pickerCoordinator = PickerCoordinator(navigationController: nav, dataService: dataService)
            pickerCoordinator.start()
        }
    }
    
    func showProfileLoadfailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.ProfileErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.settingsController?.navigationController?.popViewController(animated: true)
        }))
        
        settingsController?.navigationController?.present(alertController, animated: true)
    }
    
    func checkReset(reset: @escaping () -> Void) {
        
        let alert = UIAlertController(title: Strings.ResetTitle, message: Strings.ResetMessage, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: Strings.CancelAction, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.ResetAction, style: .destructive, handler: { _ in
            reset()
        }))
        
        settingsController?.navigationController?.present(alert, animated: true)
    }
    
    func checkRemoveAccount(remove: @escaping () -> Void) {
        
        let alert = UIAlertController(title: Strings.ProfileRemoveTitle, message: Strings.ProfileRemoveMessage, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: Strings.CancelAction, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.ProfileRemoveAction, style: .destructive, handler: { _ in
            remove()
        }))
        
        settingsController?.navigationController?.present(alert, animated: true)
    }
    
    func launchAddAccount() {
        
        guard let navigationController = settingsController?.navigationController else { return }
        
        let coordinator = LoginServerModalCoordinator(navigationController: navigationController, dataService: dataService)
        coordinator.delegate = self
        
        coordinator.start()
    }
    
    func clearUser() {
        cacheDelegate?.clearUser()
    }
    
    func passcodeSaved() {
        showPasscodeSavedAlert()
    }
    
    func passcodeDeleted() {
        showPasscodeDeletedAlert()
    }
    
    private func showPasscodeSavedAlert() {
    
        let alertController = UIAlertController(title: "", message: Strings.PasscodeSaved, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.showPasscodeSettings(passcodeCount: 2)
        }))
        
        settingsController?.navigationController?.present(alertController, animated: true)
    }
    
    private func showPasscodeDeletedAlert() {
    
        let alertController = UIAlertController(title: "", message: Strings.PasscodeDeleted, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.settingsController?.navigationController?.popToRootViewController(animated: true)
        }))
        
        settingsController?.navigationController?.present(alertController, animated: true)
    }
    
    private func showPasscodeSettings(passcodeCount: Int) {
        
        guard let navigationController = settingsController?.navigationController else { return }
        var viewControllers = navigationController.viewControllers
            
        if isUpdatePasscode(viewControllers) {
            //already have passcode settings. pop back to it.
            viewControllers.remove(atOffsets: [2, 3])
        } else {
            let controller = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "PasscodeSettingsController") as! PasscodeSettingsController
            controller.viewModel = PasscodeSettingsViewModel(coordinator: self, dataService: dataService)
            //replace passcode controller(s) with the passcode settings controller so back will navigate to the main settings controller instead of passcode again
            viewControllers.replaceSubrange(1...passcodeCount, with: [controller])
        }
        
        settingsController?.navigationController?.setViewControllers(viewControllers, animated: true)
    }
    
    private func isUpdatePasscode(_ viewControllers: [UIViewController]) -> Bool {
        
        if viewControllers.count == 4
            && viewControllers[0] is SettingsController
            && viewControllers[1] is PasscodeSettingsController {
            return true
        } else {
            return false
        }
    }
}

extension SettingsCoordinator: UserDelegate {
    
    func currentUserChanged() {
        cacheDelegate?.clearUser()
    }
}

extension SettingsCoordinator: PasscodeDelegate {
    
    func unlock() {
        
        if settingsController?.navigationController?.visibleViewController?.isModalInPresentation ?? true {
            settingsController?.navigationController?.dismiss(animated: true)
        } else {
            showPasscodeSettings(passcodeCount: 1)
        }
    }
}
