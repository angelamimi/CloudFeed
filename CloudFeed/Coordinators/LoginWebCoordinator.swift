//
//  LoginWebCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/3/23.
//

import UIKit

final class LoginWebCoordinator : Coordinator {
    
    private let window: UIWindow
    private let navigationController: UINavigationController
    private let url: String
    
    init(window: UIWindow, navigationController: UINavigationController, url: String) {
        self.window = window
        self.navigationController = navigationController
        self.url = url
    }
    
    func start() {
        let loginController = UIStoryboard(name: "Login", bundle: nil).instantiateViewController(identifier: "LoginWebController") as! LoginWebController
        loginController.setURL(url: url)
        loginController.coordinator = self
        loginController.viewModel = LoginViewModel(delegate: loginController)
        self.navigationController.pushViewController(loginController, animated: true)
    }
}

extension LoginWebCoordinator {
    
    func handleLoginSuccess() {

        navigationController.setViewControllers([], animated: false)
        
        let mainCoordinator = MainCoordinator(window: window)
        mainCoordinator.start()
    }
    
    func showInitFailedPrompt() {
        let alertController = UIAlertController(title: "Error", message: "Initialization failed. Please try again.", preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))

        navigationController.present(alertController, animated: true)
    }
    
    func showInvalidURLPrompt() {
        let alertController = UIAlertController(title: "Error", message: "Failed to load URL. Please try again.", preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))

        navigationController.present(alertController, animated: true)
    }
}
