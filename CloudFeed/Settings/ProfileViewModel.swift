//
//  ProfileViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/23/25.
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
protocol ProfileDelegate: AnyObject {
    func beginSwitchingAccounts()
    func noAccountsFound()
    func profileResultReceived(profileName: String, profileEmail: String, profileImage: UIImage?)
}

@MainActor
protocol AccountDelegate: AnyObject {
    func userChanged()
    func userChangeError()
}

@MainActor
class ProfileViewModel {

    let dataService: DataService

    weak var delegate: ProfileDelegate!
    weak var accountDelegate: AccountDelegate!
    let coordinator: SettingsCoordinator
    
    init(delegate: ProfileDelegate, accountDelegate: AccountDelegate, dataService: DataService, coordinator: SettingsCoordinator) {
        self.delegate = delegate
        self.accountDelegate = accountDelegate
        self.dataService = dataService
        self.coordinator = coordinator
    }
    
    func requestProfile() async {
        
        guard let account = await dataService.getActiveAccount() else { return }
        
        Task { [weak self] in
            guard let self else { return }
            guard let currentUser = Environment.current.currentUser else { return }
            
            let result = await dataService.getUserProfile(account: currentUser.account)
            
            await downloadAvatar(account: account, user: currentUser.user)
            let image = await loadAvatar(account: account)
            
            delegate?.profileResultReceived(profileName: result.profileDisplayName, profileEmail: result.profileEmail, profileImage: image)
        }
    }
    
    func downloadAvatar(account: Account, user: String) async {
        
        let userBaseUrl = buildUserBaseUrl(account)
        let fileName = userBaseUrl + "-" + user + ".png"
        
        await dataService.downloadAvatar(fileName: fileName, account: account)
    }
    
    private func buildUserBaseUrl(_ account: Account) -> String {
        return account.user + "-" + (URL(string: account.urlBase)?.host ?? "")
    }
    
    func loadAvatar(account: Account) async -> UIImage? {

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
    
    func checkRemoveAccount() {
        coordinator.checkRemoveAccount { [weak self] in
            self?.removeAccount()
        }
    }
    
    func removeAccount() {
        
        delegate?.beginSwitchingAccounts()
        
        Task { [weak self] in
            await self?.removeCurrentAccount()
            await self?.activateNextAccount()
        }
    }
    
    func changeAccount(account: String) {
        
        Task { [weak self] in
            
            guard let tableAccount = await self?.dataService.setActiveAccount(account) else {
                self?.accountDelegate.userChangeError()
                return
            }
            
            Environment.current.setCurrentUser(account: account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId)
             
            if let currentUser = Environment.current.currentUser {
                await self?.dataService.appendSession(account: currentUser.account, user: currentUser.user, userId: currentUser.userId, urlBase: currentUser.urlBase)
                await self?.dataService.updateAccount(account: currentUser.account)
                self?.accountDelegate.userChanged()
            }
        }
    }
    
    func showProfileLoadfailedError() {
        coordinator.showProfileLoadfailedError()
    }
    
    func applicationReset() {
        coordinator.applicationReset()
    }
    
    private func removeCurrentAccount() async {
        if let account = Environment.current.currentUser?.account {
            await dataService.removeAccount(account)
        }
    }
    
    private func activateNextAccount() async {
        
        let accounts = await dataService.getAccountsOrdered()
        
        if accounts.isEmpty {
            Environment.current.currentUser = nil
            delegate.noAccountsFound()
        } else {
            changeAccount(account: accounts.first!.account)
        }
    }
}
