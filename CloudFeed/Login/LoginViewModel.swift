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

import os.log
import UIKit

@MainActor
protocol LoginDelegate: AnyObject, Sendable {
    func loginSuccess(account: String, urlBase: String, user: String, userId: String, password: String)
    func loginError()
}

@MainActor
final class LoginViewModel: NSObject {
    
    weak var delegate: LoginDelegate?
    weak var dataService: DataService?
    
    private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: LoginViewModel.self)
        )
    
    init(delegate: LoginDelegate, dataService: DataService) {
        self.delegate = delegate
        self.dataService = dataService
    }

    func loginPoll(token: String, endpoint: String) async {
        
        if let result = await dataService?.loginPoll(token: token, endpoint: endpoint) {
            login(server: result.urlBase, username: result.user, password: result.appPassword)
        }
    }
    
    func login(server: String, username: String, password: String) {
        
        var urlBase = server

        if urlBase.last == "/" {
            urlBase = String(urlBase.dropLast())
        }

        let account: String = "\(username) \(urlBase)"

        if dataService?.getAccounts() == nil {
            initSettings()
        }

        // Add new account
        dataService?.deleteAccount(account)
        dataService?.addAccount(account, urlBase: urlBase, user: username, password: password)

        Task { @MainActor [weak self] in
            
            guard let tableAccount = self?.dataService?.setActiveAccount(account) else {
                self?.delegate?.loginError()
                return
            }
            
            self?.delegate?.loginSuccess(account: account, urlBase: urlBase, user: username, userId: tableAccount.userId, password: password)
        }
     }
    
    private func initSettings() {
        
        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0

        dataService?.clearDatabase(account: nil, removeAccount: true)
    }
}
