//
//  UserAccount.swift
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


public struct UserAccount {
    
    public var account: String
    public var urlBase: String
    public var user: String
    public var userId: String
    
    init(account: String, urlBase: String, user: String, userId: String) {
        self.account = account
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
    }
}
