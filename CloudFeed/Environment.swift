//
//  Environment.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/23/23.
//

import Foundation

public class Environment: NSObject {
    
    static let current = Environment()
    
    var currentUser: UserAccount? = nil
    
    func setCurrentUser(account: String? = nil, urlBase: String? = nil, user: String? = nil, userId: String? = nil) -> Bool {
        
        guard account != nil && userId != nil else {
            return false
        }
        
        if isCurrentUser(account: account!, userId: userId!) {
            return false
        } else {
            self.currentUser = UserAccount(account: account, urlBase: urlBase, user: user, userId: userId)
            return true
        }
        
    }
    
    func isCurrentUser(account: String, userId: String) -> Bool {
        guard currentUser != nil else { return false }
        return currentUser!.account == account && currentUser!.userId == userId
    }
}
