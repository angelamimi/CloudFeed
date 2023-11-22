//
//  MediaViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/12/23.
//

import NextcloudKit
import os.log
import SVGKit
import UIKit

protocol MediaDelegate: AnyObject {
    func dataSourceUpdated()
    func favoriteUpdated(error: Bool)
    
    func searching()
    func searchResultReceived(resultItemCount: Int?)
}

final class MediaViewModel: NSObject {
    
    var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    
    let delegate: MediaDelegate
    let dataService: DataService
    
    private var previewTasks: [IndexPath: Task<Void, Never>] = [:]
    private let queue = DispatchQueue(label: String(describing: MediaViewModel.self))
    
    private let loadMoreThreshold = -80.0
    
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
            let metadata = snapshot.itemIdentifiers(inSection: 0).last
            
            //Self.logger.debug("getLastItem() - date: \(metadata?.date) name: \(metadata?.fileNameView ?? "")")
            return metadata
        }
        
        return nil
    }
    
    func metadataSearch(offsetDate: Date, limit: Int, refresh: Bool) {
        
        //Self.logger.debug("metadataSearch() - offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        
        let days = -30
        guard let fromDate = Calendar.current.date(byAdding: .day, value: days, to: offsetDate) else { return }
        
        //Self.logger.debug("metadataSearch() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        Task { [weak self] in
            guard let self else { return }
            
            let results = await search(toDate: offsetDate, fromDate: fromDate, limit: limit) //saves metadata to be paginated
            
            //Self.logger.debug("metadataSearch() - added: \(results.added.count) updated: \(results.updated.count) deleted: \(results.deleted.count)")
            
            await processSearchResult(metadatas: results.metadatas, toDate: offsetDate, fromDate: fromDate, days: days) //recursive call until enough results received or gone all the way back in time

            let resultMetadatas = await paginateMetadata(toDate: offsetDate, fromDate: fromDate, offsetDate: nil, offsetName: nil) //chunks results to be displayed in pages
            await processPaginationResult(resultMetadatas: resultMetadatas, toDate: offsetDate, fromDate: fromDate, days: days, refresh: refresh) //updates the datasource
        }
    }
    
    func sync(visibleToDate: Date, visibleFromDate: Date) {
        
        Task { [weak self] in
            guard let self else { return }

            let snapshot = dataSource.snapshot()
            let metadata = snapshot.itemIdentifiers(inSection: 0).first
            var toDate = visibleToDate
            
            if toDate == metadata!.date as Date {
                toDate = Date()
            }
            
            //Self.logger.debug("sync() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
            //Self.logger.debug("sync() - visibleFromDate: \(visibleFromDate.formatted(date: .abbreviated, time: .standard))")
            
            let results = await search(toDate: toDate, fromDate: visibleFromDate, limit: Global.shared.pageSize)
            
            guard results.metadatas != nil else { return }
            var updatedFavorites = getUpdatedFavorites(metadatas: results.metadatas!)
            
            updatedFavorites.append(contentsOf: results.updated)
            
            //Self.logger.debug("sync() - added: \(results.added.count) updated: \(results.updated.count) deleted: \(results.deleted.count)")
            processSync(added: results.added, updated: updatedFavorites, deleted: results.deleted)
        }
    }
    
    func loadMore() {
        
        var offsetDate: Date?

        let snapshot = dataSource.snapshot()
        
        if (snapshot.numberOfItems(inSection: 0) > 0) {
            let metadata = snapshot.itemIdentifiers(inSection: 0).last
            if metadata != nil {
                /*  intentionally overlapping results. could shift the date here by a second to exclude previous results,
                    but might lose items with dates in the same second */
                offsetDate = metadata!.date as Date
                //Self.logger.debug("loadMore() - offsetDate: \(offsetDate!.formatted(date: .abbreviated, time: .standard))")
            }
        }

        guard let offsetDate = offsetDate else { return }
        
        //Self.logger.debug("loadMore() - offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        
        metadataSearch(offsetDate: offsetDate, limit: 300, refresh: false)
    }
    
    func loadPreview(indexPath: IndexPath) {
        
        guard let metadata = dataSource.itemIdentifier(for: indexPath) else { return }
        
        queue.async {
            if !FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                self.loadPreviewImageForMetadata(metadata, indexPath: indexPath)
            }
        }
    }
    
    func stopPreviewLoad(indexPath: IndexPath) {
        
        //Self.logger.debug("stopPreviewLoad() - indexPath: \(indexPath)")
        
        queue.async {
            
            guard let previewLoadTask = self.previewTasks[indexPath] else {
                return
            }
            previewLoadTask.cancel()
            self.previewTasks[indexPath] = nil
        }
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
    
    private func clearTask(indexPath: IndexPath) {
        //Self.logger.debug("clearTask() - indexPath: \(indexPath)")
        
        queue.async {
            if self.previewTasks[indexPath] != nil {
                self.previewTasks[indexPath] = nil
            }
        }
    }
    
    private func loadPreviewImageForMetadata(_ metadata: tableMetadata, indexPath: IndexPath) {
        
        previewTasks[indexPath] = Task { [weak self] in
            guard let self else { return }
            
            defer { self.clearTask(indexPath: indexPath) }
            
            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                await self.dataService.downloadVideoPreview(metadata: metadata)
            } else if metadata.isSVG {
                await loadSVG(metadata: metadata)
            } else {
                await self.dataService.downloadPreview(metadata: metadata)
            }
            
            if Task.isCancelled { return }
            
            guard FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                var snapshot = self.dataSource.snapshot()
                snapshot.reloadItems([metadata])
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
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
    
    private func processSync(added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata]) {
        
        var snapshot = dataSource.snapshot()
        let displayedMetadata = snapshot.itemIdentifiers(inSection: 0)
        
        for delete in deleted {
            if displayedMetadata.contains(delete) {
                snapshot.deleteItems([delete])
            }
        }
        
        let applySnapshot = snapshot
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dataSource.apply(applySnapshot, animatingDifferences: true, completion: {
                self.applyAddedUpdated(added: added, updated: updated)
            })
        }
    }
    
    private func applyAddedUpdated(added: [tableMetadata], updated: [tableMetadata]) {
        
        var snapshot = dataSource.snapshot()
        let displayedMetadata = snapshot.itemIdentifiers(inSection: 0)
        
        if added.count > 0 && displayedMetadata.count > 0 {
            
            let firstItem = displayedMetadata.first!
            
            for add in added {
                if !displayedMetadata.contains(add) {
                    snapshot.insertItems([add], beforeItem: firstItem)
                }
            }
        }

        for update in updated {
            if displayedMetadata.contains(update) {
                snapshot.reloadItems([update])
            }
        }
            
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dataSource.apply(snapshot, animatingDifferences: true)
            self.delegate.dataSourceUpdated()
        }
    }
    
    private func search(toDate: Date, fromDate: Date, limit: Int) async -> (metadatas: [tableMetadata]?, added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata]) {
        
        //Self.logger.debug("search() - toDate: \(toDate.formatted(date: .abbreviated, time: .standard))")
        //Self.logger.debug("search() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        delegate.searching()
        
        let result = await dataService.searchMedia(toDate: toDate, fromDate: fromDate, limit: limit)
        
        //Self.logger.debug("search() - result metadatas count: \(result.metadatas.count) error?: \(result.error)")
        
        guard result.error == false else {
            Self.logger.error("search() - error") //TODO: Alert user of error?
            return (nil, [], [], [])
        }
        
        let sorted = result.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
        
        /*for metadata in sorted {
            Self.logger.debug("search() - date: \(metadata.date) fileNameView: \(metadata.fileNameView)")
        }*/
        
        //let idArray = sorted.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("search() - sorted: \(idArray)")
        
        return (sorted, result.added, result.updated, result.deleted)
    }
    
    private func processSearchResult(metadatas: [tableMetadata]?, toDate: Date, fromDate: Date, days: Int) async {
        
        guard let resultMetadatas = metadatas else {
            delegate.searchResultReceived(resultItemCount: nil)
            return
        }
        
        //Self.logger.debug("processSearchResult() - resultMetadatas count: \(resultMetadatas.count)")
        
        if resultMetadatas.count >= Global.shared.metadataPageSize {
            delegate.searchResultReceived(resultItemCount: resultMetadatas.count)
        } else {
            
            //not enough to fill a page. keep searching and collecting metadata by shifting the date span farther back in time
            
            guard let span = calculateSearchDates(toDate: toDate, days: days) else {
                //gone as far back as possible. break out of recursive call
                delegate.searchResultReceived(resultItemCount: resultMetadatas.count)
                return
            }
            
            /*Self.logger.debug("processSearchResult() - toDate: \(span.toDate.formatted(date: .abbreviated, time: .standard))")
            Self.logger.debug("processSearchResult() - fromDate: \(span.fromDate.formatted(date: .abbreviated, time: .standard))")
            print("processSearchResult() - spanDays: \(span.spanDays)")*/

            let results = await search(toDate: span.toDate, fromDate: span.fromDate, limit: Global.shared.metadataPageSize)
            await processSearchResult(metadatas: results.metadatas, toDate: span.toDate, fromDate: span.fromDate, days: span.spanDays)
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
    
    private func processPaginationResult(resultMetadatas: [tableMetadata], toDate: Date, fromDate: Date, days: Int, refresh: Bool) async {
        
        print("processPaginationResult() - resultMetadatas count: \(resultMetadatas.count) days: \(days)")
        
        if resultMetadatas.count >= Global.shared.pageSize {
            //have a full page. display all
            applyDatasourceChanges(metadatas: resultMetadatas, refresh: refresh)
        } else {
            //not enough for a full page. adjust time span, and fetch again
            guard let span = calculateSearchDates(toDate: toDate, days: days) else {
                applyDatasourceChanges(metadatas: resultMetadatas, refresh: refresh)
                return //gone back as far as possible. break out of recursive call
            }
            
            let resultMetadatas = await paginateMetadata(toDate: span.toDate, fromDate: span.fromDate, offsetDate: nil, offsetName: nil)
            await processPaginationResult(resultMetadatas: resultMetadatas, toDate: span.toDate, fromDate: span.fromDate, days: span.spanDays, refresh: refresh)
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
        
        print("calculateSearchDates() - days: \(days) newDays: \(newDays)")
        
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
            guard let self else { return }
            self.dataSource.apply(snapshot, animatingDifferences: true)
            self.delegate.dataSourceUpdated()
        }
    }
    
    private func setImage(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            
            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                await cell.showVideoIcon()
            } else if metadata.livePhoto {
                await cell.showLivePhotoIcon()
            } else {
                await cell.resetStatusIcon()
            }
            
            let image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            
            if image != nil {
                //too wide or tall and the preview appears to shrink. allow image to be cut off
                await cell.setContentMode(isLongImage: NextcloudUtility.shared.isLongImage(imageSize: image!.size))
            }
            
            await cell.setImage(image)
        } else {
            //Self.logger.debug("setImage() - ocid NOT FOUND indexPath: \(indexPath) ocId: \(metadata.ocId)")
            await cell.resetStatusIcon()
            await cell.setImage(nil)
        }
    }
    
    private func loadSVG(metadata: tableMetadata) async {
        
        if !StoreUtility.fileProviderStorageExists(metadata) && metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
            
            await dataService.download(metadata: metadata, selector: "")
            
            NextcloudUtility.shared.loadSVGPreview(metadata: metadata)
        }
    }
}
