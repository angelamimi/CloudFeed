//
//  MockDatabaseManager.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/18/23.
//

@testable import CloudFeed
import Foundation
import RealmSwift

class MockDatabaseManager: DatabaseManager {
    
    override init() {
        
        Realm.Configuration.defaultConfiguration.inMemoryIdentifier = "MockDatabase"
        
        do {
            _ = try Realm()
        } catch {
            print("Error opening mock db")
        }
    }
}
