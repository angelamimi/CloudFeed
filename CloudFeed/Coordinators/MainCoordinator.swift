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
    private let dataService: DataService

    private weak var tabBarController: UITabBarController?
    
    init(window: UIWindow, dataService: DataService) {
        
        self.window = window
        self.dataService = dataService
        
        if window.rootViewController is UITabBarController {
            tabBarController = window.rootViewController as? UITabBarController
        } else {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                tabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MainSplitTabController") as? UITabBarController
            } else {
                tabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MainTabController") as? UITabBarController
            }
        }
        
        super.init()
        
        tabBarController!.delegate = self
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            initSplitTabCoordinators(dataService: dataService)
        } else {
            initTabCoordinators(dataService: dataService)
        }
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
    
    func reset() {
        clearSettingsController()
        clearMediaController()
        clearFavoritesController()
    }
    
    func clearUser() {
        clearSettingsController()
    }
    
    func cacheCleared() {
        clearMediaController()
        clearFavoritesController()
    }
}

extension MainCoordinator {
    
    private func clearMediaController() {
        let mediaNavController = tabBarController?.viewControllers?[0] as! UINavigationController
        let mediaViewController = mediaNavController.viewControllers[0] as! MediaController
        mediaViewController.clear()
    }
    
    private func clearFavoritesController() {
        let favoritesNavController = tabBarController?.viewControllers?[1] as! UINavigationController
        let favoritesViewController = favoritesNavController.viewControllers[0] as! FavoritesController
        favoritesViewController.clear()
    }
    
    private func clearSettingsController() {
        if tabBarController?.viewControllers?[2] is UINavigationController {
            let settingsNavController = tabBarController?.viewControllers?[2] as! UINavigationController
            let settingsController = settingsNavController.viewControllers[0] as! SettingsController
            settingsController.clear()
        } else {
            let settingsSplitController = tabBarController?.viewControllers?[2] as! UISplitViewController
            let settingsController = settingsSplitController.viewController(for: .secondary) as! SettingsController
            settingsController.clear()
        }
    }
    
    private func initTabCoordinators(dataService: DataService) {

        guard tabBarController?.viewControllers != nil && tabBarController?.viewControllers?.count == 3 else { return }

        let mediaNavController = tabBarController?.viewControllers?[0] as! UINavigationController
        let favoritesNavController = tabBarController?.viewControllers?[1] as! UINavigationController
        let settingsNavController = tabBarController?.viewControllers?[2] as! UINavigationController
        
        let mediaViewController = mediaNavController.viewControllers[0] as! MediaController
        let favoritesViewController = favoritesNavController.viewControllers[0] as! FavoritesController
        let settingsViewController = settingsNavController.viewControllers[0] as! SettingsController
        
        let cacheManager = CacheManager(dataService: dataService)
        
        let mediaCoordinator = MediaCoordinator(navigationController: mediaNavController, dataService: dataService)
        let favoriteCoordinator = FavoritesCoordinator(navigationController: favoritesNavController, dataService: dataService)
        let settingCoordinator = SettingsCoordinator(navigationController: settingsNavController, dataService: dataService, cacheDelegate: self)
        
        mediaViewController.viewModel = MediaViewModel(delegate: mediaViewController, dataService: dataService, cacheManager: cacheManager, coordinator: mediaCoordinator)
        favoritesViewController.viewModel = FavoritesViewModel(delegate: favoritesViewController, dataService: dataService, cacheManager: cacheManager, coordinator: favoriteCoordinator)
        settingsViewController.viewModel = SettingsViewModel(delegate: settingsViewController, profileDelegate: settingsViewController, dataService: dataService, coordinator: settingCoordinator)
        
        settingsViewController.mode = .all
        
        mediaViewController.delegate = mediaViewController
        favoritesViewController.delegate = favoritesViewController
    }
    
    private func initSplitTabCoordinators(dataService: DataService) {
        
        guard tabBarController?.viewControllers != nil && tabBarController?.viewControllers?.count == 3 else { return }

        let mediaNavController = tabBarController?.viewControllers?[0] as! UINavigationController
        let favoritesNavController = tabBarController?.viewControllers?[1] as! UINavigationController
        let settingsSplitController = tabBarController?.viewControllers?[2] as! UISplitViewController
        
        settingsSplitController.title = Strings.SettingsNavTitle
        
        let menuController = settingsSplitController.viewController(for: .primary) as! MenuController
        menuController.delegate = self
        
        let mediaViewController = mediaNavController.viewControllers[0] as! MediaController
        let favoritesViewController = favoritesNavController.viewControllers[0] as! FavoritesController
        let settingsController = settingsSplitController.viewController(for: .secondary) as! SettingsController
        
        settingsController.mode = .account
        
        let cacheManager = CacheManager(dataService: dataService)
        
        let mediaCoordinator = MediaCoordinator(navigationController: mediaNavController, dataService: dataService)
        let favoriteCoordinator = FavoritesCoordinator(navigationController: favoritesNavController, dataService: dataService)
        let settingCoordinator = SettingsCoordinator(navigationController: settingsController.navigationController!, dataService: dataService, cacheDelegate: self)
        
        mediaViewController.viewModel = MediaViewModel(delegate: mediaViewController, dataService: dataService, cacheManager: cacheManager, coordinator: mediaCoordinator)
        favoritesViewController.viewModel = FavoritesViewModel(delegate: favoritesViewController, dataService: dataService, cacheManager: cacheManager, coordinator: favoriteCoordinator)
        settingsController.viewModel = SettingsViewModel(delegate: settingsController, profileDelegate: settingsController, dataService: dataService, coordinator: settingCoordinator)
        
        mediaViewController.delegate = mediaViewController
        favoritesViewController.delegate = favoritesViewController
    }
    
    private func updateMode(_ mode: Global.SettingsMode) {
        let settingsSplitController = tabBarController?.viewControllers?[2] as! UISplitViewController
        let settingsController = settingsSplitController.viewController(for: .secondary) as! SettingsController
        
        settingsController.navigationController?.popToRootViewController(animated: false)
        
        settingsController.updateMode(mode)
    }
}

extension MainCoordinator: MenuDelegate {
    
    func selectProfile() {
        updateMode(.account)
    }
    
    func selectDisplay() {
        updateMode(.display)
    }
    
    func selectInformation() {
        updateMode(.information)
    }
    
    func selectData() {
        updateMode(.data)
    }
}
