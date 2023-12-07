//
//  AppCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/3/23.
//

import UIKit

final class AppCoordinator: Coordinator {
    
    let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        
        let dbManager = DatabaseManager()
        dbManager.setup()
        
        let dataService = DataService(nextcloudService: NextcloudKitService(), databaseManager: dbManager)
        
        if let activeAccount = dataService.getActiveAccount() {
            if Environment.current.setCurrentUser(account: activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId) {
                dataService.setup(account: activeAccount.account, user: activeAccount.user, userId: activeAccount.userId, password: StoreUtility.getPassword(activeAccount.account), urlBase: activeAccount.urlBase)
            }
        }

        if Environment.current.currentUser == nil {
            let loginServerCoordinator = LoginServerCoordinator(window: window, dataService: dataService)
            loginServerCoordinator.start()
        } else {
            let mainCoordinator = MainCoordinator(window: window, dataService: dataService)
            mainCoordinator.start()
        }
    }
}
