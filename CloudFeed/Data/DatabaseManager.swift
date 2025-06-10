//
//  DatabaseManager.swift
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

import NextcloudKit
import os.log
import RealmSwift
import SwiftData
import UIKit

@ModelActor
actor DatabaseManager: Sendable {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DatabaseManager.self)
    )

    static var test: ModelContainer {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: AccountModel.self, MetadataModel.self, AvatarModel.self, configurations: config)
            return container
        } catch {
            fatalError("Failed to create container.")
        }
    }
    
    static func modelConainerWithURL(_ url: URL) -> ModelContainer {
        
        do {
            let config = ModelConfiguration(url: url)
            let container = try ModelContainer(for: AccountModel.self, MetadataModel.self, AvatarModel.self, configurations: config)
            return container
        } catch {
            fatalError("Failed to create container.")
        }
    }
    
    /*func setup(fileUrl: URL) -> Bool {
        
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
    }*/
    
    /*func setup(identifier: String) -> Bool {
        
        let config = Realm.Configuration(inMemoryIdentifier: identifier, migrationBlock: nil)
        
        Realm.Configuration.defaultConfiguration = config
        Logger.shared.level = .warn
        
        return true
    }*/

    
    func clearDatabase(account: String?, removeAccount: Bool) {
        
        //try? modelContext.delete(model: AvatarModel.self)
        //deleteMetadata(account)
        
        if removeAccount && account != nil {
            self.deleteAccount(account!)
        }
    }
    
    func clearDatabase() {
        
        do {
            try modelContext.delete(model: AccountModel.self)
            //try modelContext.delete(MetadataModel.self)
            //try modelContext.delete(AvatarModel.self)
        } catch {
            Self.logger.error("Failed to clear database")
        }
    }
}
