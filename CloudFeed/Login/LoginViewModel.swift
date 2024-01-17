//
//  LoginViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/16/23.
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
