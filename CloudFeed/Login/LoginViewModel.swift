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
    func loginSuccess(account: String, urlBase: String, user: String, userId: String, password: String)
    func loginError()
}

final class LoginViewModel: NSObject {
    
    let delegate: LoginDelegate
    let dataService: DataService
    
    private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: LoginViewModel.self)
        )
    
    init(delegate: LoginDelegate, dataService: DataService) {
        self.delegate = delegate
        self.dataService = dataService
    }
    
    func login(server: String, username: String, password: String) {
        
        var urlBase = server

        // Normalized
        if urlBase.last == "/" {
            urlBase = String(urlBase.dropLast())
        }

        let account: String = "\(username) \(urlBase)"

        if dataService.getAccounts() == nil {
            initSettings()
        }

        // Add new account
        dataService.deleteAccount(account)
        dataService.addAccount(account, urlBase: urlBase, user: username, password: password)

        guard let tableAccount = dataService.setActiveAccount(account) else {
            delegate.loginError()
            return
        }
        
        delegate.loginSuccess(account: account, urlBase: urlBase, user: username, userId: tableAccount.userId, password: password)
     }
    
    private func initSettings() {
        
        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
        KTVHTTPCache.cacheDeleteAllCaches()

        dataService.clearDatabase(account: nil, removeAccount: true)

        StoreUtility.initStorage()
    }
}
