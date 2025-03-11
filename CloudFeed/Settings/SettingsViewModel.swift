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
    
    func requestProfile() {
        
        guard let account = dataService.getActiveAccount() else { return }
        
        Task { [weak self] in
            guard let self else { return }
            
            let result = await dataService.getUserProfile()
            
            await downloadAvatar(account: account)
            let image = await loadAvatar(account: account)
            
            delegate.profileResultReceived(profileName: result.profileDisplayName, profileEmail: result.profileEmail, profileImage: image)
        }
    }

    func clearCache() {
        
        let store = dataService.store
        
        Task(priority: .high) { [weak self] in
            
            if let account = Environment.current.currentUser?.account {
                self?.dataService.clearDatabase(account: account, removeAccount: false)
            }
            
            await store.clearCache()
            
            self?.delegate.cacheCleared()
        }
    }
    
    func reset() {
        
        let store = dataService.store
        
        Task(priority: .high) { [weak self] in
            
            await store.clearCache()
            store.removeDocumentsDirectory()
            store.deleteAllChainStore()
            
            self?.dataService.removeDatabase()
            
            self?.delegate.applicationReset()
        }
    }
    
    func calculateCacheSize() {

        let totalSize = FileSystemUtility.getDirectorySize(directory: dataService.store.cacheDirectory)
        
        delegate.cacheCalculated(cacheSize: totalSize)
    }
    
    private func downloadAvatar(account: tableAccount) async {
        
        guard let user = Environment.current.currentUser?.user else { return }
        
        let userBaseUrl = buildUserBaseUrl(account)
        let fileName = userBaseUrl + "-" + user + ".png"
        
        await dataService.downloadAvatar(fileName: fileName, account: account)
    }
    
    private func buildUserBaseUrl(_ account: tableAccount) -> String {
        return account.user + "-" + (URL(string: account.urlBase)?.host ?? "")
    }
    
    private func loadAvatar(account: tableAccount) async -> UIImage? {

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
