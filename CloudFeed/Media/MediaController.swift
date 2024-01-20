//
//  MediaController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
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

import NextcloudKit
import os.log
import UIKit

class MediaController: CollectionController {
    
    var coordinator: MediaCoordinator!
    var viewModel: MediaViewModel!

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MediaController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerCell("MainCollectionViewCell")
        
        title = Strings.MediaNavTitle
        
        collectionView.delegate = self
        
        viewModel.initDataSource(collectionView: collectionView)
        initTitleView(mediaView: self, allowEdit: false)
        initCollectionView()
        initEmptyView(imageSystemName: "photo", title: Strings.MediaEmptyTitle, description: Strings.MediaEmptyDescription)
        initConstraints()
        initObservers()
    }
    
    deinit {
        cleanup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        findMedia()
    }
    
    override func refresh() {
        viewModel.metadataSearch(offsetDate: Date(), offsetName: nil, refresh: true)
    }
    
    override func loadMore() {
        viewModel.loadMore()
    }
    
    override func setTitle() {

        setTitle("")
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }

        let metadata = viewModel.getItemAtIndexPath(indexPath)
        guard metadata != nil else { return }
        
        setTitle(StoreUtility.getFormattedDate(metadata!.date as Date))
    }
    
    public func clear() {
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self else { return }
            
            self.scrollToTop()
            self.hideMenu()
            self.setTitle("")
            self.viewModel?.resetDataSource()
        }
    }
    
    private func findMedia() {
        
        let syncDateRange = getSyncDateRange()
        
        if syncDateRange.toDate == nil || syncDateRange.fromDate == nil {
            hideMenu()
            viewModel.metadataSearch(offsetDate: Date(), offsetName: nil, refresh: false)
        } else {
            viewModel.sync(toDate: syncDateRange.toDate!, fromDate: syncDateRange.fromDate!)
        }
    }
    
    private func openViewer(indexPath: IndexPath) {
        
        let metadata = viewModel.getItemAtIndexPath(indexPath)
        
        guard metadata != nil && (metadata!.classFile == NKCommon.TypeClassFile.image.rawValue
                || metadata!.classFile == NKCommon.TypeClassFile.audio.rawValue
                || metadata!.classFile == NKCommon.TypeClassFile.video.rawValue) else { return }
        
        let metadatas = viewModel.getItems()
        coordinator.showViewerPager(currentIndex: indexPath.item, metadatas: metadatas)
    }
    
    private func getSyncDateRange() -> (toDate: Date?, fromDate: Date?) {
        
        let lastItem = viewModel.getLastItem()
        
        if lastItem == nil {
            return (nil, nil)
        } else {
            return (Date(), lastItem!.date as Date)
        }
    }
    
    private func favoriteMenuAction(metadata: tableMetadata) -> UIAction {
        
        if metadata.favorite {
            return UIAction(title: Strings.FavRemove, image: UIImage(systemName: "star.fill")) { [weak self] _ in
                self?.toggleFavorite(metadata: metadata)
            }
        } else {
            return UIAction(title: Strings.FavAdd, image: UIImage(systemName: "star")) { [weak self] _ in
                self?.toggleFavorite(metadata: metadata)
            }
        }
    }
    
    private func toggleFavorite(metadata: tableMetadata) {
        
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.startAnimating()
        }
        
        self.viewModel.toggleFavorite(metadata: metadata)
    }
    
    private func enteringForeground() {
        if isViewLoaded && view.window != nil {
            findMedia()
        }
    }
    
    private func initObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.enteringForeground()
        }
    }
    
    private func cleanup() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

extension MediaController: MediaDelegate {
    
    func dataSourceUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.displayResults()
        }
    }
    
    func favoriteUpdated(error: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activityIndicator.stopAnimating()
            if error {
                self.coordinator.showFavoriteUpdateFailedError()
            }
        }
    }
    
    func searching() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.isRefreshing() && !self.isLoadingMore() {
                self.activityIndicator.startAnimating()
            }
        }
    }
    
    func searchResultReceived(resultItemCount: Int?) {
        DispatchQueue.main.async { [weak self] in
            if resultItemCount == nil {
                self?.coordinator.showLoadFailedError()
            }
        }
    }
}

extension MediaController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        openViewer(indexPath: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        
        guard let indexPath = indexPaths.first, let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell else { return nil }
        guard let image = cell.imageView.image else { return nil }
        guard let metadata = viewModel.getItemAtIndexPath(indexPath) else { return nil }
        
        let imageSize = image.size
        let width = self.view.bounds.width
        let height = imageSize.height * (width / imageSize.width)
        let previewController = self.coordinator.getPreviewController(metadata: metadata)
        
        previewController.preferredContentSize = CGSize(width: width, height: height)

        let config = UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: { previewController }, actionProvider: { [weak self] _ in
            guard let self else { return .init(children: []) }
            return UIMenu(title: "", options: .displayInline, children: [self.favoriteMenuAction(metadata: metadata)])
        })
        
        return config
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        
        animator.addCompletion {
            guard let indexPath = configuration.identifier as? IndexPath else { return }
            self.openViewer(indexPath: indexPath)
        }
    }
}

extension MediaController: MediaViewController {
    
    func zoomInGrid() {
        zoomIn()
    }
    
    func zoomOutGrid() {
        zoomOut(currentItemCount: viewModel.currentItemCount())
    }
    
    func titleTouched() {
        if viewModel.currentItemCount() > 0 {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
        }
    }
    
    func edit() {}
    func endEdit() {}
    func cancel() {}
}
