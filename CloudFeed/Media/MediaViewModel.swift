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
    func searchResultReceived(resultItemCount: Int?, retry: Bool)
    func selectCellUpdated(cell: CollectionViewCell, indexPath: IndexPath)
    func videoSelected()
    func videoPlay(indexPath: IndexPath)
    func syncComplete()
}

@MainActor
final class MediaViewModel {

    var pauseLoading: Bool = false
    var metadataVisible: Bool = false
    var tableMode: Bool = false

    private var dataSource: UICollectionViewDiffableDataSource<Int, Metadata.ID>!
    private var tableDataSource: UITableViewDiffableDataSource<Int, Metadata.ID>!

    private let dataSourceQueue = DispatchQueue(label: "datasource.queue")

    private nonisolated let dataService: DataService
    private let coordinator: MediaCoordinator
    private weak var delegate: MediaDelegate!

    private let cacheManager: CacheManager

    private var metadatas: [Metadata.ID: Metadata] = [:]
    private var systemIconIds: [Metadata.ID] = []

    private var fetchTask: Task<Void, Never>? {
        willSet {
            fetchTask?.cancel()
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MediaViewModel.self)
    )

    init(delegate: MediaDelegate, dataService: DataService, cacheManager: CacheManager, coordinator: MediaCoordinator) {
        self.delegate = delegate
        self.cacheManager = cacheManager
        self.coordinator = coordinator
        self.dataService = dataService
    }

    func initDataSource(collectionView: UICollectionView) {

        dataSource = UICollectionViewDiffableDataSource<Int, Metadata.ID>(collectionView: collectionView) { [weak self] (collectionView: UICollectionView, indexPath: IndexPath, metadataId: Metadata.ID) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainCollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            return self?.initCell(metadataId: metadataId, cell: cell, indexPath: indexPath)
        }

        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
    }

    func initDataSource(tableView: UITableView) {

        tableDataSource = UITableViewDiffableDataSource<Int, Metadata.ID>(tableView: tableView) { [weak self] tableView, indexPath, metadataId in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TableCell", for: indexPath) as? TableCell else { fatalError("Cannot create new cell") }
            return self?.initCell(metadataId: metadataId, cell: cell, indexPath: indexPath)
        }

        var snapshot = tableDataSource.snapshot()
        snapshot.appendSections([0])
        tableDataSource.applySnapshotUsingReloadData(snapshot)
    }

