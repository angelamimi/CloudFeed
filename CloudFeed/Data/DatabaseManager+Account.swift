//
//  DatabaseManager+Account.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//

import Foundation
import RealmSwift
import NextcloudKit

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
    
    func addAccount(_ account: String, urlBase: String, user: String, password: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableAccount()

                addObject.account = account

                StoreUtility.setPassword(account, password: password)

                addObject.urlBase = urlBase
                addObject.user = user
                addObject.userId = user

                realm.add(addObject, update: .all)
            }
        } catch let error {
            //NKCommon.shared.writeLog("Could not write to database: \(error)")
            print("Could not write to database: \(error)")
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
            //NKCommon.shared.writeLog("Could not write to database: \(error)")
            print("Could not write to database: \(error)")
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
            //NKCommon.shared.writeLog("Could not write to database: \(error)")
            print("Could not write to database: \(error)")
            return nil
        }

        return tableAccount.init(value: accountReturn)
    }
}
