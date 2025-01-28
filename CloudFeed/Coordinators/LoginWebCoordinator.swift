//
//  LoginWebCoordinator.swift
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

final class LoginWebCoordinator : NSObject, Coordinator {
    
    private let window: UIWindow
    private let navigationController: UINavigationController
    private let dataService: DataService
    
    private let token: String
    private let endpoint: String
    private let login: String
    
    init(window: UIWindow, navigationController: UINavigationController, dataService: DataService, token: String, endpoint: String, login: String) {
        self.window = window
        self.navigationController = navigationController
        self.dataService = dataService
        self.token = token
        self.endpoint = endpoint
        self.login = login
    }
    
    func start() {

        let controller = UIStoryboard(name: "Login", bundle: nil).instantiateViewController(identifier: "LoginPollController") as! LoginPollController

        controller.token = token
        controller.endpoint = endpoint
        controller.login = login
        controller.coordinator = self
        controller.viewModel = LoginViewModel(delegate: controller, dataService: dataService)
        
        navigationController.pushViewController(controller, animated: true)
    }
}

extension LoginWebCoordinator {
    
    func handleLoginSuccess(account: String, urlBase: String, user: String, userId: String, password: String) {

        navigationController.setViewControllers([], animated: false)
        
        if Environment.current.setCurrentUser(account: account, urlBase: urlBase, user: user, userId: userId) {
            dataService.setup(account: account, user: user, userId: userId, urlBase: urlBase)
        }
        
        if let currentUser = Environment.current.currentUser {
            dataService.appendSession(userAccount: currentUser)
        }
        
        let mainCoordinator = MainCoordinator(window: window, dataService: dataService)
        mainCoordinator.start()
    }
    
    func showInitFailedPrompt() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.InitErrorMessage, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))

        navigationController.present(alertController, animated: true)
    }
    
    func showInvalidURLPrompt() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.UrlErrorMessage, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))

        navigationController.present(alertController, animated: true)
    }
}
