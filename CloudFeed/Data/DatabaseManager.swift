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
    
    func clearDatabase(account: String?, removeAccount: Bool) {
        
        do {
            try modelContext.delete(model: AvatarModel.self)
            
            if account != nil {
                deleteMetadata(account!)
                
                if removeAccount {
                    self.deleteAccount(account!)
                }
            }
        } catch {
            Self.logger.error("Failed to clear database")
        }
    }
    
    func clearDatabase() {
        
        do {
            try modelContext.delete(model: AccountModel.self)
            try modelContext.delete(model: MetadataModel.self)
            try modelContext.delete(model: AvatarModel.self)
        } catch {
            Self.logger.error("Failed to clear database")
        }
    }
}
