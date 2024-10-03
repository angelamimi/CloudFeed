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

final class LoginServerCoordinator : NSObject, Coordinator {
    
    private let window: UIWindow
    private let navigationController: UINavigationController
    private let dataService: DataService
    
    init(window: UIWindow, dataService: DataService) {
        self.window = window
        self.dataService = dataService
        self.navigationController = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController() as! UINavigationController
    }
    
    func start() {
        
        //LoginServerController is presented by the storyboard
        let loginServerController = navigationController.viewControllers[0] as! LoginServerController
        loginServerController.coordinator = self
        
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }
    
    func navigateToWebLogin(url: String) {
        let coordinator = LoginWebCoordinator(window: window, navigationController: navigationController, dataService: dataService, url: url)
        navigate(to: coordinator)
    }
    
    func showInvalidURLPrompt() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.UrlErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
}
