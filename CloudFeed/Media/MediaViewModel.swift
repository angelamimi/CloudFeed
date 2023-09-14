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
    func searchResultReceived(resultItemCount: Int?)
}

final class MediaViewModel: NSObject {
    
    var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    var delegate: MediaDelegate!
    
    private let loadMoreThreshold = -80.0
    private let groupSize = 2 //thumbnail fetches executed concurrently
    private var greaterDays = -30
    
    private var currentPageItemCount = 0
    private var currentMetadataCount = 0
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MediaViewModel.self)
    )
    
    init(delegate: MediaDelegate) {
        self.delegate = delegate
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
    
    private func setImage(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            let image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            await cell.setImage(image)
            //await cell.imageView.image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            //Self.logger.debug("CELL - image size: \(cell.imageView.image?.size.width ?? -1),\(cell.imageView.image?.size.height ?? -1)")
        }  else {
            //Self.logger.debug("CELL - ocid NOT FOUND indexPath: \(indexPath) ocId: \(metadata.ocId)")
        }
    }
    
    func metadataSearch(offsetDate: Date) {
        //Self.logger.debug("metadataSearch() - offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        
        currentMetadataCount = 0
        greaterDays = -30
        
        let lastMetadata = getLastItem()

        var lessDate: Date
        if lastMetadata == nil {
            lessDate = offsetDate
        } else {
            lessDate = lastMetadata!.date as Date
        }
        
        guard let lessDate = Calendar.current.date(byAdding: .second, value: 1, to: lessDate) else { return }
        guard let greaterDate = Calendar.current.date(byAdding: .day, value: greaterDays, to: lessDate) else { return }
        
        //Self.logger.debug("metadataSearch() - lessDate: \(lessDate.formatted(date: .abbreviated, time: .standard))")
        //Self.logger.debug("metadataSearch() - greaterDate: \(greaterDate.formatted(date: .abbreviated, time: .standard))")
        
        Task {
            let results = await search(lessDate: lessDate, greaterDate: greaterDate, limit: Global.shared.metadataPageSize)
            await processMetadataSearch(results: results, greaterDate: greaterDate)

            let resultMetadatas = await paginateMetadata(lessDate: lessDate, greaterDate: greaterDate, offsetDate: nil, offsetName: nil)
            await processPaginationResult(resultMetadatas: resultMetadatas, lastDate: greaterDate, loadMoreMetadata: false)
        }
    }
    
    func sync(lessDate: Date, greaterDate: Date) {
        Task {
            let results = await search(lessDate: lessDate, greaterDate: greaterDate, limit: Global.shared.pageSize)
            guard results.metadatas != nil else { return }
            processSync(metadatas: results.metadatas!, deleteOcIds: results.deleteOcIds)
        }
    }
    
    func loadMore() {
        
        var offsetDate: Date?
        var offsetName: String?
        
        let snapshot = dataSource.snapshot()
        
        if (snapshot.numberOfItems(inSection: 0) > 0) {
            let metadata = snapshot.itemIdentifiers(inSection: 0).last
            if metadata != nil {
                offsetDate = metadata!.date as Date
                offsetName = metadata!.fileNameView
                
                Self.logger.debug("loadMore() - offsetDate: \(offsetDate!.formatted(date: .abbreviated, time: .standard)) offsetName: \(offsetName!)")
            }
        }

        guard let offsetName = offsetName, let offsetDate = offsetDate else { return }
        
        //loadMoreIndicator.startAnimating()
        
        currentPageItemCount = 0
        greaterDays = -30
        
        guard let greaterDate = Calendar.current.date(byAdding: .day, value: greaterDays, to: offsetDate) else { return }
        
        Self.logger.debug("loadMore() - lessDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        Self.logger.debug("loadMore() - greaterDate: \(greaterDate.formatted(date: .abbreviated, time: .standard))")
        
        Task {
        
            let resultMetadatas = await paginateMetadata(lessDate: offsetDate, greaterDate: greaterDate, offsetDate: offsetDate, offsetName: offsetName)
            Self.logger.debug("loadMore() - resultMetadatas count: \(resultMetadatas.count)")
            
            await processPaginationResult(resultMetadatas: resultMetadatas, lastDate: greaterDate, loadMoreMetadata: true)
            
            //loadMoreIndicator.stopAnimating()
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
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true, completion: {
                self.applyDatasourceChanges(metadatas: metadatas, sync: true)
            })
        }
    }
    
    private func search(lessDate: Date, greaterDate: Date, limit: Int) async -> (metadatas: [tableMetadata]?, deleteOcIds: [String]) {
        
        //startActivityIndicator()
        
        let mediaPath = getMediaPath()
        let startServerUrl = getStartServerUrl()
        
        guard mediaPath != nil && startServerUrl != nil else { return (nil, []) }
        
        Self.logger.debug("search() - greaterDays: \(self.greaterDays) lessDate: \(lessDate.formatted(date: .abbreviated, time: .standard))")
        Self.logger.debug("search() - greaterDate: \(greaterDate.formatted(date: .abbreviated, time: .standard))")
        let result = await Environment.current.dataService.searchMedia(
            account: Environment.current.currentUser!.account!,
            mediaPath: mediaPath!,
            startServerUrl: startServerUrl!,
            lessDate: lessDate,
            greaterDate: greaterDate,
            limit: limit)
        
        //stopActivityIndicator()
        
        Self.logger.debug("search() - result metadatas count: \(result.metadatas.count) error?: \(result.error)")
        
        guard result.error == false else {
            Self.logger.error("search() - error") //TODO: Alert user of error?
            return (nil, [])
        }
        
        let sorted = result.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
        
        for metadata in sorted {
            Self.logger.debug("search() - date: \(metadata.date) fileNameView: \(metadata.fileNameView)")
        }
        
        //let idArray = sorted.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("search() - sorted: \(idArray)")
        
        return (sorted, result.deleteOcIds)
    }
    
    private func processMetadataSearch(results: (metadatas: [tableMetadata]?, deleteOcIds: [String]), greaterDate: Date) async {
        
        guard let resultMetadatas = results.metadatas else {
            delegate?.searchResultReceived(resultItemCount: nil)
            return
        }
        
        delegate?.searchResultReceived(resultItemCount: resultMetadatas.count)
        
        var lessDate: Date = Date()
        //let resultMetadatas: [tableMetadata] = results.metadatas == nil ? [] : results.metadatas!
        
        lessDate = Calendar.current.date(byAdding: .second, value: 1, to: greaterDate)!
        
        currentMetadataCount += resultMetadatas.count
        
        Self.logger.debug("processMetadataSearch() - lessDate: \(lessDate.formatted(date: .abbreviated, time: .standard))")
        Self.logger.debug("processMetadataSearch() - greaterDate: \(greaterDate.formatted(date: .abbreviated, time: .standard))")
        
        Self.logger.debug("processMetadataSearch() - resultMetadatas count: \(resultMetadatas.count) currentMetadataCount: \(self.currentMetadataCount)")
        
        if currentMetadataCount < Global.shared.metadataPageSize {
            //not enough to fill a page. keep searching and collecting metadata
            let searchDates = calculateSearchDates(lessDate: lessDate)

            if (searchDates.lessDate != nil && searchDates.greaterDate != nil) {
                let results = await search(lessDate: searchDates.lessDate!, greaterDate: searchDates.greaterDate!, limit: Global.shared.metadataPageSize)
                await processMetadataSearch(results: results, greaterDate: searchDates.greaterDate!)
            } else {
                //gone as far back as possible. reset search
                currentMetadataCount = 0
                greaterDays = 0
                
                Self.logger.debug("processMetadataSearch() - no search dates. done.")
            }
        } else {
            //have enough to stop searching. reset search
            currentMetadataCount = 0
            greaterDays = 0
            
            Self.logger.debug("processMetadataSearch() - full page. done.")
        }
    }
    
    private func calculateSearchDates(lessDate: Date) -> (lessDate: Date?, greaterDate: Date?) {
        
        greaterDays = greaterDays - 30
        
        Self.logger.error("calculateSearchDates() -----------------------")
        Self.logger.error("calculateSearchDates() - greaterDays: \(self.greaterDays)")
        
        if greaterDays >= -120{
            if greaterDays == -120 {
                greaterDays = -999 //go all the way back in time
            } else if greaterDays <= -999 {
                return (nil, nil) //gone as far back in time as possible. no more valid date ranges to return
            }
            
            var greaterDate: Date
            
            if (greaterDays == -999) {
                greaterDate = Date.distantPast
            } else {
                //greaterDate = Calendar.current.date(byAdding: .day, value: greaterDays, to:lessDate)!
                greaterDate = Calendar.current.date(byAdding: .day, value: greaterDays, to: lessDate)!
            }
            
            Self.logger.debug("calculateSearchDates() - lessDate: \(lessDate.formatted(date: .abbreviated, time: .standard))")
            Self.logger.debug("calculateSearchDates() - greaterDate: \(greaterDate.formatted(date: .abbreviated, time: .standard))")
            
            return (lessDate, greaterDate)
        }
        
        return (nil, nil)
    }
    
    private func paginateMetadata(lessDate: Date, greaterDate: Date, offsetDate: Date?, offsetName: String?) async -> [tableMetadata] {
        //Self.logger.debug("paginateMetadata() - lessDate: \(lessDate.formatted(date: .abbreviated, time: .standard))")
        //Self.logger.debug("paginateMetadata() - greaterDate: \(greaterDate.formatted(date: .abbreviated, time: .standard))")
        
        let startServerUrl = getStartServerUrl()
        
        guard startServerUrl != nil else { return [] }
        guard let account = Environment.current.currentUser?.account else { return [] }
        
        let resultMetadatas = Environment.current.dataService.paginateMetadata(account: account, startServerUrl: startServerUrl!, greaterDate: greaterDate, lessDate: lessDate, offsetDate: offsetDate, offsetName: offsetName)
        
        /*for metadata in resultMetadatas {
            Self.logger.debug("paginateMetadata() - date: \(metadata.date) fileNameView: \(metadata.fileNameView)")
        }*/
        
        return resultMetadatas
    }
    
    private func processPaginationResult(resultMetadatas: [tableMetadata], lastDate : Date, loadMoreMetadata: Bool) async {
        var offsetDate: Date
        var offsetName: String?
        
        currentPageItemCount += resultMetadatas.count
        
        if resultMetadatas.count == 0 {
            offsetDate = lastDate
        } else {
            offsetDate = resultMetadatas.last!.date as Date
            offsetName = resultMetadatas.last!.fileNameView
        }
        
        Self.logger.debug("processPaginationResult() - offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        Self.logger.debug("processPaginationResult() - lastDate: \(lastDate.formatted(date: .abbreviated, time: .standard))")
        
        Self.logger.debug("processPaginationResult() - resultMetadatas count: \(resultMetadatas.count) currentPageItemCount: \(self.currentPageItemCount)")
        
        if currentPageItemCount < Global.shared.pageSize {
            //not enough to fill a page. display what currently have.
            await paginate(pageMetadatas: resultMetadatas)
            
            let searchDates = calculateSearchDates(lessDate: offsetDate)
            
            if (searchDates.lessDate != nil && searchDates.greaterDate != nil) {
                
                let resultMetadatas = await paginateMetadata(lessDate: searchDates.lessDate!, greaterDate: searchDates.greaterDate!, offsetDate: offsetDate, offsetName: offsetName)
                await processPaginationResult(resultMetadatas: resultMetadatas, lastDate: searchDates.greaterDate!, loadMoreMetadata: loadMoreMetadata)
            } else {
                //can't go any further back. display, reset pagination, and perform metadata search
                currentPageItemCount = 0
                greaterDays = 0
                
                await paginate(pageMetadatas: resultMetadatas)
                
                if loadMoreMetadata {
                    Self.logger.debug("processPaginationResult() - GONE AS FAR BACK AS POSSIBLE. METADATA FETCH")
                    metadataSearch(offsetDate: offsetDate)
                }
            }
            
        } else {
            //have a full page. display and reset pagination
            currentPageItemCount = 0
            greaterDays = 0
            
            await paginate(pageMetadatas: resultMetadatas)
        }
    }
    
    /*
     Divides the current page of results into groups of fetch preview tasks to be executed concurrently
     */
    private func paginate(pageMetadatas: [tableMetadata]) async {
        
        guard pageMetadatas.count > 0 else { return }
        
        var groupMetadata: [tableMetadata] = []
        
        //let idArray = pageMetadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("paginate() - pageMetadatas: \(idArray)")
        
        for metadataIndex in (0...pageMetadatas.count - 1) {
            
            //Self.logger.debug("paginate() - metadataIndex: \(metadataIndex) pageMetadatas.count \(pageMetadatas.count)")
            
            if groupMetadata.count < groupSize {
                //Self.logger.debug("paginate() - appending: \(pageMetadatas[metadataIndex].ocId)")
                groupMetadata.append(pageMetadatas[metadataIndex])
            } else {
                await executeGroup(metadatas: groupMetadata)
                applyDatasourceChanges(metadatas: groupMetadata)
                
                groupMetadata = []
                //Self.logger.debug("paginate() - appending: \(pageMetadatas[metadataIndex].ocId)")
                groupMetadata.append(pageMetadatas[metadataIndex])
            }
        }
        
        if groupMetadata.count > 0 {
            //Self.logger.debug("paginate() - groupMetadata: \(groupMetadata)")
            await executeGroup(metadatas: groupMetadata)
            applyDatasourceChanges(metadatas: groupMetadata)
        }
    }
    
    private func executeGroup(metadatas: [tableMetadata]) async {
        await withTaskGroup(of: Void.self, returning: Void.self, body: { taskGroup in
            for metadata in metadatas {
                taskGroup.addTask {
                    //Self.logger.debug("executeGroup() - contentType: \(metadata.contentType) fileExtension: \(metadata.fileExtension)")
                    //Self.logger.debug("executeGroup() - ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
                    if metadata.classFile == NKCommon.typeClassFile.video.rawValue {
                        await Environment.current.dataService.downloadVideoPreview(metadata: metadata)
                    } else if metadata.contentType == "image/svg+xml" || metadata.fileExtension == "svg" {
                        //TODO: Implement svg fetch. Need a library that works.
                    } else {
                        //Self.logger.debug("executeGroup() - contentType: \(metadata.contentType)")
                        await Environment.current.dataService.downloadPreview(metadata: metadata)
                    }
                }
            }
        })
    }
    
    private func applyDatasourceChanges(metadatas: [tableMetadata], sync: Bool = false) {
        
        var ocIdAdd : [tableMetadata] = []
        var ocIdUpdate : [tableMetadata] = []
        var snapshot = dataSource.snapshot()
        
        for metadata in metadatas {
            if snapshot.indexOfItem(metadata) == nil {
                ocIdAdd.append(metadata)
            } else {
                ocIdUpdate.append(metadata)
            }
        }
        
        Self.logger.debug("applyDatasourceChanges() - ocIdAdd: \(ocIdAdd.count) ocIdUpdate: \(ocIdUpdate.count)")
        //Self.logger.debug("applyDatasourceChanges() - ocIdAdd: \(ocIdAdd)")
        
        if ocIdAdd.count > 0 {
            snapshot.appendItems(ocIdAdd, toSection: 0)
            /*if sync == false {
                snapshot.appendItems(ocIdAdd, toSection: 0)
            } else {
                insertItems(metadatas: ocIdAdd)
            }*/
        }
        
        if ocIdUpdate.count > 0 {
            snapshot.reconfigureItems(ocIdUpdate)
        }
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
            self.delegate.dataSourceUpdated()
        }
    }
    
    private func getMediaPath() -> String? {
        guard let activeAccount = Environment.current.dataService.getActiveAccount() else { return nil }
        return activeAccount.mediaPath
    }
    
    private func getStartServerUrl() -> String? {
        guard let mediaPath = getMediaPath() else { return nil }
        let urlBase = Environment.current.currentUser!.urlBase!
        let userId = Environment.current.currentUser!.userId!
        let startServerUrl = urlBase + "/remote.php/dav/files/" + userId + mediaPath
        
        return startServerUrl
    }
}
