//
//  AppCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/3/23.
//

import UIKit

final class AppCoordinator: Coordinator {
    
    let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        if Environment.current.currentUser == nil {
            let loginServerCoordinator = LoginServerCoordinator(window: window)
            loginServerCoordinator.start()
        } else {
            let mainCoordinator = MainCoordinator(window: window)
            mainCoordinator.start()
        }
    }
}
