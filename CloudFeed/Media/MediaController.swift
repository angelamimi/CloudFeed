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
        initTitleView(mediaView: self, navigationDelegate: self, allowEdit: false, layoutType: viewModel.getLayoutType())
        initCollectionView(layoutType: viewModel.getLayoutType(), columnCount: viewModel.getColumnCount())
        initEmptyView(imageSystemName: "photo", title: Strings.MediaEmptyTitle, description: Strings.MediaEmptyDescription)
    }

    override func viewWillDisappear(_ animated: Bool) {
        viewModel.cancel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        refreshVisibleItems()
        syncMedia()
        
        viewModel.cleanupFileCache()
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
    
    public func scrollToMetadata(metadata: Metadata) {
        if let indexPath = viewModel.getIndexPathForMetadata(metadata: metadata) {
            //only scroll to item if not visible already
            if collectionView.indexPathsForVisibleItems.contains(indexPath) == false {
                collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
            }
        }
    }
    
    private func refreshVisibleItems() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if visibleIndexPaths.count > 0 {
            viewModel.refreshItems(visibleIndexPaths)
        }
    }
    
    private func syncMedia() {

        if collectionView.isHidden == true && emptyView.isHidden == false {
            emptyView.hide(animate: false) //hiding empty view during sync looks better
        }
        
        let syncDateRange = getSyncDateRange()
        
        if hasFilter() {
            viewModel.sync(type: filterType, toDate: filterToDate!, fromDate: filterFromDate!)
        } else if syncDateRange.toDate != nil && syncDateRange.fromDate != nil {
            viewModel.sync(type: filterType, toDate: syncDateRange.toDate!, fromDate: syncDateRange.fromDate!)
        } else {
            viewModel.metadataSearch(type: filterType, toDate: Date.distantFuture, fromDate: Date.distantPast, offsetDate: nil, offsetName: nil, refresh: false)
        }
    }
    
    private func openViewer(indexPath: IndexPath) {
        
        let metadata = viewModel.getItemAtIndexPath(indexPath)
        
        guard metadata != nil && (metadata!.classFile == NKCommon.TypeClassFile.image.rawValue
                || metadata!.classFile == NKCommon.TypeClassFile.audio.rawValue
                || metadata!.classFile == NKCommon.TypeClassFile.video.rawValue) else { return }
        
        let metadatas = viewModel.getItems()
        viewModel.showViewerPager(currentIndex: indexPath.item, metadatas: metadatas)
    }
    
    private func getSyncDateRange() -> (toDate: Date?, fromDate: Date?) {
        
        let lastItem = viewModel.getLastItem()
        
        if lastItem == nil {
            return (nil, nil)
        } else {
            return (Date(), lastItem!.date as Date)
        }
    }
    
    private func favoriteMenuAction(metadata: Metadata) -> UIAction {
        
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
    
    private func toggleFavorite(metadata: Metadata) {
        activityIndicator.startAnimating()
        viewModel.toggleFavorite(metadata: metadata)
    }
    
    private func displayResults(refresh: Bool) {
        if hasFilter() {
            displayResults(refresh: refresh, emptyViewTitle: Strings.MediaEmptyFilterTitle, emptyViewDescription: Strings.MediaEmptyFilterDescription)
        } else {
            displayResults(refresh: refresh, emptyViewTitle: Strings.MediaEmptyTitle, emptyViewDescription: Strings.MediaEmptyDescription)
        }
    }
}

extension MediaController: CollectionDelegate {
    
    func enteringForeground() {
        syncMedia()
    }
    
    func columnCountChanged(columnCount: Int) {
        viewModel.saveColumnCount(columnCount)
        refreshVisibleItems()
    }
    
    func scrollSpeedChanged(scrolling: Bool) {
        viewModel.pauseLoading = scrolling
        
        if scrolling {
            viewModel.cancelLoads()
        }
    }
    
    func refresh() {
        
        if hasFilter() {
            viewModel.filter(type: filterType, toDate: filterToDate!, fromDate: filterFromDate!)
        } else {
            viewModel.metadataSearch(type: filterType, toDate: Date.distantFuture, fromDate: Date.distantPast, offsetDate: nil, offsetName: nil, refresh: true)
        }
    }
    
    func loadMore() {
        viewModel.loadMore(type: filterType, filterFromDate: filterFromDate)
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

extension MediaController: MediaDelegate {
    
    func dataSourceUpdated(refresh: Bool) {
        displayResults(refresh: refresh)
        refreshVisibleItems()
    }
    
    func favoriteUpdated(error: Bool) { 
        activityIndicator.stopAnimating()
    }
    
    func searching() {
        if !isRefreshing() && !isLoadingMore() {
            activityIndicator.startAnimating()
        }
    }
    
    func searchResultReceived(resultItemCount: Int?) {
        if resultItemCount == nil {
            syncMedia()
            displayResults(refresh: false)
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
        
        let previewController = viewModel.getPreviewController(metadata: metadata)
        
        previewController.preferredContentSize = image.size

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
    
    func updateMediaType(_ type: Global.FilterType) {
        filterType = type
        clear()
        syncMedia()
    }
    
    func updateLayout(_ layout: String) {
        viewModel.updateLayoutType(layout)
        reloadMenu(allowEdit: false, layoutType: viewModel.getLayoutType())
        updateLayoutType(layout)
    }
    
    func zoomInGrid() {
        if viewModel.currentItemCount() > 0 {
            zoomIn()
        }
    }
    
    func zoomOutGrid() {
        if viewModel.currentItemCount() > 0 {
            zoomOut()
        }
    }
    
    func filter() {
        viewModel.showFilter(filterable: self, from: filterFromDate, to: filterToDate)
    }
    
    func edit() {}
    func endEdit() {}
}

extension MediaController: NavigationDelegate {
    
    func titleTouched() {
        scrollToTop(animated: true)
    }
    
    func cancel() {}
}

extension MediaController: Filterable {
    
    func filter(from: Date, to: Date) {
        
        if emptyView.isHidden == false {
            emptyView.hide() //looks better when searching again
        }
        
        viewModel.dismissFilter()
        
        if to < from {
            viewModel.showInvalidFilterError()
        } else {

            showEditFilter()
            
            filterToDate = to
            filterFromDate = from
            
            viewModel.filter(type: filterType, toDate: to, fromDate: from)
        }
    }
    
    func removeFilter() {
        
        viewModel.dismissFilter()
        
        hideEditFilter()
        hideEmptyView()
        
        filterToDate = nil
        filterFromDate = nil
        
        refresh()
        
        viewModel.resetDataSource()
    }
}
