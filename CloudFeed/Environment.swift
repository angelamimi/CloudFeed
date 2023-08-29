//
//  Environment.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/23/23.
//

import Foundation

public class Environment: NSObject {
    
    static private(set) var current = Environment()
    
    let nextcloudService: NextcloudKitServiceProtocol
    let databaseManager: DatabaseManager
    let dataService: DataService
    
    var currentUser: UserAccount? = nil
    
    public override init() {
        self.nextcloudService = NextcloudKitService()
        self.databaseManager = DatabaseManager()
        self.dataService = DataService(nextcloudService: self.nextcloudService, databaseManager: self.databaseManager)
        super.init()
    }
    
    func initCurrentUser(account: String? = nil, urlBase: String? = nil, user: String? = nil, userId: String? = nil) {
        self.currentUser = UserAccount(account: account, urlBase: urlBase, user: user, userId: userId)
    }
    
    func isCurrentUser(account: String, userId: String) -> Bool {
        guard currentUser != nil else { return false }
        return currentUser!.account == account && currentUser!.userId == userId
    }
    
    func initServicesFor(account: String, urlBase: String, user: String, userId: String, password: String) {
        if !isCurrentUser(account: account, userId: userId) {
            initCurrentUser(account: account, urlBase: urlBase, user: user, userId: userId)
            dataService.initServices(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
        }
    }
}
