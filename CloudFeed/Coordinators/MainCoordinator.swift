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
        
        if #unavailable(iOS 26) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            initSplitTabCoordinators(dataService: dataService)
        } else {
            initTabCoordinators(dataService: dataService)
        }
        
        tabBarController?.delegate = self
        tabBarController?.view?.backgroundColor = .black
        tabBarController?.tabBar.tintColor = .label
    }
    
    func start() {
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}

extension MainCoordinator {
    
    private func getMediaController() -> MediaController? {
        return (tabBarController?.viewControllers?[0] as? UINavigationController)?.viewControllers[0] as? MediaController
    }
    
    private func getFavoritesController() -> FavoritesController? {
        return (tabBarController?.viewControllers?[1] as? UINavigationController)?.viewControllers[0] as? FavoritesController
    }
    
    private func resetMediaFilter() {
        if let media = getMediaController() {
            media.resetFilter()
        }
    }
    
    private func resetFavoritesFilter() {
        if let favs = getFavoritesController() {
            favs.resetFilter()
        }
    }
    
    private func clearMediaController() {
        
        if let nav = tabBarController?.viewControllers?[0] as? UINavigationController {
            nav.popToRootViewController(animated: false)
        }
        
        if let media = getMediaController() {
            media.clear()
        }
    }
    
    func sync() {
        
        if let nav = tabBarController?.selectedViewController as? UINavigationController {
           
            if let media = nav.topViewController as? MediaController {
                media.sync()
            } else if let fav = nav.topViewController as? FavoritesController {
                fav.sync()
            }
        }
    }
    
    private func clearFavoritesController() {
        
        if let nav = tabBarController?.viewControllers?[1] as? UINavigationController {
            nav.popToRootViewController(animated: false)
        }
        
        if let favs = getFavoritesController() {
            favs.clear()
        }
    }
    
    private func clearSettingsController(notify: Bool, reload: Bool) {
        if tabBarController?.viewControllers?[2] is UINavigationController {
            let settingsNavController = tabBarController?.viewControllers?[2] as! UINavigationController
            let settingsController = settingsNavController.viewControllers[0] as? SettingsController
            settingsController?.clear(notify: notify, reload: reload)
        } else {
            let settingsSplitController = tabBarController?.viewControllers?[2] as! UISplitViewController
            let settingsController = settingsSplitController.viewController(for: .secondary) as? SettingsController
            settingsController?.clear(notify: notify, reload: reload)
        }
    }
    
