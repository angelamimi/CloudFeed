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
protocol SettingsDelegate: AnyObject {
    func userChanged()
    func userChangeError()
    func applicationReset()
    func cacheCleared()
    func cacheCalculated(cacheSize: Int64)
    func profileResultReceived(profileName: String, profileEmail: String, profileImage: UIImage?)
}

@MainActor
final class SettingsViewModel: NSObject {
    
    let delegate: SettingsDelegate
    let dataService: DataService
    
    init(delegate: SettingsDelegate, dataService: DataService) {
        self.delegate = delegate
        self.dataService = dataService
    }
    
    func getAccounts() -> [tableAccount] {
        return dataService.getAccountsOrderedByAlias()
    }
    
    func requestProfile() {
        
        guard let account = dataService.getActiveAccount() else { return }
        
        Task { [weak self] in
            guard let self else { return }
            guard let currentUser = Environment.current.currentUser else { return }
            
            let result = await dataService.getUserProfile(account: currentUser.account)
            
            await downloadAvatar(account: account, user: currentUser.user)
            let image = await loadAvatar(account: account)
            
            delegate.profileResultReceived(profileName: result.profileDisplayName, profileEmail: result.profileEmail, profileImage: image)
        }
    }

    func clearCache() {
        
        Task { [weak self] in
            
            if let account = Environment.current.currentUser?.account {
                self?.dataService.clearDatabase(account: account, removeAccount: false)
            }
            
            await self?.dataService.store.clearCache()
            
            self?.delegate.cacheCleared()
        }
    }
    
    func reset() {
        
        let store = dataService.store
        
        Task { [weak self] in
            
            await store.clearCache()
            await store.removeDocumentsDirectory()
            store.deleteAllChainStore()
            
            await self?.dataService.removeDatabase()
            
            self?.delegate.applicationReset()
        }
    }
    
    func calculateCacheSize() {

        let dir = dataService.store.cacheDirectory
        
        Task { [weak self] in
            let totalSize = await FileSystemUtility.getDirectorySize(directory: dir)
            self?.delegate.cacheCalculated(cacheSize: totalSize)
        }
    }
    
    func changeAccount(account: String) {
        
        Task { [weak self] in
            
            guard let tableAccount = self?.dataService.setActiveAccount(account) else {
                self?.delegate.userChangeError()
                return
            }
            
            if Environment.current.setCurrentUser(account: account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId) {
                self?.dataService.setup(account: account)
            }
             
            if let currentUser = Environment.current.currentUser {
                self?.dataService.appendSession(account: currentUser.account, user: currentUser.user, userId: currentUser.userId, urlBase: currentUser.urlBase)
                await self?.dataService.updateAccount(account: currentUser.account)
                self?.delegate.userChanged()
            }
        }
    }
    
    func downloadAvatar(account: tableAccount, user: String) async {
        
        let userBaseUrl = buildUserBaseUrl(account)
        let fileName = userBaseUrl + "-" + user + ".png"
        
        await dataService.downloadAvatar(fileName: fileName, account: account)
    }
    
    private func buildUserBaseUrl(_ account: tableAccount) -> String {
        return account.user + "-" + (URL(string: account.urlBase)?.host ?? "")
    }
    
    func loadAvatar(account: tableAccount) async -> UIImage? {

        let userBaseUrl = buildUserBaseUrl(account)
        let image = loadUserImage(for: account.userId, userBaseUrl: userBaseUrl)
        
        return image
    }
    
    private func loadUserImage(for user: String, userBaseUrl: String) -> UIImage? {
        
        let fileName = userBaseUrl + "-" + user + ".png"
        let localFilePath = dataService.store.getUserDirectory() + "/" + fileName

        if let localImage = UIImage(contentsOfFile: localFilePath) {
            return localImage
        } else {
            return nil
        }
    }
}
