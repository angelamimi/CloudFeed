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

@MainActor
protocol MediaDelegate: AnyObject {
    func dataSourceUpdated(refresh: Bool)
    func favoriteUpdated(error: Bool)
    func searching()
    func searchResultReceived(resultItemCount: Int?)
}

@MainActor
final class MediaViewModel: NSObject {
    
    var pauseLoading: Bool = false
    
    private var dataSource: UICollectionViewDiffableDataSource<Int, Metadata.ID>!
    
    private let delegate: MediaDelegate
    private let dataService: DataService
    let cacheManager: CacheManager
    
    private var metadatas: [Metadata.ID: Metadata] = [:]
    
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
        
        super.init()
    }
    
    func initDataSource(collectionView: UICollectionView) {

        dataSource = UICollectionViewDiffableDataSource<Int, Metadata.ID>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, metadataId: Metadata.ID) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainCollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            self.populateCell(metadataId: metadataId, cell: cell, indexPath: indexPath, collectionView: collectionView)
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
    
    func getItemAtIndexPath(_ indexPath: IndexPath) -> Metadata? {

        if let id = dataSource.itemIdentifier(for: indexPath) {
            return metadatas[id]
        }
        return nil
    }
    
    func getLastItem() -> Metadata? {
        
        let snapshot = dataSource.snapshot()

        if (snapshot.numberOfItems(inSection: 0) > 0) {

            if let id = snapshot.itemIdentifiers(inSection: 0).last {
                return metadatas[id]
            }
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
    
    func cancelLoads() {
        cacheManager.cancelAll()
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

            syncDatasource(added: added, updated: updated, deleted: results.deleted)
        }
    }
    
    func loadMore(type: Global.FilterType, filterFromDate: Date?) {
        
        var offsetDate: Date?
        var offsetName: String?
        
        let snapshot = dataSource.snapshot()
        
        if (snapshot.numberOfItems(inSection: 0) > 0) {
            if let id = snapshot.itemIdentifiers(inSection: 0).last {
                if let metadata = metadatas[id] {
                    /*  intentionally overlapping results. could shift the date here by a second to exclude previous results,
                     but might lose items with dates in the same second */
                    offsetDate = metadata.date as Date
                    offsetName = metadata.fileNameView
                }
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
        var snapshot = dataSource.snapshot()
        
        snapshot.reconfigureItems(items)
        dataSource.apply(snapshot)
    }

    func toggleFavorite(metadata: Metadata) {
        
        Task { [weak self] in
            guard let self else { return }
            
            let result = await dataService.toggleFavoriteMetadata(metadata)

            if result == nil {
                self.delegate.favoriteUpdated(error: true)
            } else {

                metadatas[metadata.id]?.favorite = result!.favorite
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    
                    var snapshot = self.dataSource.snapshot()
                    snapshot.reconfigureItems([metadata.id])
                    
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                    self.delegate.favoriteUpdated(error: false)
                }
            }
        }
    }
    
    private func getAddedMetadata(metadatas: [Metadata]) -> [Metadata] {

        let snapshot = dataSource.snapshot()
        let currentMetadatas = snapshot.itemIdentifiers(inSection: 0)
        var addedFavorites: [Metadata] = []
        
        for fetchedMetadata in metadatas {
            if currentMetadatas.first(where: { $0 == fetchedMetadata.id }) == nil {
                addedFavorites.append(fetchedMetadata)
            }
        }
        
        return addedFavorites
    }
    
    private func getUpdatedFavorites(metadatas: [Metadata]) -> [Metadata] {
        
        let snapshot = dataSource.snapshot()
        let currentMetadataIds = snapshot.itemIdentifiers(inSection: 0)
        var upadatedFavorites: [Metadata] = []
        
        for currentMetadataId in currentMetadataIds {
            if let result = metadatas.first(where: { $0.id == currentMetadataId }) {
                
                if var currentMetadata = self.metadatas[currentMetadataId] {

                    if result.favorite != currentMetadata.favorite {
                        currentMetadata.favorite = result.favorite
                        upadatedFavorites.append(currentMetadata)
                    }
                }
            }
        }
        return upadatedFavorites
    }
    
    private func syncDatasource(added: [Metadata], updated: [Metadata], deleted: [Metadata]) {
        
        if added.count == 0 && updated.count == 0 && deleted.count == 0 {
            self.delegate.dataSourceUpdated(refresh: false)
            return
        }
        
        var snapshot = dataSource.snapshot()
        let displayedMetadata = snapshot.itemIdentifiers(inSection: 0)
        
        if displayedMetadata.count > 0 {
        
            for delete in deleted {
                if displayedMetadata.contains(delete.id) {
                    snapshot.deleteItems([delete.id])
                }

                metadatas.removeValue(forKey: delete.id)
            }
            
            for update in updated {
                if let displayed = displayedMetadata.first(where: { $0 == update.id }) {
                    if metadatas.keys.contains(displayed) {
                        metadatas[displayed]?.favorite = update.favorite
                        metadatas[displayed]?.fileNameView = update.fileNameView
                        snapshot.reconfigureItems([displayed])
                    }
                }
            }
        }
        
        if added.count > 0 {
            
            if snapshot.numberOfItems == 0 {
                for add in added {
                    if !snapshot.itemIdentifiers.contains(add.id) {
                        metadatas[add.id] = add
                        snapshot.appendItems([add.id])
                    }
                }
            } else {
                
                //find where each item to be added fits in the visible collection by date and possibly name
                for result in added {
                    
                    if snapshot.itemIdentifiers.contains(result.id) {
                        continue
                    }
                    
                    metadatas[result.id] = result
                    
                    for visibleItem in displayedMetadata {
                        
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
        
        dataSource.apply(snapshot, animatingDifferences: true)
        delegate.dataSourceUpdated(refresh: false)
    }
    
    private func search(type: Global.FilterType, toDate: Date, fromDate: Date, offsetDate: Date?, offsetName: String?, limit: Int) async -> (metadatas: [Metadata]?, added: [Metadata], updated: [Metadata], deleted: [Metadata]) {
        
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
    
    private func applyDatasourceChanges(metadatas: [Metadata], refresh: Bool) {

        var snapshot = dataSource.snapshot()
        var adds : [Metadata.ID] = []
        var updates : [Metadata.ID] = []
        
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
            snapshot.appendItems(adds)
        }
        
        if updates.count > 0 {
            snapshot.reconfigureItems(updates)
        }
        
        dataSource.apply(snapshot, animatingDifferences: true, completion: { [weak self] in
            self?.delegate.dataSourceUpdated(refresh: refresh)
        })
    }
    
    private func populateCell(metadataId: Metadata.ID, cell: CollectionViewCell, indexPath: IndexPath, collectionView: UICollectionView) {
        
        guard let metadata = metadatas[metadataId] else { return }
        
        if metadata.video {
            //Self.logger.debug("populateCell() - show video icon \(metadata.fileNameView)")
            cell.showVideoIcon()
        } else if metadata.livePhoto {
            //Self.logger.debug("populateCell() - show live icon \(metadata.fileNameView)")
            cell.showLivePhotoIcon()
        } else {
            //Self.logger.debug("populateCell() - reset icon \(metadata.fileNameView)")
            cell.resetStatusIcon()
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
                
            } else {
                if !pauseLoading {
                    cacheManager.fetch(metadata: metadata, delegate: self)
                }
            }
        }
    }
}

extension MediaViewModel: DownloadOperationDelegate {
    
    func imageDownloaded(metadata: Metadata) {
        
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
