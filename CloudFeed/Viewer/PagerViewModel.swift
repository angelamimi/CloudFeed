//
//  PagerViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/9/23.
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

protocol PagerViewModelDelegate: AnyObject {
    func detailVisibilityChanged(visible: Bool)
    func finishedPaging(metadata: tableMetadata)
    func finishedUpdatingFavorite(isFavorite: Bool)
    func saveFavoriteError()
}

final class PagerViewModel: NSObject {

    private let coordinator: ViewerCoordinator
    let dataService: DataService
    
    private var currentIndex: Int
    private var metadatas: [tableMetadata]
    private var detailsVisible: Bool = false
    
    internal var nextIndex: Int?
    weak var delegate: PagerViewModelDelegate?
    
    init(coordinator: ViewerCoordinator, dataService: DataService, currentIndex: Int = 0, metadatas: [tableMetadata]) {
        self.coordinator = coordinator
        self.dataService = dataService
        self.currentIndex = currentIndex
        self.metadatas = metadatas
    }
    
    func currentMetadata() -> tableMetadata {
        return metadatas[currentIndex]
    }
    
    func initViewer() -> ViewerController {
        let metadata = currentMetadata()
        let viewerMedia = initViewer(index: currentIndex, metadata: metadata)
        return viewerMedia
    }
    
    func toggleFavorite(isFavorite: Bool) {
        let metadata = metadatas[currentIndex]
        
        Task { [weak self] in
            guard let self else { return }
            
            let result = await dataService.toggleFavoriteMetadata(metadata)

            if result != nil {
                metadatas[currentIndex] = result!
                delegate?.finishedUpdatingFavorite(isFavorite: isFavorite)
            } else {
                delegate?.saveFavoriteError()
            }
        }
    }
    
    func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {
        return dataService.getMetadataLivePhoto(metadata: metadata)
    }
    
    func downloadLivePhotoVideo(metadata: tableMetadata) async {
        await dataService.download(metadata: metadata, selector: "")
    }
}

extension PagerViewModel {
    
    private func initViewer(index: Int, metadata: tableMetadata) -> ViewerController {
        
        print("initViewer() - !! name: \(metadata.fileNameView) file exists: \(self.dataService.store.fileExists(metadata))")
        
        let controller = coordinator.getViewerController(for: index, metadata: metadata)
        
        controller.delegate = self
        
        if metadata.image && dataService.store.fileExists(metadata) {
            controller.path = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)
            print("initViewer() - path: \(controller.path ?? "")")
        }
        
        return controller
    }
}

extension PagerViewModel: ViewerDetailsDelegate {
    
    func detailVisibilityChanged(visible: Bool) {
        detailsVisible = visible
        delegate?.detailVisibilityChanged(visible: visible)
    }
}

extension PagerViewModel: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if currentIndex == 0 { return nil }
        let viewerMedia = initViewer(index: currentIndex - 1, metadata: metadatas[currentIndex - 1])
        return viewerMedia
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard currentIndex < metadatas.count - 1 else { return nil }
        let viewerMedia = initViewer(index: currentIndex + 1, metadata: metadatas[currentIndex + 1])
        return viewerMedia
    }
}

extension PagerViewModel: UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let nextViewController = pendingViewControllers.first as? ViewerController else { return }
        nextIndex = nextViewController.index
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed && nextIndex != nil {
            currentIndex = nextIndex!
            
            if currentIndex >= 0 && currentIndex < metadatas.count {
                let metadata = metadatas[currentIndex]
                self.delegate?.finishedPaging(metadata: metadata)
            }
        }
        self.nextIndex = nil
    }
}

