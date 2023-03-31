//
//  SettingsUtility.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//

import UIKit
import AVFoundation
import KTVHTTPCache
import os.log

class SettingsUtility: NSObject {
    static let shared: SettingsUtility = {
        let instance = SettingsUtility()
        return instance
    }()
    
    func initSettings() {

        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
        KTVHTTPCache.cacheDeleteAllCaches()

        DatabaseManager.shared.clearDatabase(account: nil, removeAccount: true)

        //StoreUtility.removeGroupDirectoryProviderStorage()
        //StoreUtility.removeGroupLibraryDirectory()

        //TODO: Causes database to fail. account isn't found eventhough was added
        //StoreUtility.removeDocumentsDirectory()
        
        
        //StoreUtility.removeTemporaryDirectory()

        StoreUtility.initStorage()

        //StoreUtility.deleteAllChainStore()
    }
}
