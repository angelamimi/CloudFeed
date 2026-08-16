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

@MainActor
protocol FavoritesDelegate: AnyObject {
    func fetching()
    func dataSourceUpdated(refresh: Bool)
    func bulkEditFinished(error: Bool)
    func fetchResultReceived(resultItemCount: Int?)
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath)
    func videoSelected()
}

@MainActor
final class FavoritesViewModel {

    var pauseLoading: Bool = false

    private var dataSource: UICollectionViewDiffableDataSource<Int, Metadata.ID>!

    private let dataSourceQueue = DispatchQueue(label: "fav.datasource.queue")

    private let dataService: DataService
    private let coordinator: FavoritesCoordinator
    private weak var delegate: FavoritesDelegate!

    private let cacheManager: CacheManager

    private var metadatas: [Metadata.ID: Metadata] = [:]
    private var systemIconIds: [Metadata.ID] = []

    private var syncTask: Task<Void, Never>? {
        willSet {
            syncTask?.cancel()
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesViewModel.self)
    )

    init(delegate: FavoritesDelegate, dataService: DataService, cacheManager: CacheManager, coordinator: FavoritesCoordinator) {
        self.delegate = delegate
        self.dataService = dataService
        self.cacheManager = cacheManager
        self.coordinator = coordinator
    }

    func initDataSource(collectionView: UICollectionView) {

        dataSource = UICollectionViewDiffableDataSource<Int, Metadata.ID>(collectionView: collectionView) { [weak self] (collectionView: UICollectionView, indexPath: IndexPath, metadataId: Metadata.ID) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            return self?.initCell(metadataId: metadataId, cell: cell, indexPath: indexPath)
        }

        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
    }

    func share(metadatas: [Metadata]) {
        coordinator.share(metadatas)
    }

    func getItemAtIndexPath(_ indexPath: IndexPath) -> Metadata? {
        if let id = dataSource.itemIdentifier(for: indexPath) {
            return metadatas[id]
        }
        return nil
    }

    func currentItemCount() -> Int {
        let snapshot = dataSource.snapshot()
        return snapshot.numberOfItems(inSection: 0)
    }

