//
//  AppCoordinator.swift
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

final class AppCoordinator: NSObject, Coordinator {
    
    let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        
        let dbManager = DatabaseManager()
        let error = dbManager.setup()
        
        if error {
            showInitFailedError()
            return
        }
        
        let dataService = DataService(nextcloudService: NextcloudKitService(), databaseManager: dbManager)
        
        if let activeAccount = dataService.getActiveAccount() {
            if Environment.current.setCurrentUser(account: activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId) {
                dataService.setup(account: activeAccount.account, user: activeAccount.user, userId: activeAccount.userId, urlBase: activeAccount.urlBase)
            }
        }

        if Environment.current.currentUser == nil {
            let loginServerCoordinator = LoginServerCoordinator(window: window, dataService: dataService)
            loginServerCoordinator.start()
        } else {
            //let cache
            let mainCoordinator = MainCoordinator(window: window, dataService: dataService)
            mainCoordinator.start()
        }
    }
    
    func showInitFailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.InitErrorMessage, preferredStyle: .alert)
        let navigationController = UINavigationController()
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            navigationController.popViewController(animated: true)
            exit(0)
        }))
        
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        
        navigationController.present(alertController, animated: true)
    }
}
