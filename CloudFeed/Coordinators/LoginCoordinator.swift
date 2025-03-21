//
//  LoginCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/17/25.
//  Copyright © 2025 Angela Jarosz. All rights reserved.
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

class LoginCoordinator: Coordinator {
    
    let navigationController: UINavigationController
    let dataService: DataService
    
    init(navigationController: UINavigationController, dataService: DataService) {
        self.navigationController = navigationController
        self.dataService = dataService
    }
    
    func start() {
        
    }
    
    func navigateToWebLogin(token: String, endpoint: String, login: String) {

    }
    
    func showInvalidURLPrompt() {
        let navController = getNavigationController()
        showErrorPrompt(message: Strings.UrlErrorMessage, navigationController: navController)
    }
    
    func showUnsupportedVersionErrorPrompt() {
        let navController = getNavigationController()
        showErrorPrompt(message: Strings.LoginUnsupportedVersionErrorMessage, navigationController: navController)
    }
    
    func showServerConnectionErrorPrompt() {
        let navController = getNavigationController()
        showErrorPrompt(message: Strings.LoginServerConnectionErrorMessage, navigationController: navController)
    }
    
    func showUntrustedWarningPrompt(host: String) {

        let navController = getNavigationController()
        let alertController = UIAlertController(title: Strings.LoginUntrustedServer, message: Strings.LoginUntrustedServerContinue, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.YesAction, style: .default, handler: { [weak self] _ in
            self?.dataService.writeCertificate(host: host)
        }))
        
        alertController.addAction(UIAlertAction(title: Strings.NoAction, style: .default, handler: { _ in }))
                            
        alertController.addAction(UIAlertAction(title: Strings.LoginViewCertificate, style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.showCertificate(host: host, certificateDirectory: self.dataService.store.certificatesDirectory, navigationController: navController, delegate: self)
        }))
        
        navController.present(alertController, animated: true)
    }
    
    func showInitFailedPrompt() {
        
        let navController = getNavigationController()
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.InitErrorMessage, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            navController.popViewController(animated: true)
        }))

        navController.present(alertController, animated: true)
    }
    
    private func showCertificateDisplayError() {
        let navController = getNavigationController()
        navController.presentedViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.showErrorPrompt(message: Strings.LoginViewCertificateError, navigationController: navController)
        })
    }
    
    private func getNavigationController() -> UINavigationController {
        if let navController = navigationController.presentedViewController as? UINavigationController {
            return navController
        } else {
            return navigationController
        }
    }
}

extension LoginCoordinator: CertificateDelegate {
    
    nonisolated func certificateDisplayError() {
        DispatchQueue.main.async { [weak self] in
            self?.showCertificateDisplayError()
        }
    }
}
