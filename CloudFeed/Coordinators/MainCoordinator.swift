//
//  MainCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
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

final class MainCoordinator : NSObject, Coordinator {
    
    private let window: UIWindow
    private let tabBarController: UITabBarController
    
    init(window: UIWindow, dataService: DataService) {
        
        self.window = window
        self.tabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as! UITabBarController
        
        super.init()
        
        tabBarController.delegate = self
        
        initTabCoordinators(dataService: dataService)
    }
    
    func start() {
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}

extension MainCoordinator: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let nav = viewController as? UINavigationController {
            nav.popToRootViewController(animated: false)
        }
    }
}

extension MainCoordinator: CacheDelegate {
    
    func cacheCleared() {

        let mediaNavController = tabBarController.viewControllers?[0] as! UINavigationController
        let favoritesNavController = tabBarController.viewControllers?[1] as! UINavigationController
        
        let mediaViewController = mediaNavController.viewControllers[0] as! MediaController
        let favoritesViewController = favoritesNavController.viewControllers[0] as! FavoritesController
        
        mediaViewController.clear()
        favoritesViewController.clear()
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
        
        let cacheManager = CacheManager(dataService: dataService)
        
        mediaViewController.coordinator = MediaCoordinator(navigationController: mediaNavController, dataService: dataService)
        favoritesViewController.coordinator = FavoritesCoordinator(navigationController: favoritesNavController, dataService: dataService)
        settingsViewController.coordinator = SettingsCoordinator(navigationController: settingsNavController, cacheDelegate: self)
        
        mediaViewController.viewModel = MediaViewModel(delegate: mediaViewController, dataService: dataService, cacheManager: cacheManager)
        favoritesViewController.viewModel = FavoritesViewModel(delegate: favoritesViewController, dataService: dataService, cacheManager: cacheManager)
        settingsViewController.viewModel = SettingsViewModel(delegate: settingsViewController, dataService: dataService)
    }
}
