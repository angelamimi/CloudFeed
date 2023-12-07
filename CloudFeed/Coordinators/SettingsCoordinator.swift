//
//  SettingsCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//

import UIKit

protocol CacheDelegate: AnyObject {
    func cacheCleared()
}

final class SettingsCoordinator {
    
    let navigationController: UINavigationController
    let cacheDelegate: CacheDelegate
    
    init(navigationController: UINavigationController, cacheDelegate: CacheDelegate) {
        self.navigationController = navigationController
        self.cacheDelegate = cacheDelegate
    }
    
    func cacheCleared() {
        cacheDelegate.cacheCleared()
    }
    
    func showAcknowledgements() {
        navigationController.pushViewController(AcknowledgementsController(), animated: true)
    }
    
    func showProfileLoadfailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.ProfileErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
    
    func checkReset(reset: @escaping () -> Void) {
        
        let alert = UIAlertController(title: Strings.ResetTitle, message: Strings.ResetMessage, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: Strings.CancelAction, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.ResetAction, style: .destructive, handler: { _ in
            reset()
        }))
        
        navigationController.present(alert, animated: true)
    }
}
