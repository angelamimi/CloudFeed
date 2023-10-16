//
//  SceneDelegate.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let _ = (scene as? UIWindowScene) else { return }
        guard let window = self.window else { return }
        
        if ProcessInfo.processInfo.environment["XCInjectBundleInto"] == nil {
            let appCoordinator = AppCoordinator(window: window)
            appCoordinator.start()
        } else {
            window.rootViewController = UINavigationController()
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}

