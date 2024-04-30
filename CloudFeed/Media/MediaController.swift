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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        syncMedia()
    }
    
    override func enteringForeground() {
        syncMedia()
    }
    
    override func scrollSpeedChanged(isScrollingFast: Bool) {
        viewModel.pauseLoading = isScrollingFast
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        super.scrollViewDidEndDecelerating(scrollView)
        
        refreshVisibleItems()
    }
    
    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        super.scrollViewDidEndScrollingAnimation(scrollView)
        
        refreshVisibleItems()
    }
    
    override func refresh() {
        
        if hasFilter() {
            viewModel.filter(toDate: filterToDate!, fromDate: filterFromDate!)
        } else {
            viewModel.metadataSearch(toDate: Date.distantFuture, fromDate: Date.distantPast, offsetDate: nil, offsetName: nil, refresh: true)
        }
    }
    
    override func loadMore() {
        viewModel.loadMore(filterFromDate: filterFromDate)
    }
    
    override func setTitle() {

        setTitle("")
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }

        let metadata = viewModel.getItemAtIndexPath(indexPath)
        guard metadata != nil else { return }
        
        setTitle(getFormattedDate(metadata!.date as Date))
    }
    
    override func sizeAtIndexPath(indexPath: IndexPath) -> CGSize {
        
        //TODO: Enable size from metadata when values are accurate. API is returning wrong dimensions.
        
        /*guard let metadata = viewModel.getItemAtIndexPath(indexPath) else {
            return CGSize()
        }
        
        Self.logger.debug("sizeAtIndexPath() - name: \(metadata.fileNameView) width: \(metadata.width) height: \(metadata.height)")
        
        return CGSize(width: metadata.width, height: metadata.height)*/
        return CGSize()
    }
    
    public func clear() {
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self else { return }
            
            self.viewModel?.clearCache()

            self.scrollToTop()
            self.setTitle("")
            self.viewModel?.resetDataSource()
        }
    }
    
    private func refreshVisibleItems() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        viewModel.refreshItems(visibleIndexPaths)
    }
    
    private func syncMedia() {
        
        if collectionView.isHidden == true && emptyView.isHidden == false {
            emptyView.hide() //hiding empty view during sync looks better
        }
        
        let syncDateRange = getSyncDateRange()
        
        if hasFilter() {
            viewModel.sync(toDate: filterToDate!, fromDate: filterFromDate!)
        } else if syncDateRange.toDate != nil && syncDateRange.fromDate != nil {
            viewModel.sync(toDate: syncDateRange.toDate!, fromDate: syncDateRange.fromDate!)
        } else {
            viewModel.metadataSearch(toDate: Date.distantFuture, fromDate: Date.distantPast, offsetDate: nil, offsetName: nil, refresh: false)
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
    
    private func displayResults(refresh: Bool) {
        if hasFilter() {
            displayResults(refresh: refresh, emptyViewTitle: Strings.MediaEmptyFilterTitle, emptyViewDescription: Strings.MediaEmptyFilterDescription)
        } else {
            displayResults(refresh: refresh, emptyViewTitle: Strings.MediaEmptyTitle, emptyViewDescription: Strings.MediaEmptyDescription)
        }
    }
}

extension MediaController: MediaDelegate {
    
    func dataSourceUpdated(refresh: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.displayResults(refresh: refresh)
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
                self?.displayResults(refresh: false)
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
        coordinator.showFilter(filterable: self, from: filterFromDate, to: filterToDate)
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

extension MediaController: Filterable {
    
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
            
            viewModel.filter(toDate: to, fromDate: from)
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
