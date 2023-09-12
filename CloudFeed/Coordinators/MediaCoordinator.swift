//
//  MediaCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//

import UIKit

final class MediaCoordinator {
    
    let navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
}

extension MediaCoordinator {
    
    func showViewerPager(currentIndex: Int, metadatas: [tableMetadata]) {
        let pagerCoordinator = PagerCoordinator(navigationController: navigationController)
        pagerCoordinator.start(currentIndex: currentIndex, metadatas: metadatas)
    }
    
    func showLoadfailedError() {
        let alertController = UIAlertController(title: "Error", message: "Failed to load media.", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
}