    func share(metadatas: [Metadata]) {
        coordinator.share(metadatas)
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

    func resetDataSource() {

        metadatas.removeAll()

        if dataSource != nil {
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

        if tableDataSource != nil {
            dataSourceQueue.async { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    if var snapshot = self?.tableDataSource.snapshot() {
                        snapshot.deleteAllItems()
                        snapshot.appendSections([0])
                        self?.tableDataSource.applySnapshotUsingReloadData(snapshot)
                    }
                }
            }
        }
    }

    func currentItemCount() -> Int {

        if tableMode == false && dataSource != nil {
            let snapshot = dataSource.snapshot()
            return snapshot.numberOfItems(inSection: 0)
        }

        if tableMode == true && tableDataSource != nil {
            let snapshot = tableDataSource.snapshot()
            return snapshot.numberOfItems(inSection: 0)
        }

        return 0
    }

    func getItems() -> [Metadata] {

        var items: [Metadata] = []

        if tableMode == false, let snapshot = dataSource?.snapshot() {
            for id in snapshot.itemIdentifiers(inSection: 0) {
                if let metadata = metadatas[id] {
                    items.append(metadata)
                }
            }
        } else if tableMode == true, let snapshot = tableDataSource?.snapshot() {
            for id in snapshot.itemIdentifiers(inSection: 0) {
                if let metadata = metadatas[id] {
                    items.append(metadata)
                }
            }
        }

        return items
    }

    func fileExists(_ metadata: Metadata) -> Bool {
        return dataService.store.fileExists(metadata)
    }

    func getMetadataLivePhoto(metadata: Metadata) async -> Metadata? {
        return await dataService.getMetadataLivePhoto(metadata: metadata)
    }

    func downloadLivePhotoVideo(metadata: Metadata) async {
        guard let account = Environment.current.currentUser?.account else { return }
        await dataService.download(account: account, metadata: metadata, progressHandler: { _, _ in })
    }

    func getCachePath(_ ocId: String, _ fileNameView: String) -> String? {
        return dataService.store.getCachePath(ocId, fileNameView)
    }

    func getMetadataFromOcId(_ ocId: String) async -> Metadata? {
        return await dataService.getMetadataFromOcId(ocId)
    }

    func getIndexPathForMetadata(metadata: Metadata) -> IndexPath? {

        if tableMode && tableDataSource != nil {
            return tableDataSource.indexPath(for: metadata.id)
        }
        if tableMode == false && dataSource != nil {
            return dataSource.indexPath(for: metadata.id)
        }

        return nil
    }

    func getItemAtIndexPath(_ indexPath: IndexPath) -> Metadata? {

        if tableMode == false, let id = dataSource?.itemIdentifier(for: indexPath) {
            return metadatas[id]
        }

        if tableMode == true, let id = tableDataSource?.itemIdentifier(for: indexPath) {
            return metadatas[id]
        }

        return nil
    }

    func getLayoutType() -> String {
        return dataService.store.getMediaLayoutType()
    }

    func updateLayoutType(_ type: String) {
        dataService.store.setMediaLayoutType(type)
    }

    func getCollectionType() -> String {
        return dataService.store.getMediaCollectionType()
    }

    func updateCollectionType(_ type: String) {
        metadatas.removeAll()
        dataService.store.setMediaCollectionType(type)
    }

    func getSocialType() -> String {
        return dataService.store.getMediaSocialType()
    }

    func updateSocialType(_ type: String) {
        dataService.store.setMediaSocialType(type)
    }

    func getColumnCount() -> Int {
        return dataService.store.getMediaColumnCount(UIDevice.current.userInterfaceIdiom)
    }

    func saveColumnCount(_ columnCount: Int) {
        dataService.store.setMediaColumnCount(columnCount)
    }

    func reload(reconfigure: Bool = true) {

        if tableMode == false, var snapshot = dataSource?.snapshot() {

            guard snapshot.numberOfSections > 0 else { return }

            if reconfigure {
                snapshot.reconfigureItems(snapshot.itemIdentifiers(inSection: 0))
            } else {
                snapshot.reloadItems(snapshot.itemIdentifiers(inSection: 0))
            }

            applyGrid(snapshot: snapshot, animate: false, notify: false, refresh: false)
        }

        if tableMode == true, var snapshot = tableDataSource?.snapshot() {

            guard snapshot.numberOfSections > 0 else { return }

            if reconfigure {
                snapshot.reconfigureItems(snapshot.itemIdentifiers(inSection: 0))
            } else {
                snapshot.reloadItems(snapshot.itemIdentifiers(inSection: 0))
            }

            if reconfigure {
                applyTable(snapshot: snapshot, animate: true, notify: false, refresh: false)
            } else {
                applyTable(snapshot: snapshot, animate: false, notify: false, refresh: false)
            }
        }
    }

    func getVideoURL(metadata: Metadata) async -> URL? {

        if let url = await dataService.getDirectDownload(metadata: metadata) {
            return url
        }

        return nil
    }

    func getVideoPath(_ metadata: Metadata) -> String? {

        if dataService.store.fileExists(metadata) {
            return dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)
        } else if dataService.store.previewExists(metadata.ocId, metadata.etag) {
            return dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
        }
        return nil
    }

    func cancel() {
        cancelLoads()
        fetchTask?.cancel()
    }

    func cancelLoads() {
        cacheManager.cancelAll()
    }

    func showPicker() {
        coordinator.showPicker()
    }

    func filter(type: Global.FilterType, fromDate: Date, toDate: Date) {
        cancel()
        sync(type: type, fromDate: fromDate, toDate: toDate, refresh: true)
    }

