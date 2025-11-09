//
//  PasscodeSettingsViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/28/25.
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
class PasscodeSettingsViewModel {
    
    private let coordinator: SettingsCoordinator?
    private let dataService: DataService
    
    init(coordinator: SettingsCoordinator?, dataService: DataService) {
        self.coordinator = coordinator
        self.dataService = dataService
    }
    
    func editPasscode() {
        coordinator?.showPasscode(mode: .create)
    }
    
    func setAppReset(_ appResetOnFailedAttempts: Bool) {
        if let account = Environment.current.currentUser?.account {
            dataService.store.setAppResetOnFailedAttempts(account, appResetOnFailedAttempts)
        }
    }
    
    func getAppReset() -> Bool {
        if let account = Environment.current.currentUser?.account {
            return dataService.store.getAppResetOnFailedAttempts(account)
        }
        
        return false
    }
}
