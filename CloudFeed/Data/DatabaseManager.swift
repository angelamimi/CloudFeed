//
//  DatabaseManager.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import NextcloudKit
import os.log
import RealmSwift
import SwiftyJSON
import UIKit

class DatabaseManager: NSObject {
    static let shared: DatabaseManager = {
        let instance = DatabaseManager()
        return instance
    }()
    
    private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: DatabaseManager.self)
        )
    
    override init() {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Global.shared.groupIdentifier)
        let databaseFileUrlPath = dirGroup?.appendingPathComponent(Global.shared.databaseDirectory + "/" + Global.shared.databaseDefault)
        
        // Disable file protection for directory DB
        // https://docs.mongodb.com/realm/sdk/ios/examples/configure-and-open-a-realm/#std-label-ios-open-a-local-realm
        if let folderPathURL = dirGroup?.appendingPathComponent(Global.shared.databaseDirectory) {
            let folderPath = folderPathURL.path
            do {
                try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: folderPath)
            } catch {
                Self.logger.error("FATAL ERROR for path: \(folderPath)")
            }
        }
        
        if let databaseFilePath = databaseFileUrlPath?.path {
            if FileManager.default.fileExists(atPath: databaseFilePath) {
                NKCommon.shared.writeLog("DATABASE FOUND in " + databaseFilePath)
            } else {
                NKCommon.shared.writeLog("DATABASE NOT FOUND in " + databaseFilePath)
            }
        }
        
        Self.logger.debug("init() - databaseFileUrlPath: \(databaseFileUrlPath?.path ?? "NIL PATH")")
        
        let config = Realm.Configuration(
            fileURL: databaseFileUrlPath,
            schemaVersion: Global.shared.databaseSchemaVersion
        )

        Realm.Configuration.defaultConfiguration = config
        
        Self.logger.debug("init() - Realm configuration: \(Realm.Configuration.defaultConfiguration)")
        
        // Verify Database, if corrupt remove it
        do {
            _ = try Realm()
        } catch {
            if let databaseFileUrlPath = databaseFileUrlPath {
                do {
                    //TODO: Present error
                    //let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_database_corrupt_")
                    //NCContentPresenter.shared.showError(error: error, priority: .max)

                    NKCommon.shared.writeLog("DATABASE CORRUPT: removed")
                    try FileManager.default.removeItem(at: databaseFileUrlPath)
                } catch {}
            }
        }

        // Open Real
        _ = try! Realm()
    }
    
    // MARK: -
    // MARK: Capabilities
    
    func addCapabilitiesJSon(_ data: Data, account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                let addObject = tableCapabilities()
                
                addObject.account = account
                addObject.jsondata = data
                
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    func getCapabilitiesServerInt(account: String, elements: [String]) -> Int {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first,
              let jsondata = result.jsondata else {
            return 0
        }
        
        let json = JSON(jsondata)
        return json[elements].intValue
    }
    
    
    // MARK: -
    // MARK: Database Management
    func clearTable(_ table: Object.Type, account: String? = nil) {

        let realm = try! Realm()

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
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    func clearDatabase(account: String?, removeAccount: Bool) {
        
        //self.clearTable(tableAvatar.self)
        self.clearTable(tableCapabilities.self, account: account)
        //self.clearTable(tableDirectory.self, account: account)
        //self.clearTable(tableE2eEncryption.self, account: account)
        //self.clearTable(tableE2eEncryptionLock.self, account: account)
        self.clearTable(tableLocalFile.self, account: account)
        self.clearTable(tableMetadata.self, account: account)
        
        if removeAccount {
            self.clearTable(tableAccount.self, account: account)
        }
    }
}