    func sync(type: Global.FilterType, fromDate: Date, toDate: Date, refresh: Bool) {

        guard let currentUser = Environment.current.currentUser,
              let currentServer = Environment.current.currentServer else { return }

        fetchTask = Task.detached { [weak self] in
            await self?.sync(type: type, fromDate: fromDate, toDate: toDate, refresh: refresh, user: currentUser, server: currentServer)
        }
    }

    @concurrent private func sync(type: Global.FilterType, fromDate: Date, toDate: Date, refresh: Bool, user: UserAccount, server: Server) async {

        let update: @concurrent @Sendable () async -> Void = { [weak self] in
            await self?.syncDatasource(type: type, fromDate: fromDate, toDate: toDate, refresh: refresh, user: user, server: server)
        }

        let finish: @concurrent @Sendable (_ error: Bool) async -> Void = { [weak self] error in
            await self?.handleSyncMediaFinished(error: error)
        }

        await MainActor.run { [weak self] in
            self?.delegate.searching()
        }

        await dataService.syncMedia(currentUserAccount: user, currentServer: server, fromDate: fromDate, toDate: toDate, update: update, finish: finish)
    }

    @concurrent private func syncDatasource(type: Global.FilterType, fromDate: Date, toDate: Date, refresh: Bool, user: UserAccount, server: Server) async {

        let metadatas = await dataService.getMetadatas(currentUserAccount: user, currentServer: server, type: type, fromDate: fromDate, toDate: toDate)
        let currentCount = await self.metadatas.count

        if metadatas.count > 0 && currentCount == 0 {
            await MainActor.run { [weak self] in
                self?.delegate.searchResultReceived(resultItemCount: metadatas.count, retry: false)
                self?.applyDatasourceChanges(add: metadatas, update: [], delete: [], refresh: refresh)
            }
            return
        }

        let local = await Array(self.metadatas.values)
        let syncResult = syncMetadata(locals: local, remotes: metadatas)

        await MainActor.run { [weak self] in
            self?.delegate.searchResultReceived(resultItemCount: metadatas.count, retry: false)
            self?.applyDatasourceChanges(add: syncResult.add, update: syncResult.update, delete: syncResult.delete, refresh: refresh)
        }
    }

    nonisolated private func handleSyncMediaFinished(error: Bool) async {

        await MainActor.run { [weak self] in

            if error {
                let retry: () -> Void = { [weak self] in
                    self?.delegate.searchResultReceived(resultItemCount: nil, retry: true)
                }
                self?.delegate.searchResultReceived(resultItemCount: nil, retry: false)
                self?.coordinator.showLoadFailedError(retry: retry)
            } else {
                self?.delegate.syncComplete()
            }
        }
    }

    func refreshItems(_ refreshItems: [IndexPath], reload: Bool = false) {

        if tableMode == false && dataSource != nil {
            let items = refreshItems.compactMap { dataSource.itemIdentifier(for: $0) }
            var snapshot = dataSource.snapshot()

            snapshot.reconfigureItems(items)
            applyGrid(snapshot: snapshot, animate: false, notify: false, refresh: false)
        }

        if tableMode == true && tableDataSource != nil {
            let items = refreshItems.compactMap { tableDataSource.itemIdentifier(for: $0) }
            var snapshot = tableDataSource.snapshot()

            if reload {
                snapshot.reloadItems(items)
            } else {
                snapshot.reconfigureItems(items)
            }
            applyTable(snapshot: snapshot, animate: false, notify: false, refresh: false)
        }
    }

    func share(indexPaths: [IndexPath]) {

        var selectedMetadatas: [Metadata] = []

        for indexPath in indexPaths {
            guard let id = dataSource?.itemIdentifier(for: indexPath) else { continue }
            guard let metadata = metadatas[id] else { continue }

            selectedMetadatas.append(metadata)
        }

        if selectedMetadatas.isEmpty == false {
            coordinator.share(selectedMetadatas)
        }
    }

