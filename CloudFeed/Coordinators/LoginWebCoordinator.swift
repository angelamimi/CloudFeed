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
    private let dataService: DataService
    
    init(window: UIWindow, navigationController: UINavigationController, dataService: DataService, url: String) {
        self.window = window
        self.navigationController = navigationController
        self.dataService = dataService
        self.url = url
    }
    
    func start() {
        let loginController = UIStoryboard(name: "Login", bundle: nil).instantiateViewController(identifier: "LoginWebController") as! LoginWebController
        loginController.setURL(url: url)
        loginController.coordinator = self
        loginController.viewModel = LoginViewModel(delegate: loginController, dataService: dataService)
        self.navigationController.pushViewController(loginController, animated: true)
    }
}

extension LoginWebCoordinator {
    
    func handleLoginSuccess(account: String, urlBase: String, user: String, userId: String, password: String) {

        navigationController.setViewControllers([], animated: false)
        
        if Environment.current.setCurrentUser(account: account, urlBase: urlBase, user: user, userId: userId) {
            dataService.setup(account: account, user: user, userId: userId, password: StoreUtility.getPassword(account), urlBase: urlBase)
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
