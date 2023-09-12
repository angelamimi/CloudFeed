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
    
    init(window: UIWindow) {
        self.window = window
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
        navigate(to: LoginWebCoordinator(window: window, navigationController: navigationController, url: url))
    }
    
    func showInvalidURLPrompt() {
        let alertController = UIAlertController(title: "Error", message: "Failed to load URL. Please try again.", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
}