    func toggleFavorite(metadata: Metadata) {

        Task { [weak self] in

            let result = await self?.dataService.toggleFavoriteMetadata(metadata)

            if result == nil {
                self?.delegate.favoriteUpdated(error: true)
                self?.coordinator.showFavoriteUpdateFailedError()
            } else {

                self?.metadatas[metadata.id]?.favorite = result!.favorite

                await MainActor.run { [weak self] in

                    if self?.tableMode == false, var snapshot = self?.dataSource.snapshot() {
                        snapshot.reconfigureItems([metadata.id])

                        self?.applyGrid(snapshot: snapshot, animate: false, notify: false, refresh: false)
                        self?.delegate.favoriteUpdated(error: false)
                    }

                    if self?.tableMode == true, var snapshot = self?.tableDataSource.snapshot() {
                        snapshot.reconfigureItems([metadata.id])

                        self?.applyTable(snapshot: snapshot, animate: false, notify: false, refresh: false)
                        self?.delegate.favoriteUpdated(error: false)
                    }
                }
            }
        }
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

    nonisolated private func syncMetadata(locals: [Metadata], remotes: [Metadata]) -> (add: [Metadata], update: [Metadata], delete: [Metadata.ID]) {

        var deletes: [Metadata.ID] = []
        var adds: [Metadata] = []
        var updates: [Metadata] = []

        for local in locals {
            if let remote = remotes.first(where: { local.ocId == $0.ocId }) {
                if remote.favorite != local.favorite || remote.etag != local.etag || remote.fileName != local.fileName {
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

        var snapshot = tableMode ? tableDataSource.snapshot() : dataSource.snapshot()

        for toUpdate in update {
            self.metadatas[toUpdate.id]?.etag = toUpdate.etag
            self.metadatas[toUpdate.id]?.fileName = toUpdate.fileName
            self.metadatas[toUpdate.id]?.fileNameView = toUpdate.fileNameView
            self.metadatas[toUpdate.id]?.favorite = toUpdate.favorite
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
                if let next = sorted.first(where: { toAdd.date >= $0.date && toAdd.ocId != $0.ocId }) {
                    if snapshot.sectionIdentifier(containingItem: next.id) == nil {

                    } else {
                        self.metadatas[toAdd.id] = toAdd
                        snapshot.insertItems([toAdd.id], beforeItem: next.id)
                    }
                } else {
                    self.metadatas[toAdd.id] = toAdd
                    snapshot.appendItems([toAdd.id])
                }
            }
        }

        apply(snapshot: snapshot, animate: false, notify: true, refresh: refresh)
    }

    private func applyTable(snapshot: NSDiffableDataSourceSnapshot<Int, Metadata.ID>, animate: Bool, notify: Bool, refresh: Bool) {

        dataSourceQueue.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                if notify {
                    self?.tableDataSource.apply(snapshot, animatingDifferences: animate, completion: { [weak self] in
                        self?.delegate.dataSourceUpdated(refresh: refresh)
                    })
                } else {
                    self?.tableDataSource.apply(snapshot, animatingDifferences: animate)
                }
            }
        }
    }

    private func applyGrid(snapshot: NSDiffableDataSourceSnapshot<Int, Metadata.ID>, animate: Bool, notify: Bool, refresh: Bool) {

        dataSourceQueue.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                if notify {
                    self?.dataSource.apply(snapshot, animatingDifferences: animate, completion: { [weak self] in
                        self?.delegate.dataSourceUpdated(refresh: refresh)
                    })
                } else {
                    self?.dataSource.apply(snapshot, animatingDifferences: animate)
                }
            }
        }
    }

    private func apply(snapshot: NSDiffableDataSourceSnapshot<Int, Metadata.ID>, animate: Bool, notify: Bool, refresh: Bool) {

        if tableMode && tableDataSource != nil {
            applyTable(snapshot: snapshot, animate: animate, notify: notify, refresh: refresh)
        } else if tableMode == false && dataSource != nil {
            applyGrid(snapshot: snapshot, animate: animate, notify: notify, refresh: refresh)
        }
    }

    private func compare(_ oldMetadata: Metadata?, _ new: Metadata) -> Bool {

        if let old = oldMetadata {
            return old.favorite != new.favorite || old.etag != new.etag || old.fileNameView != new.fileNameView
        }

        return false
    }

    private func initCell(metadataId: Metadata.ID, cell: TableCell, indexPath: IndexPath) -> TableCell {

        guard let metadata = metadatas[metadataId],
              let account = Environment.current.currentUser?.account else {
            cell.isAccessibilityElement = false
            return cell
        }

        let cachedAvatar = cacheManager.cached(urlBase: metadata.urlBase, userId: metadata.ownerId)
        let cachedImage = cacheManager.cached(ocId: metadata.ocId, etag: metadata.etag)

        populateCell(metadata: metadata, account: account, cachedAvatar: cachedAvatar, cachedImage: cachedImage, cell: cell, indexPath: indexPath)

        return cell
    }

    nonisolated private func populateCell(metadata: Metadata, account: String, cachedAvatar: UIImage?, cachedImage: UIImage?, cell: TableCell, indexPath: IndexPath) {

        DispatchQueue.main.async { [weak self] in

            cell.delegate = self!
            cell.metadataId = metadata.id

            cell.setFavorite(metadata.favorite)
            cell.setInfoVisibility(self?.metadataVisible == true)
            cell.forVideo(metadata.video)
            cell.forLivePhoto(metadata.livePhoto)

            cell.createDateLabel.text = metadata.datePhotosOriginal.formatted(date: .long, time: .shortened)
            cell.dateLabel.text = metadata.date.formatted(date: .long, time: .shortened)
            cell.ownerLabel.text = metadata.ownerDisplayName

            cell.nameLabel.text = (metadata.fileNameView as NSString).deletingPathExtension
            cell.typeLabel.text = metadata.fileExtension.uppercased()

            let width = metadata.width
            let height = metadata.height

            if width > 0 && height > 0 {
                let formattedWidth = String(format: "%.0f", width)
                let formattedHeight = String(format: "%.0f", height)
                let formattedPixels = "\(formattedWidth) x \(formattedHeight)"

                cell.pixelSizeLabel.text = formattedPixels
            }

            if metadata.size > 0 {
                let formattedFileSize = ByteCountFormatter.string(fromByteCount: metadata.size, countStyle: .file)
                cell.sizeLabel.text = formattedFileSize
            }
        }

        let ownerId = metadata.ownerId

        if ownerId.isEmpty {

        } else {

            if cachedAvatar != nil {
                DispatchQueue.main.async {
                    cell.ownerImageView?.image = cachedAvatar
                }
            } else {

                let avatarPath = dataService.store.getAvatarPath(metadata.ownerId, metadata.urlBase)

                if FileManager.default.fileExists(atPath: avatarPath) {

                    let image = UIImage(contentsOfFile: avatarPath)

                    DispatchQueue.main.async { [weak self] in
                        cell.ownerImageView?.image = image

                        if image != nil {
                            self?.cacheManager.cache(urlBase: metadata.urlBase, userId: metadata.ownerId, image: image!)
                        }
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        if self?.pauseLoading == false {
                            self?.cacheManager.download(objectId: metadata.id, userId: metadata.ownerId, urlBase: metadata.urlBase, account: account, delegate: self!)
                        }
                    }
                }
            }
        }

        if cachedImage != nil {
            DispatchQueue.main.async {
                cell.setPreviewImage(cachedImage)
            }
        } else {

            let path = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)

            if FileManager.default.fileExists(atPath: path) {

                let image = UIImage(contentsOfFile: path)

                DispatchQueue.main.async { [weak self] in
                    cell.setPreviewImage(image)

                    if image != nil {
                        self?.cacheManager.cache(metadata: metadata, image: image!)
                    }
                }
            } else {

                DispatchQueue.main.async { [weak self] in

                    if self?.systemIconIds.contains(metadata.id) == true {

                        if metadata.video {
                            cell.setSystemImage(name: "play")
                        } else if metadata.image {
                            cell.setSystemImage(name: "photo")
                        }
                    } else {

                        if self?.pauseLoading == false {
                            self?.cacheManager.download(account: account, metadata: metadata, delegate: self! as DownloadPreviewOperationDelegate)
                        }
                    }
                }
            }
        }

        DispatchQueue.main.async {
            cell.invalidate()
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

            if metadata.video {
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
                            self?.cacheManager.download(account: account, metadata: metadata, delegate: self! as DownloadPreviewOperationDelegate)
                        }
                    }
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate.selectCellUpdated(cell: cell, indexPath: indexPath)
        }
    }

    private func handleToggleFavorite(metadataId: String) {
        if let metadata = metadatas[metadataId] {
            toggleFavorite(metadata: metadata)
        }
    }

    private func handleShare(metadataId: String) {
        if let metadata = metadatas[metadataId] {
            share(metadatas: [metadata])
        }
    }

    private func handleComment(metadataId: String) {
        if let metadata = metadatas[metadataId] {
            coordinator.showComments(cacheManager: cacheManager, metadata: metadata)
        }
    }

    private func handleVideo(metadataId: String) {
        if let indexPath = tableDataSource.indexPath(for: metadataId) {
            delegate.videoPlay(indexPath: indexPath)
        }
    }

    private func handleAvatarDownloaded(_ id: String) {

        var snapshot = tableDataSource.snapshot()
        let displayed = snapshot.itemIdentifiers(inSection: 0)

        if displayed.contains(id), let metadata = metadatas[id] {

            let path = dataService.store.getAvatarPath(metadata.ownerId, metadata.urlBase)

            if FileManager.default.fileExists(atPath: path) {
                snapshot.reconfigureItems([metadata.id])
                applyTable(snapshot: snapshot, animate: false, notify: false, refresh: false)
            }
        }
    }

    private func handlePreviewDownloaded(_ metadata: Metadata) {

        if tableMode && tableDataSource != nil {
            var snapshot = tableDataSource.snapshot()
            let displayed = snapshot.itemIdentifiers(inSection: 0)

            if displayed.contains(metadata.id) {

                let path = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)

                if FileManager.default.fileExists(atPath: path) {
                    snapshot.reconfigureItems([metadata.id])
                } else {
                    systemIconIds.append(metadata.id)
                    snapshot.reconfigureItems([metadata.id])
                }

                applyTable(snapshot: snapshot, animate: false, notify: false, refresh: false)
            }
        } else if tableMode == false && dataSource != nil {

            var snapshot = dataSource.snapshot()
            let displayed = snapshot.itemIdentifiers(inSection: 0)

            if displayed.contains(metadata.id) {

                let path = dataService.store.getIconPath(metadata.ocId, metadata.etag)

                if FileManager.default.fileExists(atPath: path) {
                    snapshot.reconfigureItems([metadata.id])
                    applyGrid(snapshot: snapshot, animate: false, notify: false, refresh: false)
                } else {
                    systemIconIds.append(metadata.id)
                    snapshot.reconfigureItems([metadata.id])
                    applyGrid(snapshot: snapshot, animate: false, notify: false, refresh: false)
                }
            }
        }
    }
}

extension MediaViewModel: TableCellDelegate {

    func toggleFavoriteForMetadata(metadataId: String) {
        handleToggleFavorite(metadataId: metadataId)
    }

    func shareForMetadata(metadataId: String) {
        handleShare(metadataId: metadataId)
    }

    func commentForMetadata(metadataId: String) {
        handleComment(metadataId: metadataId)
    }

    func videoForMetadata(metadataId: String) {
        handleVideo(metadataId: metadataId)
    }
}

extension MediaViewModel: DownloadPreviewOperationDelegate {

    func previewDownloaded(metadata: Metadata) {
        handlePreviewDownloaded(metadata)
    }
}

extension MediaViewModel: DownloadAvatarOperationDelegate {

    func avatarDownloaded(id: String) {
        handleAvatarDownloaded(id)
    }
}
