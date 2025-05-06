//
//  LoginServerCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/3/23.
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

import UIKit

final class LoginServerCoordinator : LoginCoordinator {
    
    private let window: UIWindow
    
    init(window: UIWindow, dataService: DataService) {
        
        let navigationController = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController() as! UINavigationController
        
        self.window = window
        
        super.init(navigationController: navigationController, dataService: dataService)
    }
    
    override func start() {

        let loginServerController = navigationController.viewControllers[0] as! LoginServerController
        
        loginServerController.viewModel = LoginServerViewModel(dataService: dataService, coordinator: self)

        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }
    
    override func navigateToWebLogin(token: String, endpoint: String, login: String) {
        let coordinator = LoginWebCoordinator(delegate: self, navigationController: navigationController, dataService: dataService, token: token, endpoint: endpoint, login: login)
        coordinator.start()
    }
    
    func handleLoginSuccess(account: String, urlBase: String, user: String, userId: String, password: String) {

        navigationController.setViewControllers([], animated: false)
        
        let mainCoordinator = MainCoordinator(window: window, dataService: dataService)
        mainCoordinator.start()
    }
}

extension LoginServerCoordinator: LoginDelegate {
    
    func loginSuccess(account: String, urlBase: String, user: String, userId: String, password: String) {
        handleLoginSuccess(account: account, urlBase: urlBase, user: user, userId: userId, password: password)
    }
    
    func loginError() {
        showInitFailedPrompt()
    }
}
