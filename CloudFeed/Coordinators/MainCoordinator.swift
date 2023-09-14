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
    
    init(window: UIWindow) {
        self.window = window
        self.tabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as! UITabBarController
        
        initTabCoordinators()
    }
    
    func start() {
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}

extension MainCoordinator {
    
    private func initTabCoordinators() {
        
        guard tabBarController.viewControllers != nil && tabBarController.viewControllers?.count == 3 else { return }

        let mediaNavController = tabBarController.viewControllers?[0] as! UINavigationController
        let favoritesNavController = tabBarController.viewControllers?[1] as! UINavigationController
        let settingsNavController = tabBarController.viewControllers?[2] as! UINavigationController
        
        let mediaViewController = mediaNavController.viewControllers[0] as! MediaController
        let favoritesViewController = favoritesNavController.viewControllers[0] as! FavoritesController
        let settingsViewController = settingsNavController.viewControllers[0] as! SettingsController
        
        mediaViewController.coordinator = MediaCoordinator(navigationController: mediaNavController)
        favoritesViewController.coordinator = FavoritesCoordinator(navigationController: favoritesNavController)
        settingsViewController.coordinator = SettingsCoordinator(navigationController: settingsNavController)
        
        mediaViewController.viewModel = MediaViewModel(delegate: mediaViewController)
        favoritesViewController.viewModel = FavoritesViewModel(delegate: favoritesViewController)
    }
}
