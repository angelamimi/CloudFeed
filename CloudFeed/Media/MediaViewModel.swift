//
//  MediaViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/12/23.
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
import SVGKit
import UIKit

protocol MediaDelegate: AnyObject {
    func dataSourceUpdated(refresh: Bool)
    func favoriteUpdated(error: Bool)
    
    func searching()
    func searchResultReceived(resultItemCount: Int?)
}

final class MediaViewModel: NSObject {
    
    var pauseLoading: Bool = false
    
    private var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    
    private let delegate: MediaDelegate
    private let dataService: DataService
    private let cacheManager: CacheManager
    
    private var fetchTask: Task<Void, Never>? {
        willSet {
            fetchTask?.cancel()
        }
    }
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MediaViewModel.self)
    )
    
    init(delegate: MediaDelegate, dataService: DataService, cacheManager: CacheManager) {
        self.delegate = delegate
        self.dataService = dataService
        self.cacheManager = cacheManager
    }
    
    func initDataSource(collectionView: UICollectionView) {

        dataSource = UICollectionViewDiffableDataSource<Int, tableMetadata>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, metadata: tableMetadata) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainCollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            
            Self.logger.debug("initDataSource() - file: \(metadata.fileNameView) indexPath: \(indexPath.debugDescription) calling populateCell")
            self.populateCell(metadata: metadata, cell: cell, indexPath: indexPath, collectionView: collectionView)
            return cell
        }
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
    }
    
    func clearCache() {
        cacheManager.clear()
    }
    
    func resetDataSource() {
        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
    }
    
    func currentItemCount() -> Int {
        let snapshot = dataSource.snapshot()
        return snapshot.numberOfItems(inSection: 0)
    }
    
    func getItems() -> [tableMetadata] {
        let snapshot = dataSource.snapshot()
        return snapshot.itemIdentifiers(inSection: 0)
    }
    
    func getItemAtIndexPath(_ indexPath: IndexPath) -> tableMetadata? {
        return dataSource.itemIdentifier(for: indexPath)
    }
    
    func getLastItem() -> tableMetadata? {
        
        let snapshot = dataSource.snapshot()

        if (snapshot.numberOfItems(inSection: 0) > 0) {
            return snapshot.itemIdentifiers(inSection: 0).last
        }
        
        return nil
    }
    
    func getLayoutType() -> String {
        return dataService.store.getMediaLayoutType()
    }
    
    func updateLayoutType(_ type: String) {
        dataService.store.setMediaLayoutType(type)
    }
    
    func getColumnCount() -> Int {
        return dataService.store.getMediaColumnCount()
    }
    
    func saveColumnCount(_ columnCount: Int) {
        dataService.store.setMediaColumnCount(columnCount)
    }
    
    func metadataSearch(type: Global.FilterType, toDate: Date, fromDate: Date, offsetDate: Date?, offsetName: String?, refresh: Bool) {

        fetchTask = Task { [weak self] in
            guard let self else { return }
            
            let results = await search(type: type, toDate: toDate, fromDate: fromDate, offsetDate: offsetDate, offsetName: offsetName, limit: Global.shared.limit)
            
            guard let resultMetadatas = results.metadatas else {
                delegate.searchResultReceived(resultItemCount: nil)
                return
            }
            
            if Task.isCancelled { return }
            
            applyDatasourceChanges(metadatas: resultMetadatas, refresh: refresh)
        }
    }
    
    func filter(type: Global.FilterType, toDate: Date, fromDate: Date) {
        
        fetchTask = Task { [weak self] in
            guard let self else { return }
            
            let results = await search(type: type, toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, limit: Global.shared.limit)
            
            if Task.isCancelled { return }
            
            guard results.metadatas != nil else { return }
            
            //Self.logger.debug("filter() - added: \(results.added.count) total updated: \(results.updated.count) deleted: \(results.deleted.count)")
            applyDatasourceChanges(metadatas: results.metadatas!, refresh: true)
        }
    }
    
    func sync(type: Global.FilterType, toDate: Date, fromDate: Date) {
        
        fetchTask = Task { [weak self] in
            guard let self else { return }
            
            //Self.logger.debug("sync() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
            //Self.logger.debug("sync() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
            
            let results = await search(type: type, toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, limit: 0)
            
            if Task.isCancelled { return }
            
            guard results.metadatas != nil else { return }
            
            var added = getAddedMetadata(metadatas: results.metadatas!)
            added.append(contentsOf: results.added)
            
            //results.updated accounts for favorites updated remotely. Also need to account for favorites updated locally.
            //have to compare what is displayed with what was just fetched
            var updated = getUpdatedFavorites(metadatas: results.metadatas!)
            updated.append(contentsOf: results.updated)
            
            //Self.logger.debug("sync() - count: \(results.metadatas!.count)")
            //Self.logger.debug("sync() - added: \(added.count) total updated: \(updated.count) deleted: \(results.deleted.count)")
            syncDatasource(added: added, updated: updated, deleted: results.deleted)
        }
    }
    
    func loadMore(type: Global.FilterType, filterFromDate: Date?) {
        
        var offsetDate: Date?
        var offsetName: String?
        
        let snapshot = dataSource.snapshot()
        
        if (snapshot.numberOfItems(inSection: 0) > 0) {
            let metadata = snapshot.itemIdentifiers(inSection: 0).last
            if metadata != nil {
                /*  intentionally overlapping results. could shift the date here by a second to exclude previous results,
                 but might lose items with dates in the same second */
                offsetDate = metadata!.date as Date
                offsetName = metadata!.fileNameView
                //Self.logger.debug("loadMore() - offsetName: \(offsetName!) offsetDate: \(offsetDate!.formatted(date: .abbreviated, time: .standard))")
            }
        }
        
        guard offsetDate != nil && offsetName != nil else { return }
        
        if filterFromDate == nil {
            metadataSearch(type: type, toDate: offsetDate!, fromDate: Date.distantPast, offsetDate: offsetDate!, offsetName: offsetName!, refresh: false)
        } else {
            metadataSearch(type: type, toDate: offsetDate!, fromDate: filterFromDate!, offsetDate: offsetDate!, offsetName: offsetName!, refresh: false)
        }
    }

    func refreshItems(_ refreshItems: [IndexPath]) {
        
        let items = refreshItems.compactMap { dataSource.itemIdentifier(for: $0) }
        
        //Self.logger.debug("refreshItems() - items count: \(items.count)")
        
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(items)
        dataSource.apply(snapshot)
    }

    func toggleFavorite(metadata: tableMetadata) {
        
        Task { [weak self] in
            guard let self else { return }
            
            let result = await dataService.toggleFavoriteMetadata(metadata)

            if result == nil {
                self.delegate.favoriteUpdated(error: true)
            } else {

                metadata.favorite = result!.favorite
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    
                    var snapshot = self.dataSource.snapshot()
                    snapshot.reconfigureItems([metadata])
                    
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                    self.delegate.favoriteUpdated(error: false)
                }
            }
        }
    }
    
    private func getAddedMetadata(metadatas: [tableMetadata]) -> [tableMetadata] {

        let snapshot = dataSource.snapshot()
        let currentMetadatas = snapshot.itemIdentifiers(inSection: 0)
        var addedFavorites: [tableMetadata] = []
        
        for fetchedMetadata in metadatas {
            if currentMetadatas.first(where: { $0.ocId == fetchedMetadata.ocId }) == nil {
                addedFavorites.append(fetchedMetadata)
            }
        }
        
        return addedFavorites
    }
    
    private func getUpdatedFavorites(metadatas: [tableMetadata]) -> [tableMetadata] {
        
        let snapshot = dataSource.snapshot()
        let currentMetadatas = snapshot.itemIdentifiers(inSection: 0)
        var upadatedFavorites: [tableMetadata] = []
        
        for currentMetadata in currentMetadatas {
            if let result = metadatas.first(where: { $0.ocId == currentMetadata.ocId }) {
                if result.favorite != currentMetadata.favorite {
                    currentMetadata.favorite = result.favorite
                    upadatedFavorites.append(currentMetadata)
                }
                    
            }
        }
        return upadatedFavorites
    }
    
    private func syncDatasource(added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata]) {
        
        var snapshot = dataSource.snapshot()
        let displayedMetadata = snapshot.itemIdentifiers(inSection: 0)
        
        if displayedMetadata.count > 0 {
        
            for delete in deleted {
                if displayedMetadata.contains(delete) {
                    snapshot.deleteItems([delete])
                }
            }
            
            for update in updated {
                if let displayed = displayedMetadata.first(where: { $0.ocId == update.ocId }) {
                    displayed.favorite = update.favorite
                    displayed.fileNameView = update.fileNameView
                    snapshot.reloadItems([displayed])
                }
            }
        }
        
        if added.count > 0 {
            
            if snapshot.numberOfItems == 0 {
                for add in added {
                    if !snapshot.itemIdentifiers.contains(add) {
                        snapshot.appendItems([add])
                    }
                }
            } else {
                
                //find where each item to be added fits in the visible collection by date and possibly name
                for result in added {
                    
                    if snapshot.itemIdentifiers.contains(result) {
                        //Self.logger.debug("syncDatasource() - \(result.fileNameView) exists. do not add again.")
                        continue
                    }
                    
                    for visibleItem in displayedMetadata {
                        
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
        
        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(snapshot, animatingDifferences: true)
            self?.delegate.dataSourceUpdated(refresh: false)
        }
    }
    
    private func search(type: Global.FilterType, toDate: Date, fromDate: Date, offsetDate: Date?, offsetName: String?, limit: Int) async -> (metadatas: [tableMetadata]?, added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata]) {
        
        //Self.logger.debug("search() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
        //Self.logger.debug("search() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        delegate.searching()
        
        let result = await dataService.searchMedia(type: type, toDate: toDate, fromDate: fromDate, offsetDate: offsetDate, offsetName: offsetName, limit: limit)
        
        //Self.logger.debug("search() - result metadatas count: \(result.metadatas.count) error?: \(result.error)")
        
        guard result.error == false else {
            return (nil, [], [], [])
        }
        
        let sorted = result.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
        
        return (sorted, result.added, result.updated, result.deleted)
    }
    
    private func applyDatasourceChanges(metadatas: [tableMetadata], refresh: Bool) {

        var snapshot = dataSource.snapshot()
        var ocIdAdd : [tableMetadata] = []
        var ocIdUpdate : [tableMetadata] = []
        
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
            snapshot.appendItems(ocIdAdd)
        }
        
        if ocIdUpdate.count > 0 {
            snapshot.reconfigureItems(ocIdUpdate)
        }
            
        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(snapshot, animatingDifferences: true, completion: { [weak self] in
                self?.delegate.dataSourceUpdated(refresh: refresh)
            })
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
                
            } else {
                
                if !pauseLoading {
                    Task { [weak self] in
                        guard let self else { return }
                        //Self.logger.debug("populateCell() - file: \(metadata.fileNameView) calling fetch")
                        let thumbnail = await self.cacheManager.fetch(metadata: metadata, indexPath: indexPath)
                        guard let cell = await collectionView.cellForItem(at: indexPath) as? CollectionViewCell else { return }
                        await cell.setImage(thumbnail, metadata.transparent)
                    }
                }
            }
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
    
    private func loadSVG(metadata: tableMetadata) async {

        if !dataService.store.fileExists(metadata) && metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
            
            await dataService.download(metadata: metadata, selector: "")
            
            let iconPath = dataService.store.getIconPath(metadata.ocId, metadata.etag)
            let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!
            
            ImageUtility.loadSVGPreview(metadata: metadata, imagePath: imagePath, previewPath: iconPath)
        }
    }
}
