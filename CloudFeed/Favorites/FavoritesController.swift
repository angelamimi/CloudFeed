//
//  FavoritesController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
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

class FavoritesController: CollectionController {
    
    var coordinator: FavoritesCoordinator!
    var viewModel: FavoritesViewModel!
    
    private var layout: CollectionLayout?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerCell("CollectionViewCell")
        
        title = Strings.FavNavTitle
        
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = false
        
        viewModel.initDataSource(collectionView: collectionView)
        
        initCollectionView()
        initTitleView(mediaView: self, allowEdit: true)
        initEmptyView(imageSystemName: "star.fill", title: Strings.FavEmptyTitle, description: Strings.FavEmptyDescription)
        initConstraints()
        initObservers()
    }
    
    deinit {
        cleanup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        fetchFavorites()
    }
    
    override func refresh() {
        viewModel.fetch(refresh: true)
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
    
    private func fetchFavorites() {
        
        let visibleDateRange = getVisibleItemData()
        
        if visibleDateRange.toDate == nil || visibleDateRange.name == nil {
            hideMenu()
            viewModel.fetch(refresh: false)
        } else {
            viewModel.syncFavs()
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
    
    private func bulkEdit() async {
        guard let indexPaths = collectionView.indexPathsForSelectedItems else { return }
        await viewModel.bulkEdit(indexPaths: indexPaths)
    }
    
    private func reloadSection() {
        viewModel.reload()
    }
    
    private func getVisibleItemData() -> (toDate: Date?, name: String?) {
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        let first = visibleIndexes?.first

        if first == nil {
            //Self.logger.debug("getVisibleItemData() - no visible items")
        } else {

            let firstMetadata = viewModel.getItemAtIndexPath(first!)

            if firstMetadata == nil {
                //Self.logger.debug("getVisibleItemData() - missing metadata")
            } else {
                //Self.logger.debug("getVisibleItemData() - \(firstMetadata!.date) \(firstMetadata!.fileNameView)")
                return (firstMetadata!.date as Date, firstMetadata!.fileNameView)
            }
        }
        
        return (nil, nil)
    }
    
    private func favoriteMenuAction(indexPath: IndexPath) -> UIAction {
        return UIAction(title: Strings.FavRemove, image: UIImage(systemName: "star.fill")) { [weak self] _ in
            self?.removeFavorite(indexPath: indexPath)
        }
    }
    
    private func removeFavorite(indexPath: IndexPath) {
        Task { [weak self] in
            await self?.viewModel.bulkEdit(indexPaths: [indexPath])
        }
    }
    
    private func enteringForeground() {
        if isViewLoaded && view.window != nil {
            fetchFavorites()
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

extension FavoritesController: FavoritesDelegate {
    
    func bulkEditFinished() {
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            self.isEditing = false
            self.collectionView.allowsMultipleSelection = false
        
            self.displayResults()
        }
    }
    
    func fetching() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.isRefreshing() && !self.isLoadingMore() {
                self.activityIndicator.startAnimating()
            }
        }
    }
    
    func fetchResultReceived(resultItemCount: Int?) {
        DispatchQueue.main.async { [weak self] in
            if resultItemCount == nil {
                self?.coordinator.showLoadfailedError()
            }
        }
    }
    
    func dataSourceUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.displayResults()
        }
    }
    
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if self.isEditing {
                cell.selectMode(true)
                if self.collectionView.indexPathsForSelectedItems?.firstIndex(of: indexPath) != nil {
                    cell.selected(true)
                } else {
                    cell.selected(false)
                }
            } else {
                cell.selectMode(false)
            }
        }
    }
}

extension FavoritesController: MediaViewController {
    
    func zoomInGrid() {
        zoomIn()
    }
    
    func zoomOutGrid() {
        let count = viewModel.currentItemCount()
        zoomOut(currentItemCount: count)
    }
    
    func titleTouched() {
        if viewModel.currentItemCount() > 0 {
            collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }
    
    func edit() {
        if viewModel.currentItemCount() > 0 {
            isEditing = true
            collectionView.allowsMultipleSelection = true
            reloadSection()
        }
    }
    
    func endEdit() {
        Task { [weak self] in
            await self?.bulkEdit()
        }
    }
    
    func cancel() {

        collectionView.indexPathsForSelectedItems?.forEach { collectionView.deselectItem(at: $0, animated: false) }

        isEditing = false
        collectionView.allowsMultipleSelection = false
        reloadSection()
    }
}

extension FavoritesController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditing {
            if let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell {
                cell.selected(true)
            }
        } else {
            openViewer(indexPath: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isEditing {
            if let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell {
                cell.selected(false)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        
        guard isEditing == false else { return nil }
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
            return UIMenu(title: "", options: .displayInline, children: [self.favoriteMenuAction(indexPath: indexPath)])
        })
        
        return config
    }
    
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        openViewer(indexPath: indexPath)
    }
}
