//
//  LoginServerViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 1/2/25.
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

import os.log
import UIKit

@MainActor
final class LoginServerViewModel: NSObject {
    
    let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
    }
    
    func beginLoginFlow(url: String) async -> (token: String, endpoint: String, login: String, error: Bool)? {
            
        let result = await dataService.getLoginFlowV2(url: url)
        
        if result == nil {
            return nil //failed to connect to server at all
        } else if result!.serverVersion < Global.shared.minimumServerVersion { 
            return (token: "", endpoint: "", login: "", error: true)
        } else {
            return (token: result!.token, endpoint: result!.endpoint, login: result!.login, error: false)
        }
    }
}

