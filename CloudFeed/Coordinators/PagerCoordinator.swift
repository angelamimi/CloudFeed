//
//  PagerCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//

import UIKit

final class PagerCoordinator {
    
    let navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start(currentIndex: Int, metadatas: [tableMetadata]) {
        
        let viewerPager: PagerController = UIStoryboard(name: "Viewer", bundle: nil).instantiateInitialViewController() as! PagerController
        let viewModel = PagerViewModel(currentIndex: currentIndex, metadatas: metadatas)
        let viewerCoordinator = ViewerCoordinator()
        
        viewModel.coordinator = viewerCoordinator
        viewModel.delegate = viewerPager
        viewerPager.viewModel = viewModel
        
        navigationController.pushViewController(viewerPager, animated: true)
    }
}
