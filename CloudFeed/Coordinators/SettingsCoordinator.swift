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
        let alertController = UIAlertController(title: "Error", message: "Failed to load Profile.", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
    
    func checkReset(reset: @escaping () -> Void) {
        let alert = UIAlertController(title: "Reset Application", message: "Are you sure you want to reset? This cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        /*alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { (_: UIAlertAction!) in
            self.reset()
        }))*/
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { _ in
            reset()
        }))
        navigationController.present(alert, animated: true)
    }
}
