//
//  PagerCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//

import UIKit

final class PagerCoordinator {
    
    private let navigationController: UINavigationController
    private let dataService: DataService
    
    init(navigationController: UINavigationController, dataService: DataService) {
        self.navigationController = navigationController
        self.dataService = dataService
    }
    
    func start(currentIndex: Int, metadatas: [tableMetadata]) {
        
        let viewerCoordinator = ViewerCoordinator(dataService: dataService)
        let viewerPager: PagerController = UIStoryboard(name: "Viewer", bundle: nil).instantiateInitialViewController() as! PagerController
        let viewModel = PagerViewModel(coordinator: viewerCoordinator, dataService: dataService, currentIndex: currentIndex, metadatas: metadatas)
        
        viewModel.delegate = viewerPager
        viewerPager.viewModel = viewModel
        
        navigationController.pushViewController(viewerPager, animated: true)
    }
}