    private func blurWithTag(_ blurTag: Int) {
        
        if let currentView = tabBarController?.viewIfLoaded {
            let blurEffect = UIBlurEffect(style: .light)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            
            blurEffectView.frame = currentView.frame
            blurEffectView.tag = blurTag
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            currentView.addSubview(blurEffectView)
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
        let settingCoordinator = SettingsCoordinator(settingsController: settingsViewController, dataService: dataService, cacheDelegate: self, resetDelegate: self)
        
        mediaViewController.viewModel = MediaViewModel(delegate: mediaViewController, dataService: dataService, cacheManager: cacheManager, coordinator: mediaCoordinator)
        favoritesViewController.viewModel = FavoritesViewModel(delegate: favoritesViewController, dataService: dataService, cacheManager: cacheManager, coordinator: favoriteCoordinator)
        settingsViewController.viewModel = SettingsViewModel(delegate: settingsViewController, profileDelegate: settingsViewController, resetDelegate: self, dataService: dataService, coordinator: settingCoordinator)
        
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
        settingsSplitController.delegate = self
        
        let menuController = settingsSplitController.viewController(for: .primary) as! MenuController
        menuController.delegate = self
        
        let mediaViewController = mediaNavController.viewControllers[0] as! MediaController
        let favoritesViewController = favoritesNavController.viewControllers[0] as! FavoritesController
        let settingsController = settingsSplitController.viewController(for: .secondary) as! SettingsController
        
        settingsController.mode = .account
        
        let cacheManager = CacheManager(dataService: dataService)
        let mediaCoordinator = MediaCoordinator(navigationController: mediaNavController, dataService: dataService)
        let favoriteCoordinator = FavoritesCoordinator(navigationController: favoritesNavController, dataService: dataService)
        let settingCoordinator = SettingsCoordinator(settingsController: settingsController, dataService: dataService, cacheDelegate: self, resetDelegate: self)
        
        mediaViewController.viewModel = MediaViewModel(delegate: mediaViewController, dataService: dataService, cacheManager: cacheManager, coordinator: mediaCoordinator)
        favoritesViewController.viewModel = FavoritesViewModel(delegate: favoritesViewController, dataService: dataService, cacheManager: cacheManager, coordinator: favoriteCoordinator)
        settingsController.viewModel = SettingsViewModel(delegate: settingsController, profileDelegate: settingsController, resetDelegate: self, dataService: dataService, coordinator: settingCoordinator)
        
        mediaViewController.delegate = mediaViewController
        favoritesViewController.delegate = favoritesViewController
    }
    
    private func updateMode(_ mode: Global.SettingsMode) {
        
        if let settingsSplitController = tabBarController?.viewControllers?[2] as? UISplitViewController,
           let controller = settingsSplitController.viewController(for: .secondary) {
            
            let count = controller.navigationController?.viewControllers.count
            
            if count == 1 && controller is SettingsController {
                (controller as! SettingsController).updateMode(mode)
            } else {
                controller.navigationController?.popToRootViewController(animated: false)
                
                if let settings = settingsSplitController.viewController(for: .secondary) as? SettingsController {
                    settings.updateMode(mode)
                }
            }
        }
    }
}

extension MainCoordinator: MenuDelegate {
    
    func selectProfile() {
        updateMode(.account)
    }
    
    func selectDisplay() {
        updateMode(.display)
    }
    
    func selectPrivacy() {
        updateMode(.privacy)
    }
    
    func selectInformation() {
        updateMode(.information)
    }
    
    func selectData() {
        updateMode(.data)
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
    
    func clearUser() {
        clearSettingsController(notify: true, reload: true)
        resetMediaFilter()
        resetFavoritesFilter()
    }
    
    func cacheCleared() {
        clearMediaController()
        clearFavoritesController()
    }
}

extension MainCoordinator: ResetApplicationDelegate {
    
    func reset() {
        
        let blurTag = 999
        blurWithTag(blurTag)

        tabBarController?.dismiss(animated: true, completion: { [weak self] in
            
            let reload: Bool
            if self?.tabBarController?.selectedIndex == 2 {
                reload = true
            } else {
                self?.tabBarController?.selectedIndex = 2
                reload = false
            }
            
            if let nav = self?.tabBarController?.selectedViewController as? UINavigationController {
                
                nav.popToRootViewController(animated: true)
                
                DispatchQueue.main.async { [weak self] in
                    self?.clearSettingsController(notify: false, reload: reload)
                    self?.clearMediaController()
                    self?.clearFavoritesController()
                    
                    if let blur = self?.tabBarController?.view.viewWithTag(blurTag) {
                        blur.removeFromSuperview()
                    }
                }
            } else if let splitController = self?.tabBarController?.selectedViewController as? UISplitViewController {
                
                if let controller = splitController.viewController(for: .secondary) {
                    
                    controller.navigationController?.popToRootViewController(animated: false)
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.clearSettingsController(notify: false, reload: controller is SettingsController)
                        self?.clearMediaController()
                        self?.clearFavoritesController()
                        
                        if let blur = self?.tabBarController?.view.viewWithTag(blurTag) {
                            blur.removeFromSuperview()
                        }
                    }
                }
            }
        })
    }
}

extension MainCoordinator: UISplitViewControllerDelegate {
    
    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        
        updateMode(.all)
        
        if let settingsSplitController = tabBarController?.viewControllers?[2] as? UISplitViewController,
           let controller = settingsSplitController.viewController(for: .secondary) as? SettingsController {
            controller.setCompactNavigation()
        }
    }
}
