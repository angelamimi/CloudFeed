//
//  ViewerCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

@MainActor
final class ViewerCoordinator {
    
    private let navigationController: UINavigationController
    private let dataService: DataService
    
    init(navigationController: UINavigationController, dataService: DataService) {
        self.navigationController = navigationController
        self.dataService = dataService
    }
    
    func getViewerController(for index: Int, metadata: Metadata) -> ViewerController {
        
        let viewerMedia = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(identifier: "ViewerController") as! ViewerController
        let viewModel = ViewerViewModel(coordinator: self, dataService: dataService, metadata: metadata)
        
        viewerMedia.index = index
        viewerMedia.metadata = metadata
        viewerMedia.viewModel = viewModel

        return viewerMedia
    }
}

extension ViewerCoordinator: DownloadableCoordinator {
    
    func download(_ metadata: Metadata) {
        let coordinator = DownloadCoordinator(navigationController: navigationController, dataService: dataService, delegate: self, metadata: metadata)
        coordinator.start()
    }
}

extension ViewerCoordinator: DownloadCoordinatorDelegate {
    
    func downloadComplete() {
        
        if let pager = navigationController.topViewController as? PagerController {
            
            pager.reload()
            
            DispatchQueue.main.async{ [weak self] in
                self?.navigationController.dismiss(animated: false)
            }
        }
    }
}
