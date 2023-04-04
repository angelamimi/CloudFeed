//
//  SettingsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/18/23.
//

import os.log
import UIKit

class SettingsController: UIViewController {
    @IBOutlet weak var cacheSizeLabel: UILabel!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SettingsController.self)
    )
    
    @IBAction func buttonClicked(_ sender: Any) {
        clearCache()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        Task {
            await calculateCacheSize()
        }
    }
    
    private func calculateSize() {
        DispatchQueue.global(qos: .default).async(execute: {
            guard let directory = StoreUtility.getDirectoryProviderStorage() else { return }
            let totalSize = FileSystemUtility.shared.getDirectorySize(directory: directory)
            
            let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .binary)
            Self.logger.debug("calculateSize() - \(formattedSize)")
            
            DispatchQueue.main.async(execute: { [self] in
                
                cacheSizeLabel.text = formattedSize
                //tableView.reloadData()
                //footerView.updateText(text: StoreUtility.transformedSize(totalSize))
            })
        })
    }
    
    private func calculateCacheSize() async {
        guard let directory = StoreUtility.getDirectoryProviderStorage() else { return }
        let totalSize = FileSystemUtility.shared.getDirectorySize(directory: directory)
        
        let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .binary)
        Self.logger.debug("calculateCacheSize() - \(formattedSize)")
        
        DispatchQueue.main.async {
            self.cacheSizeLabel.text = formattedSize
            //tableView.reloadData()
            //footerView.updateText(text: StoreUtility.transformedSize(totalSize))
        }
    }
    
    private func clearCache() {
        Self.logger.debug("clearCache()")
        
        //startActivityIndicator()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
        
        DatabaseManager.shared.clearDatabase(account: appDelegate.account, removeAccount: false)
        
        StoreUtility.removeGroupDirectoryProviderStorage()
        //StoreUtility.removeGroupLibraryDirectory()

        StoreUtility.removeDocumentsDirectory()
        
        //TODO: THIS CAUSES VIDEOS TO NOT PLAY ON LONG CLICK OF COLLECTION VIEW
        //StoreUtility.removeTemporaryDirectory()
        
        HTTPCache.shared.deleteAllCache()
        
        let nav = self.tabBarController?.viewControllers?[0] as! UINavigationController
        if nav.viewControllers[0] is MainViewController {
            let controller = nav.viewControllers[0] as! MainViewController
            controller.clear()
        }
        
        Task {
            await calculateCacheSize()
        }
    }
}
