//
//  FavoritesViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/14/23.
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

@MainActor
protocol FavoritesDelegate: ShareDelegate {
    func fetching()
    func dataSourceUpdated(refresh: Bool)
    func bulkEditFinished(error: Bool)
    func fetchResultReceived(resultItemCount: Int?)
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath)
}

@MainActor
final class FavoritesViewModel: ShareViewModel {
    
    var pauseLoading: Bool = false

    private var dataSource: UICollectionViewDiffableDataSource<Int, Metadata.ID>!
    
    private let coordinator: FavoritesCoordinator
    private weak var delegate: FavoritesDelegate!
    
    private let cacheManager: CacheManager
    
    private var metadatas: [Metadata.ID: Metadata] = [:]
    
    private var fetchTask: Task<Void, Never>? {
        willSet {
            fetchTask?.cancel()
        }
    }
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesViewModel.self)
    )
    
    init(delegate: FavoritesDelegate, dataService: DataService, cacheManager: CacheManager, coordinator: FavoritesCoordinator) {
        self.delegate = delegate
        self.cacheManager = cacheManager
        self.coordinator = coordinator
        
        super.init(dataService: dataService, shareDelegate: delegate)
    }
    
    func initDataSource(collectionView: UICollectionView) {

        dataSource = UICollectionViewDiffableDataSource<Int, Metadata.ID>(collectionView: collectionView) { [weak self] (collectionView: UICollectionView, indexPath: IndexPath, metadataId: Metadata.ID) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            self?.populateCell(metadataId: metadataId, cell: cell, indexPath: indexPath, collectionView: collectionView)
            return cell
        }

        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
    }
    
    override func share(urls: [URL]) {
        coordinator.share(urls)
    }
    
    func getItemAtIndexPath(_ indexPath: IndexPath) -> Metadata? {
        if let id = dataSource.itemIdentifier(for: indexPath) {
            return metadatas[id]
        }
        return nil
    }
    
    func currentItemCount() -> Int {
        let snapshot = dataSource.snapshot()
        return snapshot.numberOfItems(inSection: 0)
    }
    
    func getItems() -> [Metadata] {
        let snapshot = dataSource.snapshot()
        var items: [Metadata] = []
        
        for id in snapshot.itemIdentifiers(inSection: 0) {
            if let metadata = metadatas[id] {
                items.append(metadata)
            }
        }
        
        return items
    }
    
    func getLayoutType() -> String {
        return dataService.store.getFavoriteLayoutType()
    }
    
    func updateLayoutType(_ type: String) {
        dataService.store.setFavoriteLayoutType(type)
    }
    
    func getColumnCount() -> Int {
        return dataService.store.getFavoriteColumnCount()
    }
    
    func saveColumnCount(_ columnCount: Int) {
        dataService.store.setFavoriteColumnCount(columnCount)
    }
    
    func cancelLoads() {
        cacheManager.cancelAll()
    }
    
    func clearCache() {
        cacheManager.clear()
    }
    
    func cleanupFileCache() {
        Task { [weak self] in
            await self?.dataService.store.cleanupFileCache()
        }
    }
    
    func getIndexPathForMetadata(metadata: Metadata) -> IndexPath? {
        return dataSource.indexPath(for: metadata.id)
    }
    
    func resetDataSource() {
        
        guard dataSource != nil else { return }
        
        metadatas.removeAll()
        
        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.appendSections([0])
        dataSource!.applySnapshotUsingReloadData(snapshot)
    }
    
    func loadMore(type: Global.FilterType, filterFromDate: Date?, filterToDate: Date?) {

        var offsetDate: Date?
        var offsetName: String?

        let snapshot = dataSource.snapshot()
        
        if (snapshot.numberOfItems(inSection: 0) > 0) {
            if let id = snapshot.itemIdentifiers(inSection: 0).last {
                if let metadata = metadatas[id] {
                    offsetName = metadata.fileNameView
                    offsetDate = metadata.date as Date
                    /*  intentionally overlapping results. could shift the date here by a second to exclude previous results,
                     but might lose new results from files with dates in the same second */
                    //Self.logger.debug("loadMore() - offsetDate: \(offsetDate!.formatted(date: .abbreviated, time: .standard))")
                }
            }
        }

        guard let offsetDate = offsetDate else { return }
        guard let offsetName = offsetName else { return }
        
        //Self.logger.debug("loadMore() - offsetName: \(offsetName) offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        sync(type: type, offsetDate: offsetDate, offsetName: offsetName, filterFromDate: filterFromDate, filterToDate: filterToDate)
    }
    
    func reload() {

        var snapshot = dataSource.snapshot()
        
        guard snapshot.numberOfSections > 0 else { return }
        snapshot.reloadSections([0])
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    func fetch(type: Global.FilterType, refresh: Bool) {

        delegate.fetching()
                
        fetchTask = Task { [weak self] in
            await self?.fetch(type: type, refresh: refresh)
        }
    }
    
    func fetch(type: Global.FilterType, refresh: Bool) async {
        
        let error = await dataService.getFavorites()
        
        if Task.isCancelled { return }
        
        handleFavoriteResult(error: error)
        
        let resultMetadatas = dataService.paginateFavoriteMetadata(type: type, fromDate: Date.distantPast, toDate: Date.distantFuture, offsetDate: nil, offsetName: nil)
        await applyDatasourceChanges(metadatas: resultMetadatas, refresh: refresh)
    }
    
    func filter(type: Global.FilterType, from: Date, to: Date) {
        
        delegate.fetching()
                
        fetchTask = Task { [weak self] in
            guard let self else { return }
            
            let error = await dataService.getFavorites()
            
            if Task.isCancelled { return }
            
            handleFavoriteResult(error: error)
            
            let resultMetadatas = dataService.paginateFavoriteMetadata(type: type, fromDate: from, toDate: to, offsetDate: nil, offsetName: nil)
            await applyDatasourceChanges(metadatas: resultMetadatas, refresh: true)
        }
    }
    
    func syncFavs(type: Global.FilterType, from: Date?, to: Date?) {

        delegate.fetching()
                
        fetchTask = Task { [weak self] in
            guard let self else { return }
            
            let error = await dataService.getFavorites()
            
            if Task.isCancelled { return }
            
            handleFavoriteResult(error: error)
            
            processFavorites(type: type, from: from, to: to)
        }
    }
    
    func bulkEdit(indexPaths: [IndexPath]) async {
        
        var snapshot = dataSource.snapshot()
        var error = false
        
        for indexPath in indexPaths {
            
            guard let id = dataSource.itemIdentifier(for: indexPath) else { continue }
            guard let metadata = metadatas[id] else { continue }
            
            let result = await dataService.toggleFavoriteMetadata(metadata)
            
            if result == nil {
                //Self.logger.error("bulkEdit() - failed to save favorite ocid: \(metadata.ocId)")
                error = true
            } else {
                snapshot.deleteItems([result!.id])
                metadatas.removeValue(forKey: result!.id)
            }
        }
        
        snapshot.reloadSections([0])
        
        await dataSource.apply(snapshot, animatingDifferences: true)
        delegate.bulkEditFinished(error: error)
    }
    
    func refreshItems(_ refreshItems: [IndexPath]) {

        let items = refreshItems.compactMap { dataSource.itemIdentifier(for: $0) }
        
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(items)
        dataSource.apply(snapshot)
    }
    
    func showViewerPager(currentIndex: Int, metadatas: [Metadata]) {
        coordinator.showViewerPager(currentIndex: currentIndex, metadatas: metadatas)
    }
    
    func getPreviewController(metadata: Metadata) -> PreviewController {
        return coordinator.getPreviewController(metadata: metadata)
    }
    
    func showFilter(filterable: Filterable, from: Date?, to: Date?) {
        coordinator.showFilter(filterable: filterable, from: from, to: to)
    }
    
    func dismissFilter() {
        coordinator.dismissFilter()
    }
    
    func showInvalidFilterError() {
        coordinator.showInvalidFilterError()
    }
    
    func showLoadfailedError() {
        coordinator.showLoadfailedError()
    }
    
    func showFavoriteUpdateFailedError() {
        coordinator.showFavoriteUpdateFailedError()
    }
    
    func share(indexPaths: [IndexPath]) {
        var selectedMetadatas: [Metadata] = []
        for indexPath in indexPaths {
            guard let id = dataSource.itemIdentifier(for: indexPath) else { continue }
            guard let metadata = metadatas[id] else { continue }
            
            selectedMetadatas.append(metadata)
        }
        
        share(metadatas: selectedMetadatas)
    }
    
    private func handleFavoriteResult(error: Bool) {
        if error {
            delegate.fetchResultReceived(resultItemCount: nil)
        }
    }
    
    private func sync(type: Global.FilterType, offsetDate: Date, offsetName: String, filterFromDate: Date?, filterToDate: Date?) {
        
        delegate.fetching()
        
        Task { [weak self] in
            guard let self else { return }

            _ = await self.dataService.getFavorites()

            let resultMetadatas = self.dataService.paginateFavoriteMetadata(type: type, fromDate: filterFromDate ?? Date.distantPast, toDate: filterToDate ?? Date.distantFuture, offsetDate: offsetDate, offsetName: offsetName)
            await applyDatasourceChanges(metadatas: resultMetadatas, refresh: false)
        }
    }
    
    private func populateCell(metadataId: Metadata.ID, cell: CollectionViewCell, indexPath: IndexPath, collectionView: UICollectionView) {
        
        guard let metadata = metadatas[metadataId] else {
            cell.isAccessibilityElement = false
            return
        }

        cell.isAccessibilityElement = true
        cell.accessibilityTraits = [.image]
        
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            cell.showVideoIcon()
            cell.accessibilityLabel = Strings.MediaVideo
        } else if metadata.livePhoto {
            cell.showLivePhotoIcon()
            cell.accessibilityLabel = Strings.MediaLivePhoto
        } else {
            cell.resetStatusIcon()
            cell.accessibilityLabel = Strings.MediaPhoto
        }
        
        if let cachedImage = cacheManager.cached(ocId: metadata.ocId, etag: metadata.etag) {
            cell.setImage(cachedImage)
        } else {
            
            let path = dataService.store.getIconPath(metadata.ocId, metadata.etag)
            
            if FileManager().fileExists(atPath: path) {
                
                let image = UIImage(contentsOfFile: path)
                cell.setImage(image)
                
                if image != nil {
                    cacheManager.cache(metadata: metadata, image: image!)
                }
                
            }  else {
                
                if !pauseLoading {
                    cacheManager.download(metadata: metadata, delegate: self)
                }
            }
        }
        
        delegate.editCellUpdated(cell: cell, indexPath: indexPath)
    }
    
    private func processFavorites(type: Global.FilterType, from: Date?, to: Date?) {
        
        var snapshot = dataSource.snapshot()
        var displayed = snapshot.itemIdentifiers(inSection: 0)
        
        guard let result = dataService.processFavorites(displayedMetadataIds: displayed, displayedMetadatas: metadatas,  type: type, from: from, to: to) else {
            delegate.dataSourceUpdated(refresh: false)
            return
        }
        
        guard result.delete.count > 0 || result.add.count > 0 || result.update.count > 0 else {
            delegate.dataSourceUpdated(refresh: false)
            return
        }
        
        if result.delete.count > 0 {
            snapshot.deleteItems(result.delete)
            
            for deleted in result.delete {
                metadatas.removeValue(forKey: deleted)
            }
        }
        
        for update in result.update {
            if snapshot.itemIdentifiers.contains(update.id) {
                snapshot.reconfigureItems([update.id])
                metadatas[update.id] = update
            }
        }
        
        if result.add.count > 0 {
            
            if snapshot.numberOfItems == 0 {
                for add in result.add {
                    if !snapshot.itemIdentifiers.contains(add.id) {
                        snapshot.appendItems([add.id])
                        metadatas[add.id] = add
                    }
                }
            } else {
                
                displayed = snapshot.itemIdentifiers(inSection: 0)
                
                //find where each item to be added fits in the visible collection by date and possibly name
                for result in result.add {
                    
                    if snapshot.itemIdentifiers.contains(result.id) {
                        //Self.logger.debug("processFavorites() - \(result.fileNameView) exists. do not add again.")
                        continue
                    }
                    
                    metadatas[result.id] = result
                    
                    for visibleItem in displayed {
                        
                        let visibleMetadata = metadatas[visibleItem]
                        
                        if visibleMetadata == nil {
                            break
                        }
                        
                        let resultTime = result.date.timeIntervalSinceReferenceDate
                        let visibleTime = visibleMetadata!.date.timeIntervalSinceReferenceDate
                        
                        if resultTime > visibleTime {
                            snapshot.insertItems([result.id], beforeItem: visibleItem)
                            break
                        } else if resultTime == visibleTime {
                            if result.fileNameView > visibleMetadata!.fileNameView {
                                snapshot.insertItems([result.id], beforeItem: visibleItem)
                                break
                            }
                        }
                    }

                    if snapshot.itemIdentifiers.contains(result.id) == false {
                        snapshot.appendItems([result.id])
                    }
                }
            }
        }
        
        dataSource.apply(snapshot, animatingDifferences: true, completion: { [weak self] in
            self?.delegate.dataSourceUpdated(refresh: false)
        })
    }
    
    private func applyDatasourceChanges(metadatas: [Metadata], refresh: Bool) async {
        
        var adds : [Metadata.ID] = []
        var updates : [Metadata.ID] = []
        var snapshot = dataSource.snapshot()
        
        if refresh {
            snapshot.deleteAllItems()
            snapshot.appendSections([0])
            
            self.metadatas.removeAll()
        }
        
        for metadata in metadatas {
            if snapshot.indexOfItem(metadata.id) == nil {
                adds.append(metadata.id)
            } else {
                updates.append(metadata.id)
            }
            
            self.metadatas[metadata.id] = metadata
        }
        
        if adds.count > 0 {
            snapshot.appendItems(adds, toSection: 0)
        }
        
        if updates.count > 0 {
            snapshot.reconfigureItems(updates)
        }
        
        //Self.logger.debug("applyDatasourceChanges() - adds: \(adds.count) updates: \(updates.count)")
        
        delegate.fetchResultReceived(resultItemCount: metadatas.count)

        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(snapshot, animatingDifferences: true)
            self?.delegate.dataSourceUpdated(refresh: refresh)
        }
    }
}

extension FavoritesViewModel: DownloadPreviewOperationDelegate {
    
    func previewDownloaded(metadata: Metadata) {
        var snapshot = dataSource.snapshot()
        let displayed = snapshot.itemIdentifiers(inSection: 0)
        
        if displayed.contains(metadata.id) {
            
            let path = dataService.store.getIconPath(metadata.ocId, metadata.etag)
            
            if FileManager().fileExists(atPath: path) {
                snapshot.reconfigureItems([metadata.id])
                dataSource.apply(snapshot)
            }
        }
    }
}
