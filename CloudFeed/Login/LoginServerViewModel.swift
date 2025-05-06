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
    let coordinator: LoginCoordinator
    
    init(dataService: DataService, coordinator: LoginCoordinator) {
        self.dataService = dataService
        self.coordinator = coordinator
    }
    
    func showInvalidURLPrompt() {
        coordinator.showInvalidURLPrompt()
    }
    
    func showUnsupportedVersionErrorPrompt() {
        coordinator.showUnsupportedVersionErrorPrompt()
    }
    
    func showUntrustedWarningPrompt(host: String) {
        coordinator.showUntrustedWarningPrompt(host: host)
    }
    
    func showServerConnectionErrorPrompt() {
        coordinator.showServerConnectionErrorPrompt()
    }
    
    func navigateToWebLogin(token: String, endpoint: String, login: String) {
        coordinator.navigateToWebLogin(token: token, endpoint: endpoint, login: login)
    }
    
    func beginLoginFlow(url: String) async -> (token: String, endpoint: String, login: String, supported: Bool, errorCode: Int?)? {
        
        let result = await dataService.checkServerStatus(url: url)
        
        if let serverVersion = result.serverVersion {
            
            if serverVersion < Global.shared.minimumServerVersion {
                return (token: "", endpoint: "", login: "", supported: false, errorCode: nil)
            } else if let loginResult = await dataService.getLoginFlowV2(url: url, serverVersion: serverVersion) {
                return (token: loginResult.token, endpoint: loginResult.endpoint, login: loginResult.login, supported: true, errorCode: nil)
            }
            
        } else if let errorCode = result.errorCode {
            return (token: "", endpoint: "", login: "", supported: true, errorCode: errorCode)
        }
        
        return nil
    }
}

