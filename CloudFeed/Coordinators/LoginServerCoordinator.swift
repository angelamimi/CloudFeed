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
        
        loginServerController.viewModel = LoginServerViewModel(dataService: dataService)
        loginServerController.coordinator = self
        
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }
    
    func navigateToWebLogin(token: String, endpoint: String, login: String) {
        let coordinator = LoginWebCoordinator(window: window, navigationController: navigationController, dataService: dataService, token: token, endpoint: endpoint, login: login)
        coordinator.start()
    }
    
    func showInvalidURLPrompt() {
        showErrorPrompt(message: Strings.UrlErrorMessage, navigationController: navigationController)
    }
    
    func showUnsupportedVersionErrorPrompt() {
        showErrorPrompt(message: Strings.LoginUnsupportedVersionErrorMessage, navigationController: navigationController)
    }
    
    func showServerConnectionErrorPrompt() {
        showErrorPrompt(message: Strings.LoginServerConnectionErrorMessage, navigationController: navigationController)
    }
    
    func showUntrustedWarningPrompt(host: String) {
        
        let alertController = UIAlertController(title: Strings.LoginUntrustedServer, message: Strings.LoginUntrustedServerContinue, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.YesAction, style: .default, handler: { [weak self] _ in
            self?.dataService.writeCertificate(host: host)
        }))
        
        alertController.addAction(UIAlertAction(title: Strings.NoAction, style: .default, handler: { _ in }))
                            
        alertController.addAction(UIAlertAction(title: Strings.LoginViewCertificate, style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.showCertificate(host: host, certificateDirectory: self.dataService.store.certificatesDirectory, navigationController: self.navigationController, delegate: self)
        }))
        
        navigationController.present(alertController, animated: true)
    }
    
    private func showCertificateDisplayError() {
        navigationController.presentedViewController?.dismiss(animated: true, completion: { [weak self] in
            if let nav = self?.navigationController {
                self?.showErrorPrompt(message: Strings.LoginViewCertificateError, navigationController: nav)
            }
        })
    }
}

extension LoginServerCoordinator: CertificateDelegate {
    
    nonisolated func certificateDisplayError() {
        DispatchQueue.main.async { [weak self] in
            self?.showCertificateDisplayError()
        }
    }
}
