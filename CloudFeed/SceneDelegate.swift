//
//  SceneDelegate.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let _ = (scene as? UIWindowScene) else { return }
        
        //let appDelegate = UIApplication.shared.delegate as! AppDelegate
        //appDelegate.onApplicationStart()
        
        if let activeAccount = Environment.current.dataService.getActiveAccount() {
            //NKCommon.shared.writeLog("Active Account: \(activeAccount.account)")
            
            if StoreUtility.getPassword(activeAccount.account).isEmpty {
                //NKCommon.shared.writeLog("[ERROR] PASSWORD NOT FOUND for \(activeAccount.account)")
            }
            
            //activateServiceForAccount(account: activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId, password: StoreUtility.getPassword(activeAccount.account))
            Environment.current.initServicesFor(account: activeAccount.account,
                                                urlBase: activeAccount.urlBase,
                                                user: activeAccount.user,
                                                userId: activeAccount.userId,
                                                password: StoreUtility.getPassword(activeAccount.account))
        }
        
        if Environment.current.currentUser == nil {
            let navController = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController()
            self.window?.rootViewController = navController
        }
    }

}

