//
//  AppDelegate.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import NextcloudKit
import os.log
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var account: String = ""
    var urlBase: String = ""
    var user: String = ""
    var userId: String = ""
    var password: String = ""

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: AppDelegate.self)
    )

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        StoreUtility.initStorage()
        
        return true
    }
    
    func onApplicationStart() {
        
        // LOG Account
        if let activeAccount = DatabaseManager.shared.getActiveAccount() {
            NKCommon.shared.writeLog("Active Account: \(activeAccount.account)")
            
            if StoreUtility.getPassword(activeAccount.account).isEmpty {
                NKCommon.shared.writeLog("[ERROR] PASSWORD NOT FOUND for \(activeAccount.account)")
            }
            
            activateServiceForAccount(activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId, password: StoreUtility.getPassword(activeAccount.account))
        }
        
        Self.logger.debug("onApplicationStart() - account: \(self.account)")
        
        if self.account == "" {
            displayLogin()
        }
    }
    
    func launchApp() {
        guard let scene = UIApplication.shared.connectedScenes.first,
              let sceneDeleate = scene.delegate as? SceneDelegate else {
            return
        }
        
        Self.logger.debug("launchApp()")
        
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        
        sceneDeleate.window?.rootViewController = viewController
        sceneDeleate.window?.makeKeyAndVisible()
    }
    
    func activateServiceForAccount(_ account: String, urlBase: String, user: String, userId: String, password: String) {
        
        let currentAccount = self.account + "/" + self.userId
        let testAccount = account +  "/" + userId
        
        self.account = account
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        self.password = password
        
        Self.logger.debug("activateAccount() - account: \(account) urlBase: \(urlBase) user \(user) userId \(userId)")
        
        DispatchQueue.main.async{
            if UIApplication.shared.applicationState != .background && currentAccount != testAccount {
                NextcloudService.shared.initService(account: account, urlBase: urlBase, user: user, userId: userId, password: password)
            }
        }
    }
    
    private func displayLogin() {
        
        Self.logger.debug("displayLogin()")
        
        //TODO: TEST LOGIN ON DEVICE. CLOSE AND REOPEN.
        let loginController = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController()
        showViewController(loginController)
    }
    
    private func showViewController(_ viewController: UIViewController?) {
        
        guard let scene = UIApplication.shared.connectedScenes.first,
              let sceneDeleate = scene.delegate as? SceneDelegate else {
            return
        }
        
        if let viewController = viewController {
            Self.logger.debug("showLoginViewController() - setting root view controller")
            sceneDeleate.window?.rootViewController = viewController
        }
    }
}

