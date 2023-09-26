//
//  MainCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//

import UIKit

final class MainCoordinator : Coordinator {
    
    private let window: UIWindow
    private let tabBarController: UITabBarController
    
    init(window: UIWindow, dataService: DataService) {
        
        self.window = window
        self.tabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as! UITabBarController
        
        initTabCoordinators(dataService: dataService)
    }
    
    func start() {
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}

extension MainCoordinator: CacheDelegate {
    
    func cacheCleared() {
        
        DispatchQueue.main.async {
            let mediaNavController = self.tabBarController.viewControllers?[0] as! UINavigationController
            let favoritesNavController = self.tabBarController.viewControllers?[1] as! UINavigationController
            
            let mediaViewController = mediaNavController.viewControllers[0] as! MediaController
            let favoritesViewController = favoritesNavController.viewControllers[0] as! FavoritesController
            
            mediaViewController.clear()
            favoritesViewController.clear()
        }
    }
}

extension MainCoordinator {
    
    private func initTabCoordinators(dataService: DataService) {
        
        guard tabBarController.viewControllers != nil && tabBarController.viewControllers?.count == 3 else { return }

        let mediaNavController = tabBarController.viewControllers?[0] as! UINavigationController
        let favoritesNavController = tabBarController.viewControllers?[1] as! UINavigationController
        let settingsNavController = tabBarController.viewControllers?[2] as! UINavigationController
        
        let mediaViewController = mediaNavController.viewControllers[0] as! MediaController
        let favoritesViewController = favoritesNavController.viewControllers[0] as! FavoritesController
        let settingsViewController = settingsNavController.viewControllers[0] as! SettingsController
        
        mediaViewController.coordinator = MediaCoordinator(navigationController: mediaNavController, dataService: dataService)
        favoritesViewController.coordinator = FavoritesCoordinator(navigationController: favoritesNavController, dataService: dataService)
        settingsViewController.coordinator = SettingsCoordinator(navigationController: settingsNavController, cacheDelegate: self)
        
        mediaViewController.viewModel = MediaViewModel(delegate: mediaViewController, dataService: dataService)
        favoritesViewController.viewModel = FavoritesViewModel(delegate: favoritesViewController, dataService: dataService)
        settingsViewController.viewModel = SettingsViewModel(delegate: settingsViewController, dataService: dataService)
    }
}
