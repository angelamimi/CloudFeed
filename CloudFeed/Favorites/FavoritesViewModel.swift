//
//  FavoritesViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/14/23.
//

import NextcloudKit
import os.log
import UIKit

protocol FavoritesDelegate: AnyObject {
    func fetching()
    func dataSourceUpdated()
    func bulkEditFinished()
    func fetchResultReceived(resultItemCount: Int?)
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath)
}

final class FavoritesViewModel: NSObject {
    
    var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    let delegate: FavoritesDelegate
    let dataService: DataService
    
    private var previewTasks: [IndexPath: Task<Void, Never>] = [:]
    private let queue = DispatchQueue(label: String(describing: FavoritesViewModel.self))
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesViewModel.self)
    )
    
    init(delegate: FavoritesDelegate, dataService: DataService) {
        self.delegate = delegate
        self.dataService = dataService
    }
    
    func initDataSource(collectionView: UICollectionView) {
        
        dataSource = UICollectionViewDiffableDataSource<Int, tableMetadata>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, metadata: tableMetadata) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            Task {
                await self.setImage(metadata: metadata, cell: cell, indexPath: indexPath)
            }
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
    
    func loadMore() {
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
                Self.logger.debug("loadMore() - offsetDate: \(offsetDate!.formatted(date: .abbreviated, time: .standard))")
            }
        }

        guard let offsetDate = offsetDate else { return }
        guard let offsetName = offsetName else { return }
        
        Self.logger.debug("loadMore() - offsetName: \(offsetName) offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        
        sync(offsetDate: offsetDate, offsetName: offsetName)
    }
    
    func reload() {
        
        var snapshot = dataSource.snapshot()
        
        guard snapshot.numberOfSections > 0 else { return }
        snapshot.reloadSections([0])
        
        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    func fetch() {
        
        Self.logger.debug("fetch()")
        
        delegate.fetching()
                
        Task {
            let error = await dataService.getFavorites()
            processFavoriteResult(error: error)
            
            let resultMetadatas = dataService.paginateFavoriteMetadata(offsetDate: nil, offsetName: nil)
            await applyDatasourceChanges(metadatas: resultMetadatas)
        }
    }
    
    private func processFavoriteResult(error: Bool) {
        if error {
            delegate.fetchResultReceived(resultItemCount: nil)
        }
    }
    
    func sync(offsetDate: Date, offsetName: String) {
        
        Self.logger.debug("sync()")
        
        delegate.fetching()
        
        Task {
            _ = await dataService.getFavorites()
            
            let resultMetadatas = dataService.paginateFavoriteMetadata(offsetDate: offsetDate, offsetName: offsetName)
            await applyDatasourceChanges(metadatas: resultMetadatas)
        }
    }
    
    func syncFavs() {
        
        Self.logger.debug("syncFavs()")
        
        delegate.fetching()
                
        Task {
            let error = await dataService.getFavorites()
            processFavoriteResult(error: error)
            
            var snapshot = dataSource.snapshot()
            let delete = dataService.processFavorites(displayedMetadatas: snapshot.itemIdentifiers(inSection: 0))
            
            guard delete.count > 0 else {
                delegate.dataSourceUpdated()
                return
            }
            
            snapshot.deleteItems(delete)
            
            let applySnapshot = snapshot
            
            DispatchQueue.main.async { [weak self] in
                self?.dataSource.apply(applySnapshot, animatingDifferences: true, completion: {
                    self?.delegate.dataSourceUpdated()
                })
            }
        }
    }
    
    func loadPreview(indexPath: IndexPath) {
        
        guard let metadata = dataSource.itemIdentifier(for: indexPath) else { return }
        
        queue.async { [weak self] in
            if !FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                self?.loadPreviewImageForMetadata(metadata, indexPath: indexPath)
            }
        }
    }
    
    func stopPreviewLoad(indexPath: IndexPath) {
        
        Self.logger.debug("stopPreviewLoad() - indexPath: \(indexPath)")
        
        queue.async { [weak self] in
            
            guard let previewLoadTask = self?.previewTasks[indexPath] else {
                return
            }
            previewLoadTask.cancel()
            self?.previewTasks[indexPath] = nil
        }
    }
    
    private func clearTask(indexPath: IndexPath) {
        Self.logger.debug("clearTask() - indexPath: \(indexPath)")
        
        queue.async { [weak self] in
            if self?.previewTasks[indexPath] != nil {
                self?.previewTasks[indexPath] = nil
            }
        }
    }
    
    func bulkEdit(indexPaths: [IndexPath]) async {
        
        var snapshot = dataSource.snapshot()
        
        for indexPath in indexPaths {
            let metadata = await dataSource.itemIdentifier(for: indexPath)
            
            guard metadata != nil else { continue }
            
            let error = await dataService.favoriteMetadata(metadata!)
            if error == .success {
                snapshot.deleteItems([metadata!])
            } else {
                //TODO: Show the user a single error for all failed
                Self.logger.error("bulkEdit() - ERROR: \(error.errorDescription)")
            }
        }
        
        snapshot.reloadSections([0])
        
        let applySnapshot = snapshot
        
        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(applySnapshot, animatingDifferences: true)
            self?.delegate.bulkEditFinished()
        }
    }
    
    private func loadPreviewImageForMetadata(_ metadata: tableMetadata, indexPath: IndexPath) {
        
        previewTasks[indexPath] = Task { [weak self] in
            guard let self else { return }
        
            defer { self.clearTask(indexPath: indexPath) }
            
            //Self.logger.debug("loadPreviewImageForMetadata() - ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
            
            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                await self.dataService.downloadVideoPreview(metadata: metadata)
            } else if metadata.contentType == "image/svg+xml" || metadata.fileExtension == "svg" {
                //TODO: Implement svg fetch. Need a library that works.
            } else {
                await self.dataService.downloadPreview(metadata: metadata)
            }
            
            if Task.isCancelled { return }
            
            guard FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) else {
                //Self.logger.debug("loadPreviewImageForMetadata() - NO IMAGE ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
                return
            }
            
            //Self.logger.debug("loadPreviewImageForMetadata() - GOT IMAGE REFRESH CELL ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                var snapshot = self.dataSource.snapshot()
                snapshot.reloadItems([metadata])
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }
    
    private func setImage(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        Self.logger.debug("setImage() - indexPath: \(indexPath)")
        
        let ocId = metadata.ocId
        let etag = metadata.etag
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)) {
            
            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                await cell.showVideoIcon()
            } else if metadata.livePhoto {
                await cell.showLivePhotoIcon()
            } else {
                await cell.resetStatusIcon()
            }
            
            await cell.setImage(UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)))
            //Self.logger.debug("CELL - image size: \(cell.imageView.image?.size.width ?? -1),\(cell.imageView.image?.size.height ?? -1)")
            
        }  else {
            Self.logger.debug("setImage() - ocid NOT FOUND indexPath: \(indexPath) ocId: \(ocId)")
            await cell.resetStatusIcon()
            await cell.setImage(nil)
        }
        
        delegate.editCellUpdated(cell: cell, indexPath: indexPath)
    }
    
    private func processMetadata(resultMetadatas: [tableMetadata]) -> [tableMetadata] {
        
        var metadatas : [tableMetadata] = []
        
        if resultMetadatas.count > 0 {

            //TODO: Allow user to sort?
            let sorted = resultMetadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
            
            //Filter out live photo movies. Only show the jpg in favorites.
            for metadata in sorted {
                if metadata.livePhoto && (metadata.fileNameView as NSString).pathExtension.lowercased() == "mov" {
                    continue
                }
                metadatas.append(metadata)
            }
        }
        
        Self.logger.debug("processMetadata() - new metadata count: \(metadatas.count) result count: \(resultMetadatas.count)")
        
        //let idArray = metadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("processMetadata() - metadatas: \(idArray)")
        
        return metadatas
    }
    
    private func refreshDatasourceOLD(metadatas: [tableMetadata]) async {
        var snapshot = dataSource.snapshot()
        var delete: [tableMetadata] = []
        
        for currentMetadata in snapshot.itemIdentifiers(inSection: 0) {
            let metadata = metadatas.first(where: { $0.ocId == currentMetadata.ocId })
            if (metadata == nil) {
                delete.append(currentMetadata)
            }
        }
        
        Self.logger.debug("refreshDatasource() - delete count: \(delete.count)")
        
        if delete.count > 0 {
            snapshot.deleteItems(delete)
        }
        
        let applySnapshot = snapshot
        
        DispatchQueue.main.async { [weak self] in
            self?.dataSource.apply(applySnapshot, animatingDifferences: true, completion: {
                Task {
                    await self?.applyDatasourceChanges(metadatas: metadatas)
                }
            })
        }
    }
    
    private func applyDatasourceChanges(metadatas: [tableMetadata]) async {
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
        
        if ocIdAdd.count > 0 {
            snapshot.appendItems(ocIdAdd, toSection: 0)
        }
        
        if ocIdUpdate.count > 0 {
            //snapshot.reconfigureItems(ocIdUpdate)
            snapshot.reloadItems(ocIdUpdate)
        }
        
        Self.logger.debug("applyDatasourceChanges() - ocIdAdd: \(ocIdAdd.count) ocIdUpdate: \(ocIdUpdate.count)")
        
        let applySnapshot = snapshot
        
        DispatchQueue.main.async {[weak self] in
            guard let self else { return }
            self.dataSource.apply(applySnapshot, animatingDifferences: true)
            self.delegate.dataSourceUpdated()
        }
    }
}
