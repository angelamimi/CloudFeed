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

    private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: DatabaseManager.self)
        )
    
    func setup() {
        
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
                NextcloudKit.shared.nkCommonInstance.writeLog("DATABASE FOUND in " + databaseFilePath)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("DATABASE NOT FOUND in " + databaseFilePath)
            }
        }
        
        //Self.logger.debug("init() - databaseFileUrlPath: \(databaseFileUrlPath?.path ?? "NIL PATH")")
        
        let config = Realm.Configuration(
            fileURL: databaseFileUrlPath,
            schemaVersion: Global.shared.databaseSchemaVersion
        )

        Realm.Configuration.defaultConfiguration = config
        
        //Self.logger.debug("init() - Realm configuration: \(Realm.Configuration.defaultConfiguration)")
        
        // Verify db. if corrupt, remove it
        do {
            _ = try Realm()
        } catch {
            if let databaseFileUrlPath = databaseFileUrlPath {
                do {
                    //TODO: Show error?
                    NextcloudKit.shared.nkCommonInstance.writeLog("DATABASE CORRUPT: removed")
                    try FileManager.default.removeItem(at: databaseFileUrlPath)
                } catch {}
            }
        }

        //Open
        _ = try! Realm()
    }
    
    // MARK: -
    // MARK: Capabilities
    func addCapabilitiesJSon(account: String, data: Data) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                let addObject = tableCapabilities()
                
                addObject.account = account
                addObject.jsondata = data
                
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
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
    // MARK: Avatar
    func addAvatar(fileName: String, etag: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                // Add new
                let addObject = tableAvatar()
                
                addObject.date = NSDate()
                addObject.etag = etag
                addObject.fileName = fileName
                addObject.loaded = true
                
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
    
    func getAvatar(fileName: String) -> tableAvatar? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first else {
            return nil
        }
        
        return tableAvatar.init(value: result)
    }
    
    func getAvatarImage(fileName: String) -> UIImage? {
        
        let realm = try! Realm()
        let fileNameLocalPath = String(StoreUtility.getDirectoryUserData()) + "/" + fileName
        
        let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first
        if result == nil {
            FileSystemUtility.shared.deleteFile(filePath: fileNameLocalPath)
            return nil
        } else if result?.loaded == false {
            return nil
        }
        
        return UIImage(contentsOfFile: fileNameLocalPath)
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
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
    
    func clearDatabase(account: String?, removeAccount: Bool) {
        
        self.clearTable(tableAvatar.self)
        self.clearTable(tableCapabilities.self, account: account)
        self.clearTable(tableLocalFile.self, account: account)
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
