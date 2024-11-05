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
        
        initCollectionView(layoutType: viewModel.getLayoutType(), columnCount: viewModel.getColumnCount())
        initTitleView(mediaView: self, allowEdit: true, layoutType: viewModel.getLayoutType())
        initEmptyView(imageSystemName: "star.fill", title: Strings.FavEmptyTitle, description: Strings.FavEmptyDescription)
        initConstraints()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        viewModel.cancelLoads()
    }

    override func viewDidAppear(_ animated: Bool) {
        refreshVisibleItems()
        syncFavorites()
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            refreshVisibleItems()
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        super.scrollViewDidEndDecelerating(scrollView)
        
        refreshVisibleItems()
    }
    
    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        super.scrollViewDidEndScrollingAnimation(scrollView)
        
        refreshVisibleItems()
    }
    
    public func clear() {

        viewModel?.clearCache()

        scrollToTop()
        viewModel?.resetDataSource()
        setTitle("")
    }
    
    private func refreshVisibleItems() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if visibleIndexPaths.count > 0 {
            viewModel.refreshItems(visibleIndexPaths)
        }
    }
    
    private func syncFavorites() {
        
        if collectionView.isHidden == true && emptyView.isHidden == false {
            emptyView.hide() //hiding empty view during sync looks better
        }
        
        let visibleDateRange = getVisibleItemData()
        
        if hasFilter() {
            viewModel.syncFavs(type: filterType, from: filterFromDate, to: filterToDate)
        } else if visibleDateRange.toDate != nil || visibleDateRange.name != nil {
            viewModel.syncFavs(type: filterType, from: nil, to: nil)
        } else {
            viewModel.fetch(type: filterType, refresh: false)
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
    
    private func displayResults(refresh: Bool) {
        if hasFilter() {
            displayResults(refresh: refresh, emptyViewTitle: Strings.FavEmptyFilterTitle, emptyViewDescription: Strings.FavEmptyFilterDescription)
        } else {
            displayResults(refresh: refresh, emptyViewTitle: Strings.FavEmptyTitle, emptyViewDescription: Strings.FavEmptyDescription)
        }
    }
}

extension FavoritesController: CollectionDelegate {
    
    func enteringForeground() {
        syncFavorites()
    }
    
    func columnCountChanged(columnCount: Int) {
        viewModel.saveColumnCount(columnCount)
    }
    
    func scrollSpeedChanged(scrolling: Bool) {
        viewModel.pauseLoading = scrolling
        
        if scrolling {
            viewModel.cancelLoads()
        }
    }
    
    func refresh() {
        if hasFilter() {
            viewModel.filter(type: filterType, from: filterFromDate!, to: filterToDate!)
        } else {
            viewModel.fetch(type: filterType, refresh: true)
        }
    }
    
    func loadMore() {
        viewModel.loadMore(type: filterType, filterFromDate: filterFromDate, filterToDate: filterToDate)
    }
    
    func setTitle() {
        
        setTitle("")
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }
        
        let metadata = viewModel.getItemAtIndexPath(indexPath)
        guard metadata != nil else { return }

        setTitle(getFormattedDate(metadata!.date as Date))
    }
    
    func sizeAtIndexPath(indexPath: IndexPath) -> CGSize {
        
        guard let metadata = viewModel.getItemAtIndexPath(indexPath) else {
            return CGSize.zero
        }

        return calculateItemSize(width: metadata.width, height: metadata.height)
    }
}

extension FavoritesController: FavoritesDelegate {
    
    func bulkEditFinished(error: Bool) {
        
        isEditing = false
        collectionView.allowsMultipleSelection = false

        displayResults(refresh: false)
        reloadSection()
        
        if hasFilter() {
            showEditFilter()
        }
        
        if error {
            collectionView.indexPathsForSelectedItems?.forEach { [weak self] in
                self?.collectionView.deselectItem(at: $0, animated: false)
            }
            coordinator.showFavoriteUpdateFailedError()
        }
    }
    
    func fetching() {
        if !isRefreshing() && !isLoadingMore() {
            activityIndicator.startAnimating()
        }
    }
    
    func fetchResultReceived(resultItemCount: Int?) {
        if resultItemCount == nil {
            coordinator.showLoadfailedError()
            displayResults(refresh: false)
        }
    }
    
    func dataSourceUpdated(refresh: Bool) {
        displayResults(refresh: refresh)
        refreshVisibleItems()
    }
    
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath) {
        
        if isEditing {
            cell.selectMode(true)
            if collectionView.indexPathsForSelectedItems?.firstIndex(of: indexPath) != nil {
                cell.selected(true)
            } else {
                cell.selected(false)
            }
        } else {
            cell.selectMode(false)
        }
    }
}

extension FavoritesController: MediaViewController {
    
    func updateMediaType(_ type: Global.FilterType) {
        filterType = type
        clear()
        syncFavorites()
    }
    
    func updateLayout(_ layout: String) {
        viewModel.updateLayoutType(layout)
        reloadMenu(allowEdit: true, layoutType: layout)
        updateLayoutType(layout)
    }
    
    func zoomInGrid() {
        if viewModel.currentItemCount() > 0 {
            zoomIn()
            refreshVisibleItems()
        }
    }
    
    func zoomOutGrid() {
        if viewModel.currentItemCount() > 0 {
            zoomOut()
            refreshVisibleItems()
        }
    }
    
    func titleTouched() {
        scrollToTop()
    }
    
    func edit() {
        if viewModel.currentItemCount() > 0 {
            titleBeginEdit()
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

        collectionView.indexPathsForSelectedItems?.forEach { [weak self] in
            self?.collectionView.deselectItem(at: $0, animated: false)
        }

        isEditing = false
        collectionView.allowsMultipleSelection = false
        reloadSection()
    }
    
    func filter() {
        coordinator.showFilter(filterable: self, from: filterFromDate, to: filterToDate)
    }
}

extension FavoritesController: Filterable {
    
    func filter(from: Date, to: Date) {
        
        if emptyView.isHidden == false {
            emptyView.hide() //looks better when searching again
        }
        
        coordinator.dismissFilter()
        
        if to < from {
            coordinator.showInvalidFilterError()
        } else {

            showEditFilter()
            
            filterToDate = to
            filterFromDate = from
            
            viewModel.filter(type: filterType, from: from, to: to)
        }
    }
    
    func removeFilter() {
        
        coordinator.dismissFilter()
        
        hideEditFilter()
        hideEmptyView()
        
        filterToDate = nil
        filterFromDate = nil
        
        refresh()
        
        viewModel.resetDataSource()
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
        
        let previewController = self.coordinator.getPreviewController(metadata: metadata)
        
        previewController.preferredContentSize = image.size

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
