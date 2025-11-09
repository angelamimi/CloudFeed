//
//  PasscodeViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/20/25.
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
protocol ResetApplicationDelegate: AnyObject {
    func reset()
}

@MainActor
class PasscodeViewModel {
    
    private let coordinator: SettingsCoordinator?
    private let dataService: DataService
    private let resetDelegate: ResetApplicationDelegate
    
    init(coordinator: SettingsCoordinator?, dataService: DataService, resetDelegate: ResetApplicationDelegate) {
        self.coordinator = coordinator
        self.dataService = dataService
        self.resetDelegate = resetDelegate
    }
    
    func handlePasscodeCreation(_ passcode: String) {
        coordinator?.showPasscode(passcode)
    }
    
    func passcodeUnlock(_ passcode: String) -> Bool {
        
        if let user = Environment.current.currentUser, let userPasscode = dataService.store.getPasscode(user.account) {
            return passcode == userPasscode
        }
        
        return false
    }
    
    func savePasscode(_ passcode: String) {
        
        if let user = Environment.current.currentUser {
            dataService.store.setPasscode(user.account, passcode: passcode)
            coordinator?.passcodeSaved()
        }
    }
    
    func deletePasscode() {
        if let user = Environment.current.currentUser {
            dataService.store.deletePasscode(user.account)
            coordinator?.passcodeDeleted()
        }
    }
    
    func hasPasscode() -> Bool {
        if let account = Environment.current.currentUser?.account,
           let passcode = dataService.store.getPasscode(account) {
            return passcode.isEmpty == false
        }
        return false
    }
    
    func getFailedPasscodeCount() -> Int {
        if let account = Environment.current.currentUser?.account {
            let failedCount = dataService.store.getFailedPasscodeCount(account)
            return failedCount
        }
        return 0
    }
    
    func incrementFailedPasscodeCount() {
        if let account = Environment.current.currentUser?.account {
            var failedCount = dataService.store.getFailedPasscodeCount(account)
            failedCount += 1
            dataService.store.setFailedPasscodeCount(account, failedCount)
        }
    }
    
    func resetFailedPasscodeCount() {
        if let account = Environment.current.currentUser?.account {
            dataService.store.setFailedPasscodeCount(account, 0)
        }
    }
    
    func getAppResetOnFailedAttempts() -> Bool {
        if let account = Environment.current.currentUser?.account {
            return dataService.store.getAppResetOnFailedAttempts(account)
        }
        
        return false
    }
    
    func reset() {

        Task { [weak self] in
            
            await self?.dataService.reset()
            
            Environment.current.currentUser = nil
            
            self?.resetDelegate.reset()
        }
    }
}
