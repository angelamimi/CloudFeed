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
    
    var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    
    let delegate: MediaDelegate
    let dataService: DataService
    
    private var cancelSearch: Bool = false
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MediaViewModel.self)
    )
    
    init(delegate: MediaDelegate, dataService: DataService) {
        self.delegate = delegate
        self.dataService = dataService
    }
    
    func initDataSource(collectionView: UICollectionView) {
        
        dataSource = UICollectionViewDiffableDataSource<Int, tableMetadata>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, metadata: tableMetadata) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainCollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            Task { [weak self] in
                await self?.setImage(metadata: metadata, cell: cell, indexPath: indexPath)
            }
            return cell
        }
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
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
    
    func metadataSearch(toDate: Date, fromDate: Date?, offsetDate: Date?, offsetName: String?, refresh: Bool) {
        
        Task { [weak self] in
            guard let self else { return }
            
            cancelSearch = false
            
            if fromDate == nil {
                
                let days = -30
                guard let calculatedFromDate = Calendar.current.date(byAdding: .day, value: days, to: toDate) else { return }
                
                //saves metadata to be paginated
                let results = await search(toDate: toDate, fromDate: calculatedFromDate, offsetDate: offsetDate, offsetName: offsetName, limit: Global.shared.limit)
                
                //recursive call until enough results received or gone all the way back in time
                await processSearchResult(metadatas: results.metadatas, toDate: toDate, offsetDate: offsetDate, offsetName: offsetName, days: days, refresh: refresh)
                
            } else {
                
                //saves metadata to be paginated
                let results = await search(toDate: toDate, fromDate: fromDate!, offsetDate: offsetDate, offsetName: offsetName, limit: Global.shared.limit)
                
                guard let resultMetadatas = results.metadatas else {
                    delegate.searchResultReceived(resultItemCount: nil)
                    return
                }
                
                if cancelSearch { return }
                
                //display results
                applyDatasourceChanges(metadatas: resultMetadatas, refresh: refresh)
            }
        }
    }
    
    func filter(toDate: Date, fromDate: Date) {
        
        Task { [weak self] in
            guard let self else { return }
            
            cancelSearch = true //applying filter. stop the recursive search for more results if there is one
            
            let results = await search(toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, limit: Global.shared.limit)
            
            guard results.metadatas != nil else { return }
            
            //Self.logger.debug("filter() - added: \(results.added.count) total updated: \(results.updated.count) deleted: \(results.deleted.count)")
            applyDatasourceChanges(metadatas: results.metadatas!, refresh: true)
        }
    }
    
    func sync(toDate: Date, fromDate: Date) {
        
        Task { [weak self] in
            guard let self else { return }
            
            //Self.logger.debug("sync() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
            //Self.logger.debug("sync() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
            
            let results = await search(toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, limit: 0)
            
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
    
    func loadMore(filterFromDate: Date?) {
        
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
        
        metadataSearch(toDate: offsetDate!, fromDate: filterFromDate, offsetDate: offsetDate!, offsetName: offsetName!, refresh: false)
    }
    
    private func loadPreview(indexPath: IndexPath) async {
        
        guard let metadata = await dataSource.itemIdentifier(for: indexPath) else { return }
        
        await loadPreviewImageForMetadata(metadata, indexPath: indexPath)
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
    
    private func loadPreviewImageForMetadata(_ metadata: tableMetadata, indexPath: IndexPath) async {

        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            await self.dataService.downloadVideoPreview(metadata: metadata)
        } else if metadata.svg {
            await loadSVG(metadata: metadata)
        } else {
            await self.dataService.downloadPreview(metadata: metadata)
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
    
    private func search(toDate: Date, fromDate: Date, offsetDate: Date?, offsetName: String?, limit: Int) async -> (metadatas: [tableMetadata]?, added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata]) {
        
        //Self.logger.debug("search() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
        //Self.logger.debug("search() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        delegate.searching()
        
        let result = await dataService.searchMedia(toDate: toDate, fromDate: fromDate, offsetDate: offsetDate, offsetName: offsetName, limit: limit)
        
        //Self.logger.debug("search() - result metadatas count: \(result.metadatas.count) error?: \(result.error)")
        
        guard result.error == false else {
            return (nil, [], [], [])
        }
        
        let sorted = result.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
        
        return (sorted, result.added, result.updated, result.deleted)
    }
    
    private func processSearchResult(metadatas: [tableMetadata]?, toDate: Date, offsetDate: Date?, offsetName: String?, days: Int, refresh: Bool) async {
        
        if cancelSearch { return }
        
        guard let resultMetadatas = metadatas else {
            delegate.searchResultReceived(resultItemCount: nil)
            return
        }
        
        //display results
        applyDatasourceChanges(metadatas: resultMetadatas, refresh: refresh)
        
        if resultMetadatas.count >= Global.shared.pageSize {
            delegate.searchResultReceived(resultItemCount: resultMetadatas.count)
        } else {
            
            //not enough to fill a page. keep searching and collecting metadata by shifting the date span farther back in time
            
            guard let span = calculateSearchDates(toDate: toDate, days: days) else {
                //gone as far back as possible. break out of recursive call
                delegate.searchResultReceived(resultItemCount: resultMetadatas.count)
                return
            }
            
            //Self.logger.debug("processSearchResult() - toDate: \(span.toDate.formatted(date: .abbreviated, time: .standard))")
            //Self.logger.debug("processSearchResult() - fromDate: \(span.fromDate.formatted(date: .abbreviated, time: .standard))")

            let results = await search(toDate: span.toDate, fromDate: span.fromDate, offsetDate: offsetDate, offsetName: offsetName, limit: Global.shared.limit)
            await processSearchResult(metadatas: results.metadatas, toDate: span.toDate, offsetDate: offsetDate, offsetName: offsetName, days: span.spanDays, refresh: refresh)
        }
    }
    
    private func calculateSearchDates(toDate: Date, days: Int) -> (toDate: Date, fromDate: Date, spanDays: Int)? {
        
        var newDays: Int
        
        if days == -30 {
            newDays = -60
        } else if days == -60 {
            newDays = -90
        } else if days == -90 {
            newDays = -180
        } else if days == -180 {
            newDays = -999
        } else {
            return nil
        }
        
        //Self.logger.debug("calculateSearchDates() - newDays: \(String(newDays)) days: \(String(days))")
        
        var fromDate: Date
        
        if (newDays == -999) {
            fromDate = Date.distantPast
        } else {
            fromDate = Calendar.current.date(byAdding: .day, value: newDays, to: toDate)!
        }
        
        //Self.logger.debug("calculateSearchDates() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
        //Self.logger.debug("calculateSearchDates() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        return (toDate, fromDate, newDays)
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
    
    private func setImage(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        //Self.logger.debug("setImage() - name: \(metadata.fileNameView) imageSize: \(metadata.imageSize.debugDescription)")
        
        let previewPath = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
        
        if FileManager().fileExists(atPath: previewPath) {

            if metadata.gif || metadata.svg {
                await cell.setContentMode(aspectFit: true)
                await cell.clearBackground()
            }
            
            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                await cell.showVideoIcon()
            } else if metadata.livePhoto {
                await cell.showLivePhotoIcon()
            } else {
                await cell.resetStatusIcon()
            }
            
            let image = UIImage(contentsOfFile: previewPath)
            await cell.setImage(image)
            
        } else {
            
            await cell.setImage(nil)
            await loadPreview(indexPath: indexPath)

            //only update datasource if preview was actually downloaded
            if FileManager().fileExists(atPath: previewPath) {
                applyUpdateForMetadata(metadata)
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
            
            let previewPath = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
            let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!
            
            ImageUtility.loadSVGPreview(metadata: metadata, imagePath: imagePath, previewPath: previewPath)
        }
    }
}
