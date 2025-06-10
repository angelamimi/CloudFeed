//
//  DatabaseManager+Account.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 6/8/25.
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

import Foundation
import os.log
import SwiftData

@Model
final class AccountModel {

    var account = ""
    var active: Bool = false
    var displayName = ""
    var urlBase = ""
    var user = ""
    var userId = ""
    
    init(account: String = "",
         active: Bool,
         displayName: String = "",
         urlBase: String = "",
         user: String = "",
         userId: String = "") {
        
        self.account = account
        self.active = active
        self.displayName = displayName
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
    }
}

struct Account: Sendable {
    
    var account: String
    var active: Bool
    var displayName: String
    var urlBase: String
    var user: String
    var userId: String
    
    init(_ account: AccountModel) {
        self.account = account.account
        self.active = account.active
        self.displayName = account.displayName
        self.urlBase = account.urlBase
        self.user = account.user
        self.userId = account.userId
    }
}

extension DatabaseManager {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DatabaseManager.self) + String(describing: Account.self)
    )
    
    func addAccount(_ account: String, urlBase: String, user: String, userId: String) {
        modelContext.insert(AccountModel(account: account, active: false, urlBase: urlBase, user: user, userId: userId))
    }
    
    func setActiveAccount(_ account: String) -> Account? {
        
        do {
            if let accountModel = getAccountModel(account) {
                accountModel.active = true
                try modelContext.save()
                return Account.init(accountModel)
            }
        } catch let error as NSError {
            Self.logger.error("Failed to set active account: \(error.localizedDescription)")
            return nil
        }
        
        return nil
    }
    
    func getAccountCount() -> Int {
        let fetchDescriptor = FetchDescriptor<AccountModel>()
        if let count = try? modelContext.fetchCount(fetchDescriptor) {
            return count
        } else {
            return 0
        }
    }
    
    func getActiveAccount() -> Account? {
        
        let predicate = #Predicate<AccountModel> { account in
            account.active == true
        }
        
        let fetchDescriptor = FetchDescriptor<AccountModel>(predicate: predicate)
        
        if let result = try? modelContext.fetch(fetchDescriptor), let account = result.first {
            return Account.init(account)
        }
        
        return nil
    }
    
    func getAccountsOrdered() -> [Account] {
        
        ///can't sort on a boolean field, so split the fetches on active value
        
        let sortBy = [SortDescriptor<AccountModel>(\.displayName, order: .forward),
                      SortDescriptor<AccountModel>(\.user, order: .forward)]
        
        let activePredicate = #Predicate<AccountModel> { account in
            account.active == true
        }
        
        let inactivePredicate = #Predicate<AccountModel> { account in
            account.active == false
        }
        
        let activeFetchDescriptor = FetchDescriptor<AccountModel>(predicate: activePredicate, sortBy: sortBy)
        let inactiveFetchDescriptor = FetchDescriptor<AccountModel>(predicate: inactivePredicate, sortBy: sortBy)
        
        do {
            let activeResults = try modelContext.fetch(activeFetchDescriptor)
            let inactiveResults = try modelContext.fetch(inactiveFetchDescriptor)
            
            return Array(activeResults.map { Account.init($0) }) + Array(inactiveResults.map { Account.init($0) })
            
        } catch let error as NSError {
            Self.logger.error("Fetch failed: \(error.localizedDescription)")
        }
        
        return []
    }
    
    func deleteAccount(_ account: String) {
        if let accountModel = getAccountModel(account) {
            modelContext.delete(accountModel)
        }
    }
    
    func updateAccount(account: String, displayName: String) {
        do {
            if let accountModel = getAccountModel(account) {
                accountModel.displayName = displayName
                try modelContext.save()
            }
        } catch let error as NSError {
            Self.logger.error("Failed to update account: \(error.localizedDescription)")
        }
    }
    
    private func getAccountModel(_ account: String) -> AccountModel? {
        let predicate = #Predicate<AccountModel> { accountModel in
            accountModel.account == account
        }
        
        let fetchDescriptor = FetchDescriptor<AccountModel>(predicate: predicate)
        let results = try? modelContext.fetch(fetchDescriptor)
        
        return results?.first
    }
}
