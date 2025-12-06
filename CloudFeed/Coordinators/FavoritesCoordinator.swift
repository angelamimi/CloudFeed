//
//  FavoritesController.swift
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
final class FavoritesCoordinator {
    
    weak var navigationController: UINavigationController!

    private let dataService: DataService
    
    init(navigationController: UINavigationController, dataService: DataService) {
        self.navigationController = navigationController
        self.dataService = dataService
    }
}

extension FavoritesCoordinator {
    
    func getPreviewController(metadata: Metadata) -> PreviewController {
        let previewController = PreviewController(metadata: metadata)
        previewController.viewModel = ViewerViewModel(dataService: dataService, metadata: metadata)
        return previewController
    }
    
    func showViewerPager(currentIndex: Int, metadatas: [Metadata]) {
        let pagerCoordinator = PagerCoordinator(navigationController: navigationController, dataService: dataService, delegate: self)
        pagerCoordinator.start(currentIndex: currentIndex, metadatas: metadatas)
    }
    
    func showPicker() {
        let pickerCoordinator = PickerCoordinator(navigationController: navigationController, dataService: dataService)
        pickerCoordinator.delegate = self
        pickerCoordinator.start()
    }
    
    func showFilter(filterable: Filterable, from: Date?, to: Date?) {
        
        let filterController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "FilterController") as FilterController
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        
        filterController.modalPresentationStyle = pad ? .popover : .formSheet
        filterController.preferredContentSize = CGSize(width: 400, height: 500)
        
        if pad {
            //for some reason formSheet is not presented in the center. added this to force centering along with popover modalPresentationStyle
            filterController.popoverPresentationController?.permittedArrowDirections = []
            filterController.popoverPresentationController?.sourceView = navigationController.view
            filterController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint( x: navigationController.view.bounds.midX, y: navigationController.view.bounds.midY), size: .zero)
        }
        
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
    
    func share(_ metadatas: [Metadata]) {
        let coordinator = ShareCoordinator(navigationController: navigationController, dataService: dataService, delegate: self, metadatas: metadatas)
        coordinator.start()
    }
    
    func showInvalidFilterError() {
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.MediaInvalidFilter, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
    
    func showLoadfailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.FavErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        if navigationController.presentedViewController == nil { //passcode controller not visible
            navigationController.present(alertController, animated: true)
        }
    }
    
    func showFavoriteUpdateFailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.FavUpdateErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            self.navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
}

extension FavoritesCoordinator: ShareDelegate {
    
    func shareComplete() {
        if navigationController.children[0] is FavoritesController {
            let favoritesController = navigationController.children[0] as! FavoritesController
            favoritesController.shareComplete()
        }
    }
}

extension FavoritesCoordinator: PagerDelegate {
    
    func pagingEndedWith(metadata: Metadata) {
        if navigationController.children[0] is FavoritesController {
            let favoritesController = navigationController.children[0] as! FavoritesController
            favoritesController.scrollToMetadata(metadata: metadata)
        }
    }
}

extension FavoritesCoordinator: PickerCoordinatorDelegate {
    
    func mediaPathChanged() {
        if navigationController.children[0] is FavoritesController {
            let favoritesController = navigationController.children[0] as! FavoritesController
            favoritesController.mediaPathChanged()
        }
    }
}
