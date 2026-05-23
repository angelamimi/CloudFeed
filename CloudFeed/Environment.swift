//
//  Environment.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/23/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
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

import Foundation

@MainActor
public class Environment: NSObject {
    
    static let current = Environment()
    
    var currentUser: UserAccount? = nil
    var currentServer: Server? = nil
    
    func setCurrentUser(account: String, user: String, userId: String)  {
        if !isCurrentUser(account: account, userId: userId) {
            currentUser = UserAccount(account: account, user: user, userId: userId)
        }
    }
    
    func setCurrentServer(urlBase: String, version: String) {
        currentServer = Server(urlBase: urlBase, version: version)
    }
    
    func isCurrentUser(account: String, userId: String) -> Bool {
        guard currentUser != nil else { return false }
        return currentUser!.account == account && currentUser!.userId == userId
    }
    
    func clear() {
        currentUser = nil
        currentServer = nil
    }
}

public struct UserAccount: Sendable {
    
    public let account: String
    public let user: String
    public let userId: String
    
    init(account: String, user: String, userId: String) {
        self.account = account
        self.user = user
        self.userId = userId
    }
}

public struct Server: Sendable {
    
    public let urlBase: String
    public let version: String
    
    init(urlBase: String, version: String) {
        self.urlBase = urlBase
        self.version = version
    }
}
