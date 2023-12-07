//
//  UserAccount.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/23/23.
//

import Foundation


public struct UserAccount {
    public var account: String?
    public var urlBase: String?
    public var user: String?
    public var userId: String?
    
    init(account: String? = nil, urlBase: String? = nil, user: String? = nil, userId: String? = nil) {
        self.account = account
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
    }
}
