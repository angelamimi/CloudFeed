//
//  Environment.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/23/23.
//

import Foundation

public class Environment: NSObject {
    
    static let current = Environment()
    
    fileprivate(set) var nextcloudService: NextcloudKitServiceProtocol!
    fileprivate(set) var databaseManager: DatabaseManager!
    fileprivate(set) var dataService: DataService!
    
    var currentUser: UserAccount? = nil
    
    func initServicesFor(nextcloudService: NextcloudKitServiceProtocol, databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
        self.nextcloudService = nextcloudService
        self.dataService = DataService(nextcloudService: self.nextcloudService, databaseManager: self.databaseManager)
    }
    
    func initCurrentUser(account: String? = nil, urlBase: String? = nil, user: String? = nil, userId: String? = nil) {
        self.currentUser = UserAccount(account: account, urlBase: urlBase, user: user, userId: userId)
    }
    
    func isCurrentUser(account: String, userId: String) -> Bool {
        guard currentUser != nil else { return false }
        return currentUser!.account == account && currentUser!.userId == userId
    }
    
    func setupFor(account: String, urlBase: String, user: String, userId: String, password: String) {
        if !isCurrentUser(account: account, userId: userId) {
            initCurrentUser(account: account, urlBase: urlBase, user: user, userId: userId)
            dataService.setup(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
        }
    }
}
