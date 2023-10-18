//
//  MediaViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/12/23.
//

import NextcloudKit
import os.log
import UIKit

protocol MediaDelegate: AnyObject {
    func dataSourceUpdated()
    
    func searching()
    func searchResultReceived(resultItemCount: Int?)
}

final class MediaViewModel: NSObject {
    
    var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    let delegate: MediaDelegate
    let dataService: DataService
    
    private let loadMoreThreshold = -80.0
    private let groupSize = 2 //thumbnail fetches executed concurrently
    //private var greaterDays = -30
    
    private var currentPageItemCount = 0
    //private var currentMetadataCount = 0
    
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
            Task {
                await self.setImage(metadata: metadata, cell: cell, indexPath: indexPath)
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
        dataSource!.applySnapshotUsingReloadData(snapshot)
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
            let metadata = snapshot.itemIdentifiers(inSection: 0).last
            //Self.logger.debug("getLastItem() - date: \(metadata?.date) name: \(metadata?.fileNameView ?? "")")
            return metadata
        }
        
        return nil
    }
    
    func metadataSearch(offsetDate: Date, limit: Int) {
        
        Self.logger.debug("metadataSearch() - offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        
        let days = -30
        guard let fromDate = Calendar.current.date(byAdding: .day, value: days, to: offsetDate) else { return }
        
        Self.logger.debug("metadataSearch() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        Task {
            let results = await search(toDate: offsetDate, fromDate: fromDate, limit: limit) //saves metadata to be paginated
            await processSearchResult(results: results, toDate: offsetDate, fromDate: fromDate, days: days) //recursive call until enough results received or gone all the way back in time

            let resultMetadatas = await paginateMetadata(toDate: offsetDate, fromDate: fromDate, offsetDate: nil, offsetName: nil)
            await processPaginationResult(resultMetadatas: resultMetadatas, toDate: offsetDate, fromDate: fromDate, days: days, loadMoreMetadata: false)
        }
    }
    
    func sync(toDate: Date, fromDate: Date) {
        Task {
            let results = await search(toDate: toDate, fromDate: fromDate, limit: Global.shared.pageSize)
            guard results.metadatas != nil else { return }
            processSync(metadatas: results.metadatas!, deleteOcIds: results.deleteOcIds)
        }
    }
    
    func loadMore() {
        
        var offsetDate: Date?

        let snapshot = dataSource.snapshot()
        
        if (snapshot.numberOfItems(inSection: 0) > 0) {
            let metadata = snapshot.itemIdentifiers(inSection: 0).last
            if metadata != nil {
                offsetDate = metadata!.date as Date
                /*  intentionally overlapping results. could shift the date here by a second to exclude previous results,
                    but might lose new results from files with dates in the same second */
                Self.logger.debug("loadMore() - offsetDate: \(offsetDate!.formatted(date: .abbreviated, time: .standard))")
            }
        }

        guard let offsetDate = offsetDate else { return }
        
        Self.logger.debug("loadMore() - offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        
        metadataSearch(offsetDate: offsetDate, limit: 300)
    }
    
    func loadPreview(indexPath: IndexPath) {
        
        guard let metadata = dataSource.itemIdentifier(for: indexPath) else { return }
        
        if !FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            loadPreviewImageForMetadata(metadata)
        }
    }
    
    private func loadPreviewImageForMetadata(_ metadata: tableMetadata) {
        
        Task {
            
            Self.logger.debug("loadImageForMetadata() - ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
            
            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                await self.dataService.downloadVideoPreview(metadata: metadata)
            } else if metadata.contentType == "image/svg+xml" || metadata.fileExtension == "svg" {
                //TODO: Implement svg fetch. Need a library that works.
            } else {
                await self.dataService.downloadPreview(metadata: metadata)
            }
            
            guard FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) else {
                Self.logger.debug("loadImageForMetadata() - NO IMAGE ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
                return
            }
            
            Self.logger.debug("loadImageForMetadata() - GOT IMAGE REFRESH CELL ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                var snapshot = self.dataSource.snapshot()
                snapshot.reloadItems([metadata])
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }
    
    private func processSync(metadatas: [tableMetadata], deleteOcIds: [String]) {
        
        var snapshot = dataSource.snapshot()
        var delete: [tableMetadata] = []
        
        for currentMetadata in snapshot.itemIdentifiers(inSection: 0) {
            if deleteOcIds.contains(currentMetadata.ocId) {
                delete.append(currentMetadata)
            }
        }
        
        Self.logger.debug("processSync() - delete count: \(delete.count)")
        
        if delete.count > 0 {
            snapshot.deleteItems(delete)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dataSource.apply(snapshot, animatingDifferences: true, completion: {
                self.applyDatasourceChanges(metadatas: metadatas)
            })
        }
    }
    
    private func search(toDate: Date, fromDate: Date, limit: Int) async -> (metadatas: [tableMetadata]?, deleteOcIds: [String]) {
        
        Self.logger.debug("search() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
        Self.logger.debug("search() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        delegate.searching()
        
        let result = await dataService.searchMedia(toDate: toDate, fromDate: fromDate, limit: limit)
        
        Self.logger.debug("search() - result metadatas count: \(result.metadatas.count) error?: \(result.error)")
        
        guard result.error == false else {
            Self.logger.error("search() - error") //TODO: Alert user of error?
            return (nil, [])
        }
        
        let sorted = result.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
        
        /*for metadata in sorted {
            Self.logger.debug("search() - date: \(metadata.date) fileNameView: \(metadata.fileNameView)")
        }*/
        
        //let idArray = sorted.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("search() - sorted: \(idArray)")
        
        return (sorted, result.deleteOcIds)
    }
    
    private func processSearchResult(results: (metadatas: [tableMetadata]?, deleteOcIds: [String]), toDate: Date, fromDate: Date, days: Int) async {
        
        guard let resultMetadatas = results.metadatas else {
            delegate.searchResultReceived(resultItemCount: nil)
            return
        }
        
        Self.logger.debug("processSearchResult() - resultMetadatas count: \(resultMetadatas.count)")
        
        if resultMetadatas.count >= Global.shared.metadataPageSize {
            delegate.searchResultReceived(resultItemCount: resultMetadatas.count)
        } else {
            
            //not enough to fill a page. keep searching and collecting metadata by shifting the date span farther back in time
            
            guard let span = calculateSearchDates(toDate: toDate, days: days) else {
                //gone as far back as possible. break out of recursive call
                delegate.searchResultReceived(resultItemCount: resultMetadatas.count)
                return
            }
            
            Self.logger.debug("processSearchResult() - toDate: \(span.toDate.formatted(date: .abbreviated, time: .standard))")
            Self.logger.debug("processSearchResult() - fromDate: \(span.fromDate.formatted(date: .abbreviated, time: .standard))")
            Self.logger.debug("processSearchResult() - spanDays: \(span.spanDays)")

            let results = await search(toDate: span.toDate, fromDate: span.fromDate, limit: Global.shared.metadataPageSize)
            await processSearchResult(results: results, toDate: span.toDate, fromDate: span.fromDate, days: span.spanDays)
        }
    }
    
    private func paginateMetadata(toDate: Date, fromDate: Date, offsetDate: Date?, offsetName: String?) async -> [tableMetadata] {
        
        //Self.logger.debug("paginateMetadata() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
        //Self.logger.debug("paginateMetadata() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        let resultMetadatas = dataService.paginateMetadata(fromDate: fromDate, toDate: toDate, offsetDate: offsetDate, offsetName: offsetName)
        
        /*for metadata in resultMetadatas {
            Self.logger.debug("paginateMetadata() - date: \(metadata.date) fileNameView: \(metadata.fileNameView)")
        }*/
        
        return resultMetadatas
    }
    
    private func processPaginationResult(resultMetadatas: [tableMetadata], toDate: Date, fromDate: Date, days: Int, loadMoreMetadata: Bool) async {
        
        Self.logger.debug("processPaginationResult() - resultMetadatas count: \(resultMetadatas.count) days: \(days)")
        
        if resultMetadatas.count >= Global.shared.pageSize {
            //have a full page. display all
            applyDatasourceChanges(metadatas: resultMetadatas)
        } else {
            //not enough for a full page. adjust time span, and fetch again
            guard let span = calculateSearchDates(toDate: toDate, days: days) else {
                applyDatasourceChanges(metadatas: resultMetadatas)
                return //gone back as far as possible. break out of recursive call
            }
            
            let resultMetadatas = await paginateMetadata(toDate: span.toDate, fromDate: span.fromDate, offsetDate: nil, offsetName: nil)
            await processPaginationResult(resultMetadatas: resultMetadatas, toDate: span.toDate, fromDate: span.fromDate, days: span.spanDays, loadMoreMetadata: loadMoreMetadata)
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
        
        Self.logger.error("calculateSearchDates() - days: \(days) newDays: \(newDays)")
        
        var fromDate: Date
        
        if (newDays == -999) {
            fromDate = Date.distantPast
        } else {
            fromDate = Calendar.current.date(byAdding: .day, value: newDays, to: toDate)!
        }
        
        Self.logger.debug("calculateSearchDates() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
        Self.logger.debug("calculateSearchDates() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        return (toDate, fromDate, newDays)
    }
    
    private func applyDatasourceChanges(metadatas: [tableMetadata]) {

        var snapshot = dataSource.snapshot()
        var ocIdAdd : [tableMetadata] = []
        var ocIdUpdate : [tableMetadata] = []
        
        for metadata in metadatas {
            Self.logger.debug("ocid: \(metadata.ocId) filename: \(metadata.fileName)")
            
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
            snapshot.reconfigureItems(ocIdUpdate)
        }
        
        let pageSnaphot = snapshot
            
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dataSource.apply(pageSnaphot, animatingDifferences: true)
            self.delegate.dataSourceUpdated()
        }
    }
    
    private func setImage(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            await cell.setImage(UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)))
        }
    }
}
