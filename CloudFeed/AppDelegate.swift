//
//  AppDelegate.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import NextcloudKit
import os.log
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: AppDelegate.self)
    )

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        initNavigationBar()
        
        StoreUtility.initStorage()
        
        return true
    }
    
    private func initNavigationBar() {
        let coloredAppearance = UINavigationBarAppearance()
        
        coloredAppearance.configureWithOpaqueBackground()
        coloredAppearance.backgroundColor = .systemBackground //.systemFill
        coloredAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
    }
}

