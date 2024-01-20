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
    func dataSourceUpdated()
    func bulkEditFinished(error: Bool)
    func fetchResultReceived(resultItemCount: Int?)
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath)
}

final class FavoritesViewModel: NSObject {
    
    var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    
    let delegate: FavoritesDelegate
    let dataService: DataService
    
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
            Task { [weak self] in
                await self?.setImage(metadata: metadata, cell: cell, indexPath: indexPath)
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
                //Self.logger.debug("loadMore() - offsetDate: \(offsetDate!.formatted(date: .abbreviated, time: .standard))")
            }
        }

        guard let offsetDate = offsetDate else { return }
        guard let offsetName = offsetName else { return }
        
        //Self.logger.debug("loadMore() - offsetName: \(offsetName) offsetDate: \(offsetDate.formatted(date: .abbreviated, time: .standard))")
        
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
    
    func fetch(refresh: Bool) {
        
        delegate.fetching()
                
        Task { [weak self] in
            guard let self else { return }
            
            let error = await self.dataService.getFavorites()
            handleFavoriteResult(error: error)
            
            let resultMetadatas = dataService.paginateFavoriteMetadata(offsetDate: nil, offsetName: nil)
            await applyDatasourceChanges(metadatas: resultMetadatas, refresh: refresh)
        }
    }
    
    func syncFavs() {
        
        delegate.fetching()
                
        Task { [weak self] in
            guard let self else { return }
            
            let error = await dataService.getFavorites()
            handleFavoriteResult(error: error)
            
            processFavorites()
        }
    }
    
    func bulkEdit(indexPaths: [IndexPath]) async {
        
        var snapshot = dataSource.snapshot()
        var error = false
        
        for indexPath in indexPaths {
            
            guard let metadata = await dataSource.itemIdentifier(for: indexPath) else { continue }
            
            let result = await dataService.toggleFavoriteMetadata(metadata)
            
            if result == nil {
                Self.logger.error("bulkEdit() - failed to save favorite ocid: \(metadata.ocId)")
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
    
    private func handleFavoriteResult(error: Bool) {
        if error {
            delegate.fetchResultReceived(resultItemCount: nil)
        }
    }
    
    private func sync(offsetDate: Date, offsetName: String) {
        
        delegate.fetching()
        
        Task { [weak self] in
            guard let self else { return }

            _ = await self.dataService.getFavorites()
            
            let resultMetadatas = self.dataService.paginateFavoriteMetadata(offsetDate: offsetDate, offsetName: offsetName)
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
    
    private func setImage(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        //Self.logger.debug("setImage() - indexPath: \(indexPath)")
        
        let ocId = metadata.ocId
        let etag = metadata.etag
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)) {
            
            if metadata.gif || metadata.svg {
                await cell.setContentMode(aspectFit: true)
            }
            
            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                await cell.showVideoIcon()
            } else if metadata.livePhoto {
                await cell.showLivePhotoIcon()
            } else {
                await cell.resetStatusIcon()
            }
            
            let image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            await cell.setImage(image)
            
        }  else {
            //Self.logger.debug("setImage() - ocid NOT FOUND indexPath: \(indexPath) ocId: \(ocId)")
            await cell.setImage(nil)
            await loadPreview(indexPath: indexPath)

            //only update datasource if preview was actually downloaded
            if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                applyUpdateForMetadata(metadata)
            }
        }
        
        delegate.editCellUpdated(cell: cell, indexPath: indexPath)
    }
    
    private func processFavorites() {
        
        var snapshot = dataSource.snapshot()
        var displayed = snapshot.itemIdentifiers(inSection: 0)
        
        //Self.logger.debug("syncFavs() - displayed count: \(displayed.count)")
        
        guard let result = dataService.processFavorites(displayedMetadatas: displayed) else {
            delegate.dataSourceUpdated()
            return
        }
        
        //Self.logger.debug("syncFavs() - delete: \(result.delete.count) add: \(result.add.count)")
        
        guard result.delete.count > 0 || result.add.count > 0 else {
            delegate.dataSourceUpdated()
            return
        }
        
        if result.delete.count > 0 { snapshot.deleteItems(result.delete) }
        
        displayed = snapshot.itemIdentifiers(inSection: 0)
        
        if result.add.count > 0 {
            
            if snapshot.numberOfItems == 0 {
                snapshot.appendItems(result.add)
            } else {
                
                //find where each item to be added fits in the visible collection by date and possibly name
                for result in result.add {
                    
                    if snapshot.itemIdentifiers.contains(result) {
                        Self.logger.debug("processFavorites() - \(result.fileNameView) exists. do not add again.")
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
            self?.dataSource.apply(applySnapshot, animatingDifferences: true, completion: {
                self?.delegate.dataSourceUpdated()
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
            self.delegate.dataSourceUpdated()
        }
    }
    
    private func loadSVG(metadata: tableMetadata) async {
        
        if !StoreUtility.fileProviderStorageExists(metadata) && metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
            
            await dataService.download(metadata: metadata, selector: "")
            
            NextcloudUtility.shared.loadSVGPreview(metadata: metadata)
        }
    }
}
