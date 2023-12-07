//
//  ViewerCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//

import UIKit

final class ViewerCoordinator {
    
    private let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
    }
    
    func getViewerController(for index: Int, metadata: tableMetadata) -> ViewerController {
        
        let viewerMedia = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(identifier: "ViewerController") as! ViewerController
        let viewModel = ViewerViewModel(dataService: dataService, metadata: metadata)
        
        viewerMedia.index = index
        viewerMedia.metadata = metadata
        viewerMedia.viewModel = viewModel

        return viewerMedia
    }
}
