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
