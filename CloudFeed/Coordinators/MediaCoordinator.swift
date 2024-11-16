//
//  MediaCoordinator.swift
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
final class MediaCoordinator {
    
    private let navigationController: UINavigationController
    private let dataService: DataService
    
    init(navigationController: UINavigationController, dataService: DataService) {
        self.navigationController = navigationController
        self.dataService = dataService
    }
}

extension MediaCoordinator {
    
    func getPreviewController(metadata: Metadata) -> PreviewController {
        let previewController = PreviewController(metadata: metadata)
        previewController.viewModel = ViewerViewModel(dataService: dataService, metadata: metadata)
        return previewController
    }
    
    func showViewerPager(currentIndex: Int, metadatas: [Metadata]) {
        let pagerCoordinator = PagerCoordinator(navigationController: navigationController, dataService: dataService, delegate: self)
        pagerCoordinator.start(currentIndex: currentIndex, metadatas: metadatas)
    }
    
    func showFilter(filterable: Filterable, from: Date?, to: Date?) {
        
        let filterController = UIStoryboard(name: "Media", bundle: nil).instantiateViewController(identifier: "FilterController") as FilterController
        
        filterController.modalPresentationStyle = .formSheet
        
        if let sheet = filterController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
            sheet.prefersGrabberVisible = true
        }
        
        navigationController.present(filterController, animated: true)
        
        filterController.setFilterable(filterable: filterable)
        filterController.initDateFilter(from: from, to: to)
    }
    
    func dismissFilter() {
        navigationController.dismiss(animated: true)
    }
    
    func showInvalidFilterError() {
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.MediaInvalidFilter, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
    
    func showLoadFailedError() {
        
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

extension MediaCoordinator: PagerDelegate {
    
    func pagingEndedWith(metadata: Metadata) {
        
        if navigationController.children[0] is MediaController {
            let mediaController = navigationController.children[0] as! MediaController
            mediaController.scrollToMetadata(metadata: metadata)
        }
    }
}
