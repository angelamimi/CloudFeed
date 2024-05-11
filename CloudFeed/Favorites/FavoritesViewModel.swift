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

protocol FavoritesDelegate: AnyObject {
    func fetching()
    func dataSourceUpdated(refresh: Bool)
    func bulkEditFinished(error: Bool)
    func fetchResultReceived(resultItemCount: Int?)
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath)
}

final class FavoritesViewModel: NSObject {
    
    var pauseLoading: Bool = false
    
    private var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    
    private let delegate: FavoritesDelegate
    private let dataService: DataService
    private let cacheManager: CacheManager
    
    private var fetchTask: Task<Void, Never>? {
        willSet {
            fetchTask?.cancel()
        }
    }
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesViewModel.self)
    )
    
    init(delegate: FavoritesDelegate, dataService: DataService, cacheManager: CacheManager) {
        self.delegate = delegate
        self.dataService = dataService
        self.cacheManager = cacheManager
    }
    
    func initDataSource(collectionView: UICollectionView) {
        
        dataSource = UICollectionViewDiffableDataSource<Int, tableMetadata>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, metadata: tableMetadata) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            self.populateCell(metadata: metadata, cell: cell, indexPath: indexPath, collectionView: collectionView)
            return cell
        }

        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
    }
    
    func getItemAtIndexPath(_ indexPath: IndexPath) -> tableMetadata? {
        return dataSource.itemIdentifier(for: indexPath)
    }
    
    func currentItemCount() -> Int {
        let snapshot = dataSource.snapshot()
        return snapshot.numberOfItems(inSection: 0)
    }
    
    func getItems() -> [tableMetadata] {
        let snapshot = dataSource.snapshot()
        return snapshot.itemIdentifiers(inSection: 0)
    }
    
    func resetDataSource() {
        guard dataSource != nil else { return }
        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.appendSections([0])
        dataSource!.applySnapshotUsingReloadData(snapshot)
    }
    
    func loadMore(filterFromDate: Date?, filterToDate: Date?) {
        
        var offsetDate: Date?
        var offsetName: String?

        let snapshot = dataSource.snapshot()
        
        if (snapshot.numberOfItems(inSection: 0) > 0) {
            let metadata = snapshot.itemIdentifiers(inSection: 0).last
            if metadata != nil {
                offsetName = metadata?.fileNameView
                offsetDate = metadata!.date as Date
                /*  intentionally overlapping results. could shift the date here by a second to exclude previous results,
                    but might lose new results from files with dates in the same second */
                //Self.logger.debug("loadMore() - offsetDate: \(offsetDate!.formatted(date: .abbreviated, time: .standard))")
            }
        }

        guard let offsetDate = offsetDate else { return }
        guard let offsetName = offsetName else { return }
        
        //Self.logger.debug("loadMore() - offsetName: \(offsetName) offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        sync(offsetDate: offsetDate, offsetName: offsetName, filterFromDate: filterFromDate, filterToDate: filterToDate)
    }
    
    func reload() {
        
        var snapshot = dataSource.snapshot()
        
        guard snapshot.numberOfSections > 0 else { return }
        snapshot.reloadSections([0])
        
        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    func fetch(refresh: Bool) {
        
        delegate.fetching()
                
        fetchTask = Task { [weak self] in
            guard let self else { return }
            
            let error = await dataService.getFavorites()
            
            if Task.isCancelled { return }
            
            handleFavoriteResult(error: error)
            
            let resultMetadatas = dataService.paginateFavoriteMetadata()
            await applyDatasourceChanges(metadatas: resultMetadatas, refresh: refresh)
        }
    }
    
    func filter(from: Date, to: Date) {
        
        delegate.fetching()
                
        fetchTask = Task { [weak self] in
            guard let self else { return }
            
            let error = await dataService.getFavorites()
            
            if Task.isCancelled { return }
            
            handleFavoriteResult(error: error)
            
            let resultMetadatas = await dataService.filterFavorites(from: from, to: to)
            await applyDatasourceChanges(metadatas: resultMetadatas, refresh: true)
        }
    }
    
    func syncFavs(from: Date?, to: Date?) {
        
        delegate.fetching()
                
        fetchTask = Task { [weak self] in
            guard let self else { return }
            
            let error = await dataService.getFavorites()
            
            if Task.isCancelled { return }
            
            handleFavoriteResult(error: error)
            
            processFavorites(from: from, to: to)
        }
    }
    
    func bulkEdit(indexPaths: [IndexPath]) async {
        
        var snapshot = dataSource.snapshot()
        var error = false
        
        for indexPath in indexPaths {
            
            guard let metadata = await dataSource.itemIdentifier(for: indexPath) else { continue }
            
            let result = await dataService.toggleFavoriteMetadata(metadata)
            
            if result == nil {
                //Self.logger.error("bulkEdit() - failed to save favorite ocid: \(metadata.ocId)")
                error = true
            } else {
                snapshot.deleteItems([result!])
            }
        }
        
        snapshot.reloadSections([0])
        
        let applySnapshot = snapshot
        let applyError = error
        
        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(applySnapshot, animatingDifferences: true)
            self?.delegate.bulkEditFinished(error: applyError)
        }
    }
    
    func refreshItems(_ refreshItems: [IndexPath]) {
        
        let items = refreshItems.compactMap { dataSource.itemIdentifier(for: $0) }
        
        //Self.logger.debug("refreshItems() - items count: \(items.count)")
        
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(items)
        dataSource.apply(snapshot)
    }
    
    private func handleFavoriteResult(error: Bool) {
        if error {
            delegate.fetchResultReceived(resultItemCount: nil)
        }
    }
    
    private func sync(offsetDate: Date, offsetName: String, filterFromDate: Date?, filterToDate: Date?) {
        
        delegate.fetching()
        
        Task { [weak self] in
            guard let self else { return }

            _ = await self.dataService.getFavorites()
            
            let resultMetadatas = self.dataService.paginateFavoriteMetadata(fromDate: filterFromDate, toDate: filterToDate, offsetDate: offsetDate, offsetName: offsetName)
            await applyDatasourceChanges(metadatas: resultMetadatas, refresh: false)
        }
    }
    
    private func loadPreview(indexPath: IndexPath) async {
        
        guard let metadata = await dataSource.itemIdentifier(for: indexPath) else { return }
        
        await self.loadPreviewImageForMetadata(metadata, indexPath: indexPath)
    }
    
    private func loadPreviewImageForMetadata(_ metadata: tableMetadata, indexPath: IndexPath) async {

        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            await self.dataService.downloadVideoPreview(metadata: metadata)
        } else if metadata.svg {
            await loadSVG(metadata: metadata)
        } else {
            await self.dataService.downloadPreview(metadata: metadata)
        }
    }
    
    private func populateCell(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath, collectionView: UICollectionView) {
        
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            cell.showVideoIcon()
        } else if metadata.livePhoto {
            cell.showLivePhotoIcon()
        } else {
            cell.resetStatusIcon()
        }
        
        if let cachedImage = cacheManager.cached(ocId: metadata.ocId, etag: metadata.etag) {
            cell.setImage(cachedImage, metadata.transparent)
        } else {
            
            let path = dataService.store.getIconPath(metadata.ocId, metadata.etag)
            
            if FileManager().fileExists(atPath: path) {
                
                let image = UIImage(contentsOfFile: path)
                cell.setImage(image, metadata.transparent)
                
                if image != nil {
                    cacheManager.cache(metadata: metadata, image: image!)
                }
                
            }  else {
                
                if !pauseLoading {
                    Task {
                        let thumbnail = await cacheManager.fetch(metadata: metadata, indexPath: indexPath)
                        guard let cell = await collectionView.cellForItem(at: indexPath) as? CollectionViewCell else { return }
                        await cell.setImage(thumbnail, metadata.transparent)
                    }
                }
            }
        }
        
        delegate.editCellUpdated(cell: cell, indexPath: indexPath)
    }
    
    private func processFavorites(from: Date?, to: Date?) {
        
        var snapshot = dataSource.snapshot()
        var displayed = snapshot.itemIdentifiers(inSection: 0)
        
        guard let result = dataService.processFavorites(displayedMetadatas: displayed, from: from, to: to) else {
            delegate.dataSourceUpdated(refresh: false)
            return
        }
        
        guard result.delete.count > 0 || result.add.count > 0 else {
            delegate.dataSourceUpdated(refresh: false)
            return
        }
        
        if result.delete.count > 0 { snapshot.deleteItems(result.delete) }
        
        displayed = snapshot.itemIdentifiers(inSection: 0)
        
        if result.add.count > 0 {
            
            if snapshot.numberOfItems == 0 {
                for add in result.add {
                    if !snapshot.itemIdentifiers.contains(add) {
                        snapshot.appendItems([add])
                    }
                }
            } else {
                
                //find where each item to be added fits in the visible collection by date and possibly name
                for result in result.add {
                    
                    if snapshot.itemIdentifiers.contains(result) {
                        //Self.logger.debug("processFavorites() - \(result.fileNameView) exists. do not add again.")
                        continue
                    }
                    
                    for visibleItem in displayed {
                        
                        let resultTime = result.date.timeIntervalSinceReferenceDate
                        let visibleTime = visibleItem.date.timeIntervalSinceReferenceDate
                        
                        if resultTime > visibleTime {
                            snapshot.insertItems([result], beforeItem: visibleItem)
                            break
                        } else if resultTime == visibleTime {
                            if result.fileNameView > visibleItem.fileNameView {
                                snapshot.insertItems([result], beforeItem: visibleItem)
                                break
                            }
                        }
                    }

                    if snapshot.itemIdentifiers.contains(result) == false {
                        snapshot.appendItems([result])
                    }
                }
            }
        }
        
        let applySnapshot = snapshot
        
        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(applySnapshot, animatingDifferences: true, completion: { [weak self] in
                self?.delegate.dataSourceUpdated(refresh: false)
            })
        }
    }
    
    private func applyUpdateForMetadata(_ metadata: tableMetadata) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            var snapshot = self.dataSource.snapshot()
            
            if snapshot.itemIdentifiers.contains(metadata) {
                snapshot.reconfigureItems([metadata])
                self.dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
    }
    
    private func applyDatasourceChanges(metadatas: [tableMetadata], refresh: Bool) async {
        
        var ocIdAdd : [tableMetadata] = []
        var ocIdUpdate : [tableMetadata] = []
        var snapshot = dataSource.snapshot()
        
        if refresh {
            snapshot.deleteAllItems()
            snapshot.appendSections([0])
        }
        
        for metadata in metadatas {
            if snapshot.indexOfItem(metadata) == nil {
                ocIdAdd.append(metadata)
            } else {
                ocIdUpdate.append(metadata)
            }
        }
        
        if ocIdAdd.count > 0 {
            snapshot.appendItems(ocIdAdd, toSection: 0)
        }
        
        if ocIdUpdate.count > 0 {
            snapshot.reloadItems(ocIdUpdate)
        }
        
        //Self.logger.debug("applyDatasourceChanges() - ocIdAdd: \(ocIdAdd.count) ocIdUpdate: \(ocIdUpdate.count)")
        
        let applySnapshot = snapshot
        
        DispatchQueue.main.async {[weak self] in
            guard let self else { return }
            self.dataSource.apply(applySnapshot, animatingDifferences: true)
            self.delegate.dataSourceUpdated(refresh: refresh)
        }
    }
    
    private func loadSVG(metadata: tableMetadata) async {
        
        if !dataService.store.fileExists(metadata) && metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
            
            await dataService.download(metadata: metadata, selector: "")
            
            let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!
            let iconPath = dataService.store.getIconPath(metadata.ocId, metadata.etag)
            
            ImageUtility.loadSVGPreview(metadata: metadata, imagePath: imagePath, previewPath: iconPath)
        }
    }
}
