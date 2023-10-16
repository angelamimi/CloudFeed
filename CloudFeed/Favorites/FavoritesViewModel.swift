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
    func dataSourceUpdated()
    func bulkEditFinished()
    func fetchResultReceived(resultItemCount: Int?)
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath)
}

final class FavoritesViewModel: NSObject {
    
    var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    let delegate: FavoritesDelegate
    let dataService: DataService
    
    private let groupSize = 2 //thumbnail fetches executed concurrently
    
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
    
    func reload() {
        
        var snapshot = dataSource.snapshot()
        
        guard snapshot.numberOfSections > 0 else { return }
        snapshot.reloadSections([0])
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    func fetch() {
        
        Self.logger.debug("fetch()")
                
        Task {
            let resultMetadatas = await getFavorites()
            await processResult(resultMetadatas: resultMetadatas)
        }
    }
    
    func metadataFetch() {
        
        guard let account = Environment.current.currentUser?.account else { return }
        let resultMetadatas = dataService.getFavoriteMetadatas(account: account)
        
        let metadatas = processMetadata(resultMetadatas: resultMetadatas)
        
        Task {
            await refreshDatasource(metadatas: metadatas)
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
        
        DispatchQueue.main.async {
            self.dataSource.apply(applySnapshot, animatingDifferences: true)
        }
        
        delegate.bulkEditFinished()
    }
    
    private func setImage(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        Self.logger.debug("setImage() - indexPath: \(indexPath)")
        
        let ocId = metadata.ocId
        let etag = metadata.etag
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)) {
            let image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag))
            await cell.setImage(image)
            //Self.logger.debug("CELL - image size: \(cell.imageView.image?.size.width ?? -1),\(cell.imageView.image?.size.height ?? -1)")
        }  else {
            Self.logger.debug("setImage() - ocid NOT FOUND indexPath: \(indexPath) ocId: \(ocId)")
            await cell.setImage(nil)
        }
        
        delegate.editCellUpdated(cell: cell, indexPath: indexPath)
    }
    
    private func getFavorites() async -> [tableMetadata]? {

        Self.logger.debug("getFavorites()")
        let resultMetadatas = await dataService.getFavorites()
        
        Self.logger.debug("getFavorites() - resultMetadatas count: \(resultMetadatas == nil ? -1 : resultMetadatas!.count)")
        
        return resultMetadatas
    }
    
    private func processResult(resultMetadatas: [tableMetadata]?) async {
        
        guard let resultMetadatas = resultMetadatas else {
            delegate.fetchResultReceived(resultItemCount: nil)
            /*coordinator.showLoadfailedError()
            titleView?.hideMenu()*/
            return
        }
        
        let metadatas = processMetadata(resultMetadatas: resultMetadatas)
        await processMetadataPage(pageMetadatas: metadatas)
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
    
    /*
     Divides the current page of results into groups of fetch preview tasks to be executed concurrently
     */
    private func processMetadataPage(pageMetadatas: [tableMetadata]) async {
        
        delegate.fetchResultReceived(resultItemCount: pageMetadatas.count)
        
        var groupMetadata: [tableMetadata] = []
        
        //let idArray = pageMetadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("processMetadataPage() - pageMetadatas: \(idArray)")
        
        for metadataIndex in (0...pageMetadatas.count - 1) {
            
            //Self.logger.debug("processMetadataPage() - metadataIndex: \(metadataIndex) pageMetadatas.count \(pageMetadatas.count)")
            
            if groupMetadata.count < groupSize {
                //Self.logger.debug("processMetadataPage() - appending: \(pageMetadatas[metadataIndex].ocId)")
                groupMetadata.append(pageMetadatas[metadataIndex])
            } else {
                await executeGroup(metadatas: groupMetadata)
                await applyDatasourceChanges(metadatas: groupMetadata)
                
                groupMetadata = []
                //Self.logger.debug("processMetadataPage() - appending: \(pageMetadatas[metadataIndex].ocId)")
                groupMetadata.append(pageMetadatas[metadataIndex])
            }
        }
        
        if groupMetadata.count > 0 {
            //Self.logger.debug("processMetadataPage() - groupMetadata: \(groupMetadata)")
            await executeGroup(metadatas: groupMetadata)
            await applyDatasourceChanges(metadatas: groupMetadata)
        }
    }
    
    private func executeGroup(metadatas: [tableMetadata]) async {
        await withTaskGroup(of: Void.self, returning: Void.self, body: { taskGroup in
            for metadata in metadatas {
                taskGroup.addTask {
                    //Self.logger.debug("executeGroup() - contentType: \(metadata.contentType) fileExtension: \(metadata.fileExtension)")
                    //Self.logger.debug("executeGroup() - ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
                    if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                        await self.dataService.downloadVideoPreview(metadata: metadata)
                    } else if metadata.contentType == "image/svg+xml" || metadata.fileExtension == "svg" {
                        //TODO: Implement svg fetch. Need a library that works.
                    } else {
                        //Self.logger.debug("executeGroup() - contentType: \(metadata.contentType)")
                        await self.dataService.downloadPreview(metadata: metadata)
                    }
                }
            }
        })
    }
    
    private func refreshDatasource(metadatas: [tableMetadata]) async {
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
        
        DispatchQueue.main.async {
            self.dataSource.apply(applySnapshot, animatingDifferences: true, completion: {
                Task {
                    await self.applyDatasourceChanges(metadatas: metadatas)
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
        
        DispatchQueue.main.async {
            self.dataSource.apply(applySnapshot, animatingDifferences: true)
            self.delegate.dataSourceUpdated()
        }
    }
}
