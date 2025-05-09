//
//  SettingsViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/14/23.
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
protocol SettingsDelegate: AccountDelegate {
    func cacheCleared()
    func cacheCalculated(cacheSize: Int64)
    func profileResultReceived(profileName: String, profileEmail: String, profileImage: UIImage?)
}

@MainActor
final class SettingsViewModel: ProfileViewModel {
    
    weak var settingsDelegate: SettingsDelegate!

    init(delegate: SettingsDelegate, profileDelegate: ProfileDelegate, dataService: DataService, coordinator: SettingsCoordinator) {
        self.settingsDelegate = delegate
        super.init(delegate: profileDelegate, accountDelegate: delegate, dataService: dataService, coordinator: coordinator)
    }
    
    func getAccounts() -> [tableAccount] {
        return dataService.getAccountsOrdered()
    }

    func clearCache() {
        
        Task { [weak self] in
            
            if let account = Environment.current.currentUser?.account {
                self?.dataService.clearDatabase(account: account, removeAccount: false)
            }
            
            await self?.dataService.store.clearCache()
            
            self?.coordinator.cacheCleared()
            self?.settingsDelegate.cacheCleared()
        }
    }
    
    func reset() {
        
        let store = dataService.store
        
        Task { [weak self] in
            
            await store.clearCache()
            await store.removeDocumentsDirectory()
            store.deleteAllChainStore()
            
            await self?.dataService.removeDatabase()
            
            Environment.current.currentUser = nil
            
            self?.coordinator.applicationReset()
        }
    }
    
    func calculateCacheSize() {

        let dir = dataService.store.cacheDirectory
        
        Task { [weak self] in
            let totalSize = await FileSystemUtility.getDirectorySize(directory: dir)
            self?.settingsDelegate.cacheCalculated(cacheSize: totalSize)
        }
    }
    
    func showAcknowledgements() {
        coordinator.showAcknowledgements()
    }
    
    func checkReset() {
        coordinator.checkReset { [weak self] in
            self?.reset()
        }
    }
    
    func addAccount() {
        coordinator.launchAddAccount()
    }
    
    func showProfile() {
        coordinator.showProfile()
    }
    
    func showDisplay() {
        coordinator.showDisplay()
    }
}
