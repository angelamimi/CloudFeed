//
//  AppCoordinator.swift
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

final class AppCoordinator: NSObject, Coordinator {
    
    let window: UIWindow
    var dataService: DataService?
    var mainCoordinator: MainCoordinator?
    var actionURL: URL?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        
        let store = StoreUtility()
        
        guard let certificatesDirectory = store.certificatesDirectory else {
            showInitFailedError()
            return
        }
        
        guard let dbUrl = store.databaseDirectory?.appending(path: Global.shared.database) else {
            showInitFailedError()
            return
        }
        
        let container = DatabaseManager.urlContainer(dbUrl)
        let dbManager = DatabaseManager(modelContainer: container)
        let nextcloudService = NextcloudKitService(certificatesDirectory: certificatesDirectory, delegate: self)
        
        dataService = DataService(store: store, nextcloudService: nextcloudService, databaseManager: dbManager)
        
        if let dataService = self.dataService {
            
            dataService.setup()
        
            Task { [weak self] in
                
                if let activeAccount = await dataService.getActiveAccount() {
                    Environment.current.setCurrentUser(account: activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId)
                } else {
                    store.deleteAllChainStore() //no account. make sure keychain is clear
                }

                if Environment.current.currentUser != nil {
                    await self?.startMainCoordinator(unlock: false)
                } else if let window = self?.window {
                    let loginServerCoordinator = LoginServerCoordinator(window: window, dataService: dataService)
                    loginServerCoordinator.delegate = self
                    loginServerCoordinator.start()
                }
            }
        }
    }
    
    private func startMainCoordinator(unlock: Bool) async {
        
        guard dataService != nil else { return }
        
        if let style = dataService?.getDisplayStyle() {
            window.overrideUserInterfaceStyle = style
        }
        
        for acc in await dataService!.getAccountsOrdered() {
            await dataService?.appendSession(account: acc.account, user: acc.user, userId: acc.userId, urlBase: acc.urlBase)
        }
        
        if mainCoordinator == nil {
            mainCoordinator = MainCoordinator(window: window, dataService: dataService!)
            
            if let url = actionURL, let result = URLUtility.processActionURL(url: url) {
                actionURL = nil
                if result.action == Global.WidgetAction.viewFavorite.rawValue {
                    if let currentUser = Environment.current.currentUser, result.account == currentUser.account {
                        mainCoordinator?.setViewFavoriteImage(ocId: result.ocId)
                    }
                } else if result.action == Global.WidgetAction.viewImage.rawValue {
                    if let currentUser = Environment.current.currentUser, result.account == currentUser.account {
                        mainCoordinator?.setViewImage(ocId: result.ocId)
                    }
                }
            }
        }

        mainCoordinator?.start()
        
        if !unlock && requiresPasscode(controller: window.rootViewController) {
            return
        }
    }
    
    func requiresPasscode() -> Bool {
        if let user = Environment.current.currentUser, (dataService?.store.getPasscode(user.account)) != nil {
            return true
        } else {
            return false
        }
    }
    
    func requiresPasscode(controller: UIViewController? = nil) -> Bool {

        if let user = Environment.current.currentUser {
            
            if (dataService?.store.getPasscode(user.account)) != nil && mainCoordinator != nil {
                
                let passcodeController = UIStoryboard(name: "Passcode", bundle: nil).instantiateViewController(identifier: "PasscodeController") as PasscodeController
                
                passcodeController.viewModel = PasscodeViewModel(coordinator: nil, dataService: dataService!, resetDelegate: mainCoordinator!)
                passcodeController.mode = .unlock
                passcodeController.delegate = self
                passcodeController.modalPresentationStyle = .overCurrentContext
                
                if #available(iOS 18.0, *) {
                    passcodeController.preferredTransition = .crossDissolve
                }
                
                if let showController = controller {
                    passcodeController.isModalInPresentation = true
                    showController.show(passcodeController, sender: self)
                } else {
                    let navigationController = UINavigationController(rootViewController: passcodeController)
                    window.rootViewController = navigationController
                    window.makeKeyAndVisible()
                }
                
                return true
            }
        }
        
        return false
    }
    
    func showInitFailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.InitErrorMessage, preferredStyle: .alert)
        let navigationController = UINavigationController()
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            navigationController.popViewController(animated: true)
            exit(0)
        }))
        
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        
        navigationController.present(alertController, animated: true)
    }
    
    func showUntrustedWarningPrompt(host: String) {
        
        guard let navigationController = getNavigationController() else { return }
        
        let alertController = UIAlertController(title: Strings.LoginUntrustedServerChanged, message: Strings.LoginUntrustedServerContinue, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.YesAction, style: .default, handler: { [weak self] _ in
            self?.dataService?.writeCertificate(host: host)
        }))
        
        alertController.addAction(UIAlertAction(title: Strings.NoAction, style: .default, handler: { _ in }))
                            
        alertController.addAction(UIAlertAction(title: Strings.LoginViewCertificate, style: .default, handler: { [weak self] _ in
            self?.showCertificate(host: host, certificateDirectory: self?.dataService?.store.certificatesDirectory, navigationController: navigationController, delegate: self)
        }))
        
        navigationController.present(alertController, animated: true)
    }
    
    func showServerError(error: Int) {
        switch error {
        case Global.shared.errorMaintenance:
            showMaintenanceError()
        default:
            break
        }
    }
    
    func viewFavorite(account: String, ocId: String) {
        if let currentUser = Environment.current.currentUser, account == currentUser.account {
            mainCoordinator?.viewFavorite(ocId: ocId)
        }
    }
    
    func viewImage(account: String, ocId: String) {
        if let currentUser = Environment.current.currentUser, account == currentUser.account {
            mainCoordinator?.viewImage(ocId: ocId)
        }
    }
    
    private func showMaintenanceError() {
        
        if let navigationController = getNavigationController() {
            
            let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.MaintenanceErrorMessage, preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
                navigationController.popViewController(animated: true)
            }))
            
            navigationController.present(alertController, animated: true)
        }
    }
    
    private func getNavigationController() -> UINavigationController? {
        
        if let tabs = window.rootViewController as? UITabBarController,
           let navigationController = tabs.selectedViewController as? UINavigationController,
           !(navigationController.visibleViewController is UIAlertController) {
            return navigationController
        }
        
        return nil
    }
    
    private func showCertificateDisplayError() {

        let navigationController = getNavigationController()
        
        navigationController?.presentedViewController?.dismiss(animated: true, completion: { [weak self] in
            if let nav = navigationController {
                self?.showErrorPrompt(message: Strings.LoginViewCertificateError, navigationController: nav)
            }
        })
    }
}

extension AppCoordinator: NextcloudKitServiceDelegate {

    nonisolated func serverStatusChanged(reachable: Bool) {
        //not implemented
    }
    
    nonisolated func serverError(error: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.showServerError(error: error)
        }
    }
    
    nonisolated func serverCertificateUntrusted(host: String) {
        DispatchQueue.main.async { [weak self] in
            self?.showUntrustedWarningPrompt(host: host)
        }
    }
}

extension AppCoordinator: CertificateDelegate {
    
    nonisolated func certificateDisplayError() {
        DispatchQueue.main.async { [weak self] in
            self?.showCertificateDisplayError()
        }
    }
}

extension AppCoordinator: PasscodeDelegate {

    func unlock() {
        if window.rootViewController is UITabBarController {
            window.rootViewController?.dismiss(animated: true, completion: { [weak self] in
                self?.mainCoordinator?.sync()
            })
        } else {
            Task { [weak self] in
                await self?.startMainCoordinator(unlock: true)
            }
        }
    }
}

extension AppCoordinator: LoginServerCoordinatorDelegate {
    
    func loginSuccess() {
        Task { [weak self] in
            await self?.startMainCoordinator(unlock: true)
        }
    }
}
