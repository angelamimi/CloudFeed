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
        
        //NextcloudNetworking.shared.cancelAllTransfer(account: appDelegate.account) {}
        //NextcloudOperationQueue.shared.cancelAllQueue()
        //NextcloudNetworking.shared.cancelAllTask()

        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
        
        DatabaseManager.shared.clearDatabase(account: appDelegate.account, removeAccount: false)
        
        StoreUtility.removeGroupDirectoryProviderStorage()
        //StoreUtility.removeGroupLibraryDirectory()

        //TODO: THIS LOGGED THE USER OUT
        //StoreUtility.removeDocumentsDirectory()
        
        //TODO: THIS CAUSES VIDEOS TO NOT PLAY ON LONG CLICK OF COLLECTION VIEW
        //StoreUtility.removeTemporaryDirectory()
        
        HTTPCache.shared.deleteAllCache()
        
        let controller = self.tabBarController?.viewControllers?[0] as! MainViewController
        controller.clear()

        /*DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(1 * Double(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: { [self] in
            //self.stopActivityIndicator()
            self.calculateCacheSize()
        })*/
        
        Task {
            await calculateCacheSize()
        }
    }
}
