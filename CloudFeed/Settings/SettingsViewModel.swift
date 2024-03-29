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


protocol SettingsDelegate: AnyObject {
    func avatarLoaded(image: UIImage?)
    func cacheCleared()
    func cacheCalculated(cacheSize: Int64)
    func profileResultReceived(profileName: String, profileEmail: String)
}

final class SettingsViewModel: NSObject {
    
    let delegate: SettingsDelegate
    let dataService: DataService
    
    init(delegate: SettingsDelegate, dataService: DataService) {
        self.delegate = delegate
        self.dataService = dataService
    }
    
    func requestProfile() {
        
        Task { [weak self] in
            guard let self else { return }
            
            let result = await dataService.getUserProfile()
            delegate.profileResultReceived(profileName: result.profileDisplayName, profileEmail: result.profileEmail)
        }
    }
    
    func requestAvatar() {
        
        guard let account = dataService.getActiveAccount() else { return }
        
        Task { [weak self] in
            guard let self else { return }
            
            await downloadAvatar(account: account)
            let image = await loadAvatar(account: account)
            
            delegate.avatarLoaded(image: image)
        }
    }
    
    func clearCache() {
        
        Task {[weak self] in
            guard let self else { return }
            guard let account = Environment.current.currentUser?.account else { return }
            
            URLCache.shared.removeAllCachedResponses()
            URLCache.shared.diskCapacity = 0
            URLCache.shared.memoryCapacity = 0
            
            dataService.clearDatabase(account: account, removeAccount: false)
            
            StoreUtility.removeGroupDirectoryProviderStorage()
            StoreUtility.removeDirectoryUserData()
            
            StoreUtility.removeDocumentsDirectory()
            
            StoreUtility.removeTemporaryDirectory()
            StoreUtility.initTemporaryDirectory()
            
            HTTPCache.shared.deleteAllCache()
            
            delegate.cacheCleared()
        }
    }
    
    func reset() {
        
        Task { [weak self] in
            guard let self else { return }
            
            URLCache.shared.diskCapacity = 0
            URLCache.shared.memoryCapacity = 0
            
            StoreUtility.removeGroupDirectoryProviderStorage()
            
            StoreUtility.removeDocumentsDirectory()
            StoreUtility.removeTemporaryDirectory()
            
            StoreUtility.deleteAllChainStore()
            
            dataService.removeDatabase()
            
            exit(0)
        }
    }
    
    func calculateCacheSize() {
        
        Task { [weak self] in
            guard let self else { return }
            guard let directory = StoreUtility.getDirectoryProviderStorage() else { return }
            
            let totalSize = FileSystemUtility.shared.getDirectorySize(directory: directory)
            
            delegate.cacheCalculated(cacheSize: totalSize)
        }
    }
    
    private func downloadAvatar(account: tableAccount) async {
        
        guard let user = Environment.current.currentUser?.user else { return }
        
        await dataService.downloadAvatar(user: user, account: account)
    }
    
    private func loadAvatar(account: tableAccount) async -> UIImage? {

        let userBaseUrl = NextcloudUtility.shared.getUserBaseUrl(account)
        let image = loadUserImage(for: account.userId, userBaseUrl: userBaseUrl)
        
        return image
    }
    
    private func loadUserImage(for user: String, userBaseUrl: String) -> UIImage? {
        
        let fileName = userBaseUrl + "-" + user + ".png"
        let localFilePath = String(StoreUtility.getDirectoryUserData()) + "/" + fileName

        if let localImage = UIImage(contentsOfFile: localFilePath) {
            return createAvatar(image: localImage, size: 150)
        } else if let loadedAvatar = dataService.getAvatarImage(fileName: fileName) {
            return loadedAvatar
        } else {
            return nil
        }
    }
    
    private func createAvatar(image: UIImage, size: CGFloat) -> UIImage {
        
        var avatarImage = image
        let rect = CGRect(x: 0, y: 0, width: size, height: size)

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 3.0)
        UIBezierPath(roundedRect: rect, cornerRadius: rect.size.height).addClip()
        avatarImage.draw(in: rect)
        avatarImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return avatarImage
    }
}