    func cancel() {
        cancelLoads()
        syncTask?.cancel()
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

    func getMetadataFromOcId(_ ocId: String) async -> Metadata? {
        return await dataService.getMetadataFromOcId(ocId)
    }

    func getLayoutType() -> String {
        return dataService.store.getFavoriteLayoutType()
    }

    func updateLayoutType(_ type: String) {
        dataService.store.setFavoriteLayoutType(type)
    }

    func getColumnCount() -> Int {
        return dataService.store.getFavoriteColumnCount(UIDevice.current.userInterfaceIdiom)
    }

    func saveColumnCount(_ columnCount: Int) {
        dataService.store.setFavoriteColumnCount(columnCount)
    }

    func cancelLoads() {
        cacheManager.cancelAll()
    }

    func clearCache() {
        systemIconIds = []
        cacheManager.clear()
    }

    func cleanupFileCache() {
        Task.detached { [weak self] in
            await self?.dataService.store.cleanupFileCache()
        }
    }

    func getIndexPathForMetadata(metadata: Metadata) -> IndexPath? {
        return dataSource.indexPath(for: metadata.id)
    }

    func resetDataSource() {

        guard dataSource != nil else { return }

        metadatas.removeAll()

        dataSourceQueue.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                if var snapshot = self?.dataSource.snapshot() {
                    snapshot.deleteAllItems()
                    snapshot.appendSections([0])
                    self?.dataSource.applySnapshotUsingReloadData(snapshot)
                }
            }
        }
    }

    func reload() {

        var snapshot = dataSource.snapshot()
        guard snapshot.numberOfSections > 0 else { return }

        snapshot.reconfigureItems(snapshot.itemIdentifiers(inSection: 0))

        apply(snapshot: snapshot, animate: false, notify: false, refresh: false)
    }

    func filter(type: Global.FilterType, from: Date, to: Date) {
        sync(type: type, from: from, to: to, refresh: true)
    }

    func sync(type: Global.FilterType, from: Date, to: Date, refresh: Bool) {

        guard let currentUser = Environment.current.currentUser,
              let currentServer = Environment.current.currentServer else { return }

        delegate.fetching()

        syncTask = Task.detached { [weak self] in
            await self?.sync(type: type, from: from, to: to, refresh: refresh, user: currentUser, server: currentServer)
        }
    }

    @concurrent
    func sync(type: Global.FilterType, from: Date, to: Date, refresh: Bool, user: UserAccount, server: Server) async {

        let error = await dataService.syncFavorites(currentUserAccount: user, currentServer: server)

        if Task.isCancelled { return }

        await MainActor.run { [weak self] in
            self?.handleFavoriteResult(error: error)
        }

        let results = await dataService.fetchFavorites(type: type, fromDate: from, toDate: to, currentUserAccount: user, currentServer: server)

        await MainActor.run { [weak self] in
            self?.delegate.fetchResultReceived(resultItemCount: results.count)
        }

        let local = await Array(self.metadatas.values)
        let syncResult = syncFavorites(locals: local, remotes: results)

        await MainActor.run { [weak self] in
            self?.applyDatasourceChanges(add: syncResult.add, update: syncResult.update, delete: syncResult.delete, refresh: refresh)
        }
    }

    nonisolated func syncFavorites(locals: [Metadata], remotes: [Metadata]) -> (add: [Metadata], update: [Metadata], delete: [Metadata.ID]) {

        var deletes: [Metadata.ID] = []
        var adds: [Metadata] = []
        var updates: [Metadata] = []

        for local in locals {
            if let remote = remotes.first(where: { local.ocId == $0.ocId }) {
                if remote.etag != local.etag || remote.fileName != local.fileName {
                    updates.append(remote)
                }
            } else {
                deletes.append(local.ocId)
            }
        }

        for remote in remotes {
            if !locals.contains(where: { remote.ocId == $0.ocId }) {
                adds.append(remote)
            }
        }

        return (add: adds, update: updates, delete: deletes)
    }

    private func applyDatasourceChanges(add: [Metadata], update: [Metadata], delete: [Metadata.ID], refresh: Bool) {

        guard !add.isEmpty || !update.isEmpty || !delete.isEmpty else {
            delegate.dataSourceUpdated(refresh: refresh)
            return
        }

        var snapshot = dataSource.snapshot()

        for toUpdate in update {
            self.metadatas[toUpdate.id]?.etag = toUpdate.etag
            self.metadatas[toUpdate.id]?.fileName = toUpdate.fileName
            self.metadatas[toUpdate.id]?.fileNameView = toUpdate.fileNameView
            self.metadatas[toUpdate.id]?.date = toUpdate.date
            self.metadatas[toUpdate.id]?.datePhotosOriginal = toUpdate.datePhotosOriginal
            self.metadatas[toUpdate.id]?.hasPreview = toUpdate.hasPreview
            self.metadatas[toUpdate.id]?.size = toUpdate.size
            self.metadatas[toUpdate.id]?.width = toUpdate.width
            self.metadatas[toUpdate.id]?.height = toUpdate.height

            snapshot.reconfigureItems([toUpdate.id])
        }

        for toDelete in delete {
            self.metadatas.removeValue(forKey: toDelete)
            if snapshot.itemIdentifiers(inSection: 0).contains(toDelete) {
                snapshot.deleteItems([toDelete])
            }
        }

        if snapshot.numberOfItems(inSection: 0) == 0 {
            for toAdd in add {
                self.metadatas[toAdd.id] = toAdd
                snapshot.appendItems([toAdd.id])
            }
        } else {
            let sorted = self.metadatas.values.sorted(by: { $0.date > $1.date })
            for toAdd in add {
                self.metadatas[toAdd.id] = toAdd
                if let next = sorted.first(where: { toAdd.date >= $0.date && toAdd.ocId != $0.ocId }) {
                    if snapshot.sectionIdentifier(containingItem: next.id) == nil {

                    } else {
                        self.metadatas[toAdd.id] = toAdd
                        snapshot.insertItems([toAdd.id], beforeItem: next.id)
                    }
                } else {
                    snapshot.appendItems([toAdd.id])
                }
            }
        }

        apply(snapshot: snapshot, animate: false, notify: true, refresh: refresh)
    }

    func bulkEdit(indexPaths: [IndexPath]) async {

        var snapshot = dataSource.snapshot()
        var error = false

        for indexPath in indexPaths {

            guard let id = dataSource.itemIdentifier(for: indexPath) else { continue }
            guard let metadata = metadatas[id] else { continue }

            let result = await dataService.toggleFavoriteMetadata(metadata)

            if result == nil {
                error = true
            } else {
                snapshot.deleteItems([result!.id])
                metadatas.removeValue(forKey: result!.id)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.apply(snapshot: snapshot, animate: true, notify: false, refresh: false, bulk: true, bulkError: error)
        }
    }

    func refreshItems(_ refreshItems: [IndexPath]) {

        let items = refreshItems.compactMap { dataSource.itemIdentifier(for: $0) }

        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(items)

        apply(snapshot: snapshot, animate: false, notify: false, refresh: false)
    }

    func showViewerPager(currentIndex: Int, metadatas: [Metadata]) {
        delegate.videoSelected()
        coordinator.showViewerPager(cacheManager: cacheManager, currentIndex: currentIndex, metadatas: metadatas)
    }

    func getPreviewController(metadata: Metadata) -> PreviewController {
        return coordinator.getPreviewController(metadata: metadata)
    }

    func showFilter(filterable: Filterable, from: Date?, to: Date?) {
        coordinator.showFilter(filterable: filterable, from: from, to: to)
    }

    func dismissFilter() {
        coordinator.dismissFilter()
    }

    func showInvalidFilterError() {
        coordinator.showInvalidFilterError()
    }

    func showLoadfailedError() {
        coordinator.showLoadfailedError()
    }

    func showFavoriteUpdateFailedError() {
        coordinator.showFavoriteUpdateFailedError()
    }

    func showPicker() {
        coordinator.showPicker()
    }

    func share(indexPaths: [IndexPath]) {
        var selectedMetadatas: [Metadata] = []
        for indexPath in indexPaths {
            guard let id = dataSource.itemIdentifier(for: indexPath) else { continue }
            guard let metadata = metadatas[id] else { continue }

            selectedMetadatas.append(metadata)
        }

        coordinator.share(selectedMetadatas)
    }

    private func handleFavoriteResult(error: Bool) {
        if error {
            delegate.fetchResultReceived(resultItemCount: nil)
        }
    }

    private func initCell(metadataId: Metadata.ID, cell: CollectionViewCell, indexPath: IndexPath) -> CollectionViewCell {

        guard let metadata = self.metadatas[metadataId],
              let account = Environment.current.currentUser?.account else {
            cell.isAccessibilityElement = false
            return cell
        }

        let cached = cacheManager.cached(ocId: metadata.ocId, etag: metadata.etag)

        populateCell(account: account, metadata: metadata, cached: cached, cell: cell, indexPath: indexPath)

        return cell
    }

    nonisolated private func populateCell(account: String, metadata: Metadata, cached: UIImage?, cell: CollectionViewCell, indexPath: IndexPath) {

        DispatchQueue.main.async {

            if cell.isSelected == false {
                cell.selected(false, removal: false)
            }

            cell.isAccessibilityElement = true
            cell.accessibilityTraits = [.image]

            if metadata.classFile == NKTypeClassFile.video.rawValue {
                cell.showVideoIcon()
                cell.accessibilityLabel = Strings.MediaVideo
            } else if metadata.livePhoto {
                cell.showLivePhotoIcon()
                cell.accessibilityLabel = Strings.MediaLivePhoto
            } else {
                cell.resetStatusIcon()
                cell.accessibilityLabel = Strings.MediaPhoto
            }
        }

        if cached != nil {
            DispatchQueue.main.async {
                cell.setImage(cached)
            }
        } else {
            let path = dataService.store.getIconPath(metadata.ocId, metadata.etag)

            if FileManager.default.fileExists(atPath: path) {

                let image = UIImage(contentsOfFile: path)

                DispatchQueue.main.async { [weak self] in

                    cell.imageStatus.tintColor = .white
                    cell.setImage(image)

                    if image != nil {
                        self?.cacheManager.cache(metadata: metadata, image: image!)
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in

                    if self?.systemIconIds.contains(metadata.id) == true {
                        cell.imageStatus.tintColor = .systemGray2
                        if !metadata.video && !metadata.livePhoto {
                            cell.imageStatus.isHidden = false
                            cell.imageStatus.image = UIImage(systemName: "photo")
                        }
                    } else {
                        if self?.pauseLoading == false {
                            self?.cacheManager.download(account: account, metadata: metadata, delegate: self!)
                        }
                    }
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate.editCellUpdated(cell: cell, indexPath: indexPath)
        }
    }

    private func apply(snapshot: NSDiffableDataSourceSnapshot<Int, Metadata.ID>, animate: Bool, notify: Bool, refresh: Bool, bulk: Bool = false, bulkError: Bool = false) {

        dataSourceQueue.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                if bulk {
                    self?.dataSource.apply(snapshot, animatingDifferences: animate, completion: { [weak self] in
                        self?.delegate.bulkEditFinished(error: bulkError)
                    })
                } else if notify {
                    self?.dataSource.apply(snapshot, animatingDifferences: animate, completion: { [weak self] in
                        self?.delegate.dataSourceUpdated(refresh: refresh)
                    })
                } else {
                    self?.dataSource.apply(snapshot, animatingDifferences: animate)
                }
            }
        }
    }

    private func compare(_ oldMetadata: Metadata?, _ new: Metadata) -> Bool {

        if let old = oldMetadata {
            return old.etag != new.etag || old.fileNameView != new.fileNameView
        }

        return false
    }
}

extension FavoritesViewModel: DownloadPreviewOperationDelegate {

    func previewDownloaded(metadata: Metadata) {

        var snapshot = dataSource.snapshot()
        let displayed = snapshot.itemIdentifiers(inSection: 0)

        if displayed.contains(metadata.id) {

            let path = dataService.store.getIconPath(metadata.ocId, metadata.etag)

            if FileManager().fileExists(atPath: path) {
                snapshot.reconfigureItems([metadata.id])
                apply(snapshot: snapshot, animate: false, notify: false, refresh: false)
            } else {
                systemIconIds.append(metadata.id)
                snapshot.reconfigureItems([metadata.id])
                apply(snapshot: snapshot, animate: false, notify: false, refresh: false)
            }
        }
    }
}
