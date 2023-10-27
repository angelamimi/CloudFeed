//
//  SettingsViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/14/23.
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
            
            //TODO: THIS CAUSES VIDEOS TO NOT PLAY ON LONG CLICK OF COLLECTION VIEW
            //StoreUtility.removeTemporaryDirectory()
            
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
            
            //let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .binary)
            //Self.logger.debug("calculateCacheSize() - \(formattedSize)")
            
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
