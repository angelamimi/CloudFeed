//
//  DatabaseManager+Account.swift
//  CloudFeed
//
//  Created by Marino Faggiana on 13/11/23.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import RealmSwift

class tableAccount: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var active: Bool = false
    @objc dynamic var alias = ""
    @objc dynamic var displayName = ""
    @objc dynamic var enabled: Bool = false
    @objc dynamic var mediaPath = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userId = ""
    
    override static func primaryKey() -> String {
        return "account"
    }
}

extension DatabaseManager {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                       category: String(describing: DatabaseManager.self) + "Account")
    
    func addAccount(_ account: String, urlBase: String, user: String, password: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                
                let addObject = tableAccount()

                addObject.account = account
                addObject.urlBase = urlBase
                addObject.user = user
                addObject.userId = user

                realm.add(addObject, update: .all)
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }
    
    func deleteAccount(_ account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableAccount.self).filter("account == %@", account)
                realm.delete(result)
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }
    
    func getAccounts() -> [String]? {

        let realm = try! Realm()

        let results = realm.objects(tableAccount.self).sorted(byKeyPath: "account", ascending: true)

        if results.count > 0 {
            return Array(results.map { $0.account })
        }

        return nil
    }
    
    func getActiveAccount() -> tableAccount? {

        let realm = try! Realm()

        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return nil
        }

        return tableAccount.init(value: result)
    }
    
    @discardableResult
    func setActiveAccount(_ account: String) -> tableAccount? {

        let realm = try! Realm()
        var accountReturn = tableAccount()

        do {
            try realm.write {

                let results = realm.objects(tableAccount.self)
                for result in results {
                    if result.account == account {
                        result.active = true
                        accountReturn = result
                    } else {
                        result.active = false
                    }
                }
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
            return nil
        }

        return tableAccount.init(value: accountReturn)
    }
}
