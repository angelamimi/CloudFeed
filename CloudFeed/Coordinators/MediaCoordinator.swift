//
//  MediaCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//

import UIKit

final class MediaCoordinator {
    
    private let navigationController: UINavigationController
    private let dataService: DataService
    
    init(navigationController: UINavigationController, dataService: DataService) {
        self.navigationController = navigationController
        self.dataService = dataService
    }
}

extension MediaCoordinator {
    
    func getPreviewController(metadata: tableMetadata) -> PreviewController {
        let previewController = PreviewController(metadata: metadata)
        previewController.viewModel = ViewerViewModel(dataService: dataService, metadata: metadata)
        return previewController
    }
    
    func showViewerPager(currentIndex: Int, metadatas: [tableMetadata]) {
        let pagerCoordinator = PagerCoordinator(navigationController: navigationController, dataService: dataService)
        pagerCoordinator.start(currentIndex: currentIndex, metadatas: metadatas)
    }
    
    func showLoadfailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.MediaErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
    
    func showFavoriteUpdateFailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.FavUpdateErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
}