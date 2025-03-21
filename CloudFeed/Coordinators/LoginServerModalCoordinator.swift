//
//  LoginServerModalCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/18/25.
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

import UIKit

@MainActor
protocol UserDelegate: AnyObject {
    func currentUserChanged()
}

final class LoginServerModalCoordinator : LoginCoordinator {
    
    weak var delegate: UserDelegate?
    
    override func start() {
        
        let loginNavigationController = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let loginServerController = loginNavigationController.viewControllers[0] as! LoginServerController
        
        loginServerController.viewModel = LoginServerViewModel(dataService: dataService)
        loginServerController.coordinator = self

        loginNavigationController.modalPresentationStyle = .fullScreen
        
        navigationController.present(loginNavigationController, animated: true)
    }
    
    override func navigateToWebLogin(token: String, endpoint: String, login: String) {
        let loginNavigationController = navigationController.presentedViewController as! UINavigationController
        let coordinator = LoginWebCoordinator(delegate: self, navigationController: loginNavigationController, dataService: dataService, token: token, endpoint: endpoint, login: login)
        coordinator.start()
    }
    
    func handleLoginSuccess(account: String, urlBase: String, user: String, userId: String, password: String) {
        delegate?.currentUserChanged()
        navigationController.dismiss(animated: true)
    }
}

extension LoginServerModalCoordinator: LoginDelegate {
    
    func loginSuccess(account: String, urlBase: String, user: String, userId: String, password: String) {
        handleLoginSuccess(account: account, urlBase: urlBase, user: user, userId: userId, password: password)
    }
    
    func loginError() {
        showInitFailedPrompt()
    }
}
