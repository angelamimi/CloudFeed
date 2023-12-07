//
//  LoginServerCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/3/23.
//

import UIKit

final class LoginServerCoordinator : Coordinator {
    
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
