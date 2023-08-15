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

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: AppDelegate.self)
    )

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        initNavigationBar()
        
        StoreUtility.initStorage()
        
        return true
    }
    
    func onApplicationStart() {
        
        let nextcloudService = NextcloudKitService()
        let databaseManager = DatabaseManager()
        let dataService = DataService(nextcloudService: nextcloudService, databaseManager: databaseManager)
        
        if let activeAccount = dataService.getActiveAccount() {
            NKCommon.shared.writeLog("Active Account: \(activeAccount.account)")
            
            if StoreUtility.getPassword(activeAccount.account).isEmpty {
                NKCommon.shared.writeLog("[ERROR] PASSWORD NOT FOUND for \(activeAccount.account)")
            }
            
            activateServiceForAccount(dataService: dataService, account: activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId, password: StoreUtility.getPassword(activeAccount.account))
            
            
            guard let scene = UIApplication.shared.connectedScenes.first,
                    let sceneDeleate = scene.delegate as? SceneDelegate else {
                return
            }
            
            let tabBarController = sceneDeleate.window?.rootViewController as! UITabBarController
            
            inject(dataService, tabBarController: tabBarController)
        }
        
        Self.logger.debug("onApplicationStart() - account: \(self.account)")
        
        if self.account == "" {
            displayLogin(dataService: dataService)
        }
    }
    
    func launchApp(dataService: DataService) {
        guard let scene = UIApplication.shared.connectedScenes.first,
              let sceneDeleate = scene.delegate as? SceneDelegate else {
            return
        }
        
        Self.logger.debug("launchApp()")
        
        //TODO: REFACTOR! Test casting to tab bar controller and dependency injection
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as! UITabBarController
        
        inject(dataService, tabBarController: controller)
        
        sceneDeleate.window?.rootViewController = controller
        sceneDeleate.window?.makeKeyAndVisible()
    }
    
    private func inject(_ dataService: DataService, tabBarController : UITabBarController) {
        if tabBarController.viewControllers != nil {
            for tab in tabBarController.viewControllers! {
                if tab is UINavigationController {
                    let dataViewController = (tab as! UINavigationController).viewControllers[0] as? DataViewController
                    dataViewController?.setDataService(service: dataService)
                }
            }
        }
    }
    
    func activateServiceForAccount(dataService: DataService, account: String, urlBase: String, user: String, userId: String, password: String) {
        
        let currentAccount = self.account + "/" + self.userId
        let testAccount = account +  "/" + userId
        
        self.account = account
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        
        Self.logger.debug("activateAccount() - account: \(account) urlBase: \(urlBase) user \(user) userId \(userId)")
        
        /*if UIApplication.shared.applicationState != .background && currentAccount != testAccount {
            DispatchQueue.main.async{
                dataService.initServices(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
            }
        }*/
        
        if currentAccount != testAccount {
            dataService.initServices(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
        }
    }
    
    private func displayLogin(dataService: DataService) {
        
        Self.logger.debug("displayLogin()")
        
        //TODO: TEST LOGIN ON DEVICE. CLOSE AND REOPEN.
        
        let navController = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController()
        
        let loginServerController = UIStoryboard(name: "Login", bundle: nil).instantiateViewController(
            identifier: "LoginServerController",
            creator: { coder in
                LoginServerController(dataService: dataService, coder: coder)
            }
        )
        
        showViewController(navController)
        navController?.show(loginServerController, sender: nil)
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
    
    private func initNavigationBar() {
        let coloredAppearance = UINavigationBarAppearance()
        
        coloredAppearance.configureWithOpaqueBackground()
        coloredAppearance.backgroundColor = .systemBackground //.systemFill
        coloredAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
    }
}

