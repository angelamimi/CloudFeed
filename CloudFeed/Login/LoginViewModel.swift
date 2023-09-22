//
//  LoginViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/16/23.
//

import KTVHTTPCache
import os.log
import UIKit

protocol LoginDelegate: AnyObject {
    func loginSuccess()
    func loginError()
}

final class LoginViewModel: NSObject {
    
    var delegate: LoginDelegate!
    
    private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: LoginViewModel.self)
        )
    
    init(delegate: LoginDelegate) {
        self.delegate = delegate
    }
    
    func login(server: String, username: String, password: String) {
        
        //Self.logger.debug("createAccount() - server: \(server) username: \(username) password: \(password)")

        let dataService = Environment.current.dataService!
        var urlBase = server

        // Normalized
        if urlBase.last == "/" {
            urlBase = String(urlBase.dropLast())
        }

        let account: String = "\(username) \(urlBase)"

        if dataService.getAccounts() == nil {
            
            initSettings()
            
            Self.logger.debug("createAccount() - removeAllSettings???")
        }

        // Add new account
        dataService.deleteAccount(account)
        dataService.addAccount(account, urlBase: urlBase, user: username, password: password)

        guard let tableAccount = dataService.setActiveAccount(account) else {
            delegate.loginError()
            return
        }
        
        Environment.current.setupFor(account: account, urlBase: urlBase, user: username, userId: tableAccount.userId, password: password)
        
        delegate.loginSuccess()
     }
    
    private func initSettings() {
        
        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
        KTVHTTPCache.cacheDeleteAllCaches()

        Environment.current.dataService.clearDatabase(account: nil, removeAccount: true)

        //StoreUtility.removeGroupDirectoryProviderStorage()
        //StoreUtility.removeGroupLibraryDirectory()

        //TODO: Causes database to fail. account isn't found eventhough was added
        //StoreUtility.removeDocumentsDirectory()
        
        
        //StoreUtility.removeTemporaryDirectory()

        StoreUtility.initStorage()

        //StoreUtility.deleteAllChainStore()
    }
}
