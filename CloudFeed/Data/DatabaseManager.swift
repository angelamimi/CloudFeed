//
//  DatabaseManager.swift
//  CloudFeed
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import NextcloudKit
import os.log
import RealmSwift
import UIKit


final class DatabaseManager: Sendable {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DatabaseManager.self)
    )
    
    func setup(fileUrl: URL) -> Bool {
        
        let config = Realm.Configuration(fileURL: fileUrl, schemaVersion: 3)
        
        Realm.Configuration.defaultConfiguration = config
        
        if ProcessInfo.processInfo.environment["XCInjectBundleInto"] == nil {
            let path = fileUrl.path
            if FileManager.default.fileExists(atPath: path) {
                NextcloudKit.shared.nkCommonInstance.writeLog("DATABASE FOUND in " + path)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("DATABASE NOT FOUND in " + path)
            }
        }
        
        do {
            _ = try Realm()
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not open database: \(error)")
            return true
        }
        
        return false
    }
    
    func setup(identifier: String) -> Bool {
        
        let config = Realm.Configuration(inMemoryIdentifier: identifier, migrationBlock: nil)
        
        Realm.Configuration.defaultConfiguration = config
        Logger.shared.level = .warn
        
        return true
    }
    
    func clearTable(_ table: Object.Type, account: String? = nil) {

        guard let realm = try? Realm() else { return }

        do {
            
            try realm.write {
                var results: Results<Object>

                if let account = account {
                    results = realm.objects(table).filter("account == %@", account)
                } else {
                    results = realm.objects(table)
                }

                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
    
    func clearDatabase(account: String?, removeAccount: Bool) {
        
        self.clearTable(tableAvatar.self)
        self.clearTable(tableMetadata.self, account: account)
        
        if removeAccount {
            self.clearTable(tableAccount.self, account: account)
        }
    }
    
    func removeDatabase() {
        let realmURL = Realm.Configuration.defaultConfiguration.fileURL!
        let realmURLs = [
            realmURL,
            realmURL.appendingPathExtension("lock"),
            realmURL.appendingPathExtension("note"),
            realmURL.appendingPathExtension("management")
        ]
        for URL in realmURLs {
            do {
                try FileManager.default.removeItem(at: URL)
            } catch let error {
                NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
            }
        }
    }
}
