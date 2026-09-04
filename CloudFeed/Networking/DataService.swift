//
//  DataService.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/1/23.
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

import Alamofire
import os.log
import SwiftyJSON
import UIKit
import WidgetKit

enum DataServiceFailureCondition: Error {
    case databaseStorageFailed
}

nonisolated final class DataService: NSObject, Sendable {

    let store: StoreUtility

    private let nextcloudService: NextcloudKitServiceProtocol
    private let databaseManager: DatabaseManager

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DataService.self)
    )

    init(store: StoreUtility, nextcloudService: NextcloudKitServiceProtocol) async throws {

        self.store = store
        self.nextcloudService = nextcloudService

        self.databaseManager = try await Task.detached {
            guard let dbUrl = store.databaseDirectory?.appending(path: Global.shared.database) else { throw DataServiceFailureCondition.databaseStorageFailed }
            let modelContainer = DatabaseManager.urlContainer(dbUrl)
            return DatabaseManager(modelContainer: modelContainer)
        }.value
    }

    init(store: StoreUtility, nextcloudService: NextcloudKitServiceProtocol, inMemory: Bool) async throws {

        self.store = store
        self.nextcloudService = nextcloudService

        self.databaseManager = await Task.detached {
            return DatabaseManager(modelContainer: DatabaseManager.memoryContainer())
        }.value
    }

    func setup() {
        nextcloudService.setup()
    }

    func loginPoll(token: String, endpoint: String) async -> (urlBase: String, user: String, appPassword: String)? {
        return await nextcloudService.loginPoll(token: token, endpoint: endpoint)
    }

    func getLoginFlowV2(url: String, serverVersion: Int) async -> (token: String, endpoint: String, login: String)? {
        return await nextcloudService.getLoginFlowV2(url: url, serverVersion: serverVersion)
    }

    func checkServerStatus(url: String) async -> (serverVersion: Int?, errorCode: Int?) {
        return await nextcloudService.checkServerStatus(url: url)
    }

    func appendSession(account: String, user: String, userId: String, urlBase: String) async {

        let password = store.getPassword(account) ?? ""

        nextcloudService.appendSession(account: account, urlBase: urlBase, user: user, userId: userId,
                                       password: password, userAgent: Global.shared.userAgent,
                                       groupIdentifier: Global.shared.groupIdentifier)
    }

    func removeSession(account: String) {
        nextcloudService.removeSession(account: account)
    }

    func writeCertificate(host: String) {

        if let path = store.certificatesDirectory?.path {

            let certificateAtPath = path + "/" + host + ".tmp"
            let certificateToPath = path + "/" + host + ".der"

            if !store.copyFile(atPath: certificateAtPath, toPath: certificateToPath) {
                Self.logger.error("[ERROR] Write certificare error")
            }
        }
    }

    // MARK: -
    // MARK: Account Management
    func getActiveAccount() async -> Account? {
        return await databaseManager.getActiveAccount()
    }

    func setActiveAccount(_ account: String) async -> Account? {
        return await databaseManager.setActiveAccount(account)
    }

    func getAccountCount() async -> Int {
        return await databaseManager.getAccountCount()
    }

    func deleteAccount(_ account: String) async {
        await databaseManager.deleteAccount(account)
    }

    func removeAccount(_ account: String) async {
        await clearDatabase(account: account, removeAccount: true)
        removeSession(account: account)
        store.setPassword(account, password: nil)
        store.deletePasscode(account)
        store.deleteFailedPasscodeCount(account)
        store.deleteAppResetOnFailedAttempts(account)
        await store.clearCache()
        clearWidgetData()
    }

    func addAccount(_ account: String, urlBase: String, user: String, password: String) async {
        await databaseManager.addAccount(account, urlBase: urlBase, user: user, userId: user)
        store.setPassword(account, password: password)
    }

    func getAccountsOrdered() async -> [Account] {
        return await databaseManager.getAccountsOrdered()
    }

    func updateAccount(account: String) async {
        let profile = await getUserProfile(account: account)
        await databaseManager.updateAccount(account: account, displayName: profile?.name ?? "")
    }

    func updateAccountMediaPath(account: String, mediaPath: String) async {
        await databaseManager.updateAccountMediaPath(account: account, mediaPath: mediaPath)
    }

    func clearWidgetData() {
        store.clearWidgetFavoriteData("")
        store.clearWidgetFavoriteData(WidgetFamily.systemSmall.description)
        store.clearWidgetFavoriteData(WidgetFamily.systemMedium.description)
        store.clearWidgetFavoriteData(WidgetFamily.systemLarge.description)
        store.clearWidgetFavoriteData(WidgetFamily.systemExtraLarge.description)
        store.setWidgetFavoriteLastImageDate(date: nil)
        store.setWidgetFavoriteLastImageOcId(ocId: nil)

        store.clearWidgetFeedData("")
        store.clearWidgetFeedData(WidgetFamily.systemSmall.description)
        store.clearWidgetFeedData(WidgetFamily.systemMedium.description)
        store.clearWidgetFeedData(WidgetFamily.systemLarge.description)
        store.clearWidgetFeedData(WidgetFamily.systemExtraLarge.description)
        store.setWidgetFeedLastImageDate(date: nil)
        store.setWidgetFeedLastImageOcId(ocId: nil)

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: -
    // MARK: Database Management
    func clearDatabase(account: String?, removeAccount: Bool) async {
        await databaseManager.clearDatabase(account: account, removeAccount: removeAccount)
    }

    func clearDatabase() async {
        await databaseManager.clearDatabase()
    }

    // MARK: -
    // MARK: Metadata
    func getMetadataFromOcId(_ ocId: String) async -> Metadata? {
        return await databaseManager.getMetadataFromOcId(ocId)
    }

    func getMetadataLivePhoto(metadata: Metadata) async -> Metadata? {
        return await databaseManager.getMetadataLivePhoto(metadata: metadata)
    }

    func readFolder(account: String, serverUrl: String, depth: String) async -> (metadatas: [Metadata], mediaFileCount: Int)? {
        if let results = await nextcloudService.readFolder(account: account, serverUrl: serverUrl, depth: depth) {
            return (metadatas: results.metadatas, mediaFileCount: results.mediaFileCount)
        } else {
            return nil
        }
    }

    // MARK: -
    // MARK: Avatar
    func downloadAvatar(userId: String, urlBase: String, account: String, screenScale: CGFloat) async {

        let fileNameLocalPath = store.getAvatarPath(userId, urlBase)
        let fileName = URL(filePath: fileNameLocalPath).lastPathComponent

        var etag: String?
        if FileManager.default.fileExists(atPath: fileNameLocalPath) {
            etag = await databaseManager.getAvatar(fileName: fileName)?.etag
        }

        let avatarSize = Global.shared.avatarSizeBase * Int(screenScale)
        let etagResult = await nextcloudService.downloadAvatar(account: account, userId: userId, fileNameLocalPath: fileNameLocalPath, etag: etag, avatarSize: avatarSize)

        guard etagResult != nil else { return }
        await databaseManager.addAvatar(fileName: fileName, etag: etagResult!)
    }

    func downloadAvatar(fileName: String, account: Account, screenScale: CGFloat) async {

        let fileNameLocalPath = store.getUserDirectory() + "/" + fileName

        var etag: String?
        if FileManager.default.fileExists(atPath: fileNameLocalPath) {
            etag = await databaseManager.getAvatar(fileName: fileName)?.etag
        }

        let avatarSize = Global.shared.avatarSizeBase * Int(screenScale)
        let etagResult = await nextcloudService.downloadAvatar(account: account.account, userId: account.userId, fileNameLocalPath: fileNameLocalPath, etag: etag, avatarSize: avatarSize)

        guard etagResult != nil else { return }
        await databaseManager.addAvatar(fileName: fileName, etag: etagResult!)
    }

    // MARK: -
    // MARK: Favorites
    func toggleFavoriteMetadata(_ metadata: Metadata) async -> Metadata? {

        if let videoMetadata = await databaseManager.getMetadataLivePhoto(metadata: metadata) {
            if videoMetadata.favorite == metadata.favorite {
                let result = await toggleFavorite(metadata: videoMetadata)
                if result == nil {
                    return nil
                } else {
                    return await toggleFavorite(metadata: metadata)
                }
            } else {
                return await toggleFavorite(metadata: metadata)
            }
        } else {
            return await toggleFavorite(metadata: metadata)
        }
    }

    private func toggleFavorite(metadata: Metadata) async -> Metadata? {

        let fileName = buildFileNamePath(metadataFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)
        let favorite = !metadata.favorite
        let ocId = metadata.ocId

        let error = await nextcloudService.setFavorite(fileName: fileName, favorite: favorite, account: metadata.account)

        if error {
            return nil
        } else {
            return await databaseManager.setMetadataFavorite(ocId: ocId, favorite: favorite)
        }
    }

    private func buildFileNamePath(metadataFileName: String, serverUrl: String, urlBase: String, userId: String, account: String) -> String {

        let homeServer = buildHomeServer(urlBase: urlBase, userId: userId)

        var fileName = "\(serverUrl.replacingOccurrences(of: homeServer, with: ""))/\(metadataFileName)"

        if fileName.hasPrefix("/") {
            fileName = (fileName as NSString).substring(from: 1)
        }

        return fileName
    }

    func syncFavorites(currentUserAccount: UserAccount?, currentServer: Server?) async -> Bool {

        guard let account = currentUserAccount?.account else { return false }
        guard let mediaPath = await getMediaPath() else { return false }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath, currentUserAccount: currentUserAccount, currentServer: currentServer) else { return false }

        let listingResult = await nextcloudService.listingFavorites(account: account)

        guard listingResult.files != nil else { return true }

        await databaseManager.syncFavorites(account: listingResult.account, startServerUrl: startServerUrl, metadatas: listingResult.files!)

        return false
    }

    func fetchFavorites(type: Global.FilterType, fromDate: Date, toDate: Date, currentUserAccount: UserAccount?, currentServer: Server?) async -> [Metadata] {

        guard let account = currentUserAccount?.account else { return [] }
        guard let mediaPath = await getMediaPath() else { return [] }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath, currentUserAccount: currentUserAccount, currentServer: currentServer) else { return [] }

        return await databaseManager.fetchMetadata(favorite: true, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
    }

    // MARK: -
    // MARK: Download
    func download(account: String, metadata: Metadata, progressHandler: @escaping @Sendable (_ metadata: Metadata, _ progress: Progress) -> Void) async {

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = store.getCachePath(metadata.ocId, metadata.fileName)!

        await nextcloudService.download(account: account, metadata: metadata, serverUrlFileName: serverUrlFileName,
                                        fileNameLocalPath: fileNameLocalPath, progressHandler: progressHandler)
    }

    func downloadPreview(account: String, metadata: Metadata?) async {

        guard let metadata = metadata else { return }

        let previewPath = store.getPreviewPath(metadata.ocId, metadata.etag)
        let iconPath = store.getIconPath(metadata.ocId, metadata.etag)

        await nextcloudService.downloadPreview(account: account, fileId: metadata.fileId,
                                               previewPath: previewPath, iconPath: iconPath, etag: metadata.etag)
    }

    func getVideoFrame(metadata: Metadata) -> UIImage? {

        let path = store.getImagePath(metadata.ocId, metadata.etag)

        if FileManager().fileExists(atPath: path) {
            return autoreleasepool { () -> UIImage? in
                return UIImage(contentsOfFile: path)
            }
        }

        return nil
    }

    func downloadVideoFrame(metadata: Metadata, url: URL, size: CGSize) async -> UIImage? {

        let path = store.getImagePath(metadata.ocId, metadata.etag)

        if FileManager().fileExists(atPath: path) {
            return autoreleasepool { () -> UIImage? in
                return UIImage(contentsOfFile: path)
            }
        } else {
            let image = await ImageUtility.imageFromVideo(url: url, size: size)
            try? image?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: path))

            if image != nil {
                let iconPath = store.getIconPath(metadata.ocId, metadata.etag)
                let previewPath = store.getPreviewPath(metadata.ocId, metadata.etag)

                await ImageUtility.saveImageAtPaths(image: image!, previewPath: previewPath, iconPath: iconPath)
            }

            return image
        }
    }

    func saveVideoPreview(metadata: Metadata, image: UIImage) async {

        let path = store.getImagePath(metadata.ocId, metadata.etag)
        try? image.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: path))

        let iconPath = store.getIconPath(metadata.ocId, metadata.etag)
        let previewPath = store.getPreviewPath(metadata.ocId, metadata.etag)

        await ImageUtility.saveImageAtPaths(image: image, previewPath: previewPath, iconPath: iconPath)
    }

    func downloadVideoPreview(metadata: Metadata?) async {

        guard metadata != nil else { return }

        let iconPath = store.getIconPath(metadata!.ocId, metadata!.etag)
        let previewPath = store.getPreviewPath(metadata!.ocId, metadata!.etag)

        if metadata!.video && !FileManager().fileExists(atPath: iconPath) {

            if let url = await getDirectDownload(metadata: metadata!) {

                let preview = await ImageUtility.imageFromVideo(url: url, size: CGSize(width: Global.shared.sizePreview, height: Global.shared.sizePreview))
                try? preview?.jpegData(compressionQuality: 1)?.write(to: URL(fileURLWithPath: previewPath))

                let icon = preview?.preparingThumbnail(of: CGSize(width: Global.shared.sizeIcon, height: Global.shared.sizeIcon))
                try? icon?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: iconPath))
            }
        }
    }

    func downloadSVGPreview(account: String, metadata: Metadata?) async {

        guard metadata != nil else { return }

        await download(account: account, metadata: metadata!, progressHandler: { _, _ in })

        let iconPath = store.getIconPath(metadata!.ocId, metadata!.etag)
        let previewPath = store.getPreviewPath(metadata!.ocId, metadata!.etag)
        let imagePath = store.getCachePath(metadata!.ocId, metadata!.fileNameView)!

        await ImageUtility.loadSVG(metadata: metadata!, imagePath: imagePath, iconPath: iconPath, previewPath: previewPath)
    }

    func iconPreviewCheck(metadata: Metadata) -> Bool {
        return store.previewExists(metadata.ocId, metadata.etag)
    }

    func savePreview(metadata: Metadata) async {

        if store.fileExists(metadata),
           let path = store.getCachePath(metadata.ocId, metadata.fileNameView),
           let image = UIImage(contentsOfFile: path) {

            let previewPath = store.getPreviewPath(metadata.ocId, metadata.etag)
            let iconPath = store.getIconPath(metadata.ocId, metadata.etag)

            await ImageUtility.saveImageAtPaths(image: image, previewPath: previewPath, iconPath: iconPath)
        }
    }

    func getDirectDownload(metadata: Metadata) async -> URL? {
        return await nextcloudService.getDirectDownload(metadata: metadata) //should pass in account?
    }

    // MARK: -
    // MARK: Search
    func getMetadatas(currentUserAccount: UserAccount?, currentServer: Server?, type: Global.FilterType, fromDate: Date, toDate: Date) async -> [Metadata] {

        guard let account = currentUserAccount?.account else { return [] }
        guard let mediaPath = await getMediaPath() else { return [] }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath, currentUserAccount: currentUserAccount, currentServer: currentServer) else { return [] }

        return await databaseManager.fetchMetadata(favorite: false, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
    }

    func syncMedia(currentUserAccount: UserAccount?, currentServer: Server?, fromDate: Date, toDate: Date,
                   update: @concurrent @Sendable @escaping () async -> Void,
                   finish: @concurrent @Sendable @escaping (_ error: Bool) async -> Void) async {

        guard let account = currentUserAccount?.account else { return }
        guard let userId = currentUserAccount?.userId else { return }
        guard let urlBase = currentServer?.urlBase else { return }
        guard let mediaPath = await getMediaPath() else { return }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath, currentUserAccount: currentUserAccount, currentServer: currentServer) else { return }

        let updateFromChunk: @concurrent @Sendable ([Metadata], Date?, Date?, Date?, Date?) async -> Void = { [weak self] metadatas, syncFromDate, syncToDate, fromDate, toDate in
            guard !Task.isCancelled else { return }
            await self?.syncMetadatas(account: account, mediaPath: mediaPath, startServerUrl: startServerUrl,
                                      remoteMetadatas: metadatas, syncFromDate: syncFromDate, syncToDate: syncToDate, fromDate: fromDate, toDate: toDate, update: update)
        }

        await nextcloudService.search(account: account, userId: userId, urlBase: urlBase, mediaPath: mediaPath,
                                      fromDate: fromDate, toDate: toDate, update: updateFromChunk, finish: finish)
    }

    private func syncMetadatas(account: String, mediaPath: String, startServerUrl: String, remoteMetadatas: [Metadata], syncFromDate: Date?, syncToDate: Date?, fromDate: Date?, toDate: Date?, update: @concurrent @Sendable @escaping () async -> Void) async {

        guard let rangeFrom = syncFromDate ?? remoteMetadatas.last?.date,
                let rangeTo = syncToDate ?? remoteMetadatas.first?.date else { return }

        let local = await databaseManager.getMetadatas(account: account, startServerUrl: startServerUrl, fromDate: rangeFrom, toDate: rangeTo)

        guard !Task.isCancelled else { return }

        let deletes = await databaseManager.syncMetadatas(local: local, remote: remoteMetadatas, fromDate: fromDate, toDate: toDate)

        guard !Task.isCancelled else { return }

        await handleMetadataDeletes(account, deletes)

        guard !Task.isCancelled else { return }

        await update()
    }

    private func handleMetadataDeletes(_ account: String, _ deletes: [Metadata]) async {

        guard deletes.count > 0 else { return }

        Self.logger.debug("Possible sync delete count: \(deletes.count)")

        let chunkSize = Global.shared.queueLimit
        var toDeleteIds: [String] = []

        for start in stride(from: 0, to: deletes.count, by: chunkSize) {

            guard !Task.isCancelled else { return }

            let chunk = Array(deletes[start..<min(start + chunkSize, deletes.count)])

            let results = await withTaskGroup(of: String.self) { group in

                var chunkDeleteIds: [String] = []

                for delete in chunk {

                    guard !Task.isCancelled else { return [String]() }

                    group.addTask { [weak self] in
                        if let serverUrlFileName = self?.buildServerUrlFileName(delete) {
                            let exists = await self?.nextcloudService.fileExists(account: account, serverUrlFileName: serverUrlFileName)
                            return exists == false ? delete.ocId : ""
                        }
                        return ""
                    }

                    for await data in group {
                        guard !Task.isCancelled else {
                            group.cancelAll()
                            break
                        }
                        if !data.isEmpty {
                            chunkDeleteIds.append(data)
                        }
                    }
                }

                return chunkDeleteIds
            }

            if results.count > 0 {
                toDeleteIds.append(contentsOf: results)
            }
        }

        Self.logger.debug("Confirmed for deletion count: \(toDeleteIds.count)")

        guard !Task.isCancelled else { return }

        await databaseManager.deleteMetadatas(toDeleteIds)
    }

    private func buildServerUrlFileName(_ metadata: Metadata) -> String {
        if metadata.fileName.isEmpty {
            return metadata.serverUrl
        } else if metadata.serverUrl.last == "/" {
            return metadata.serverUrl + metadata.fileName
        } else {
            return metadata.serverUrl + "/" + metadata.fileName
        }
    }

    private func getMediaPath() async -> String? {
        guard let activeAccount = await getActiveAccount() else { return nil }
        return activeAccount.mediaPath
    }

    private func getStartServerUrl(mediaPath: String?, currentUserAccount: UserAccount?, currentServer: Server?) -> String? {

        guard mediaPath != nil else { return nil }

        let urlBase = currentServer?.urlBase
        let userId = currentUserAccount?.userId

        guard urlBase != nil && userId != nil else { return nil }

        let startServerUrl = urlBase! + Global.shared.davLocation + userId! + mediaPath!

        return startServerUrl
    }

    // MARK: -
    // MARK: Profile
    func getUserProfile(account: String) async -> Profile? {
        return await nextcloudService.getUserProfile(account: account)
    }

    func getServerVersion(account: String) async -> String? {
        return await nextcloudService.getCapabilitiesServerVersion(account)
    }

    // MARK: -
    // MARK: Settings
    func saveDisplayStyle(style: UIUserInterfaceStyle?) {
        store.setDisplayStyle(style: style)
    }

    func getDisplayStyle() -> UIUserInterfaceStyle? {
        return store.getDisplayStyle()
    }

    func getVideoControlsStyleBackground() -> Bool? {
        return store.getVideoControlsStyleBackground()
    }

    func saveVideoControlsStyleBackground(hasBackground: Bool) {
        store.saveVideoControlsStyleBackground(hasBackground: hasBackground)
    }

    func getHomeServer(urlBase: String, userId: String) -> String {
        return buildHomeServer(urlBase: urlBase, userId: userId)
    }

    func reset() async {
        await store.clearCache()
        await store.removeDirectories()
        store.deleteAllChainStore()
        await clearDatabase()
        clearWidgetData()
    }

    private func buildHomeServer(urlBase: String, userId: String) -> String {
        let homeServer = urlBase + Global.shared.davLocation + userId
        return homeServer
    }

    // MARK: -
    // MARK: Comments
    func getComments(fileId: String, account: String) async -> [FileComment]? {
        return await nextcloudService.getComments(fileId: fileId, account: account)
    }

    func addComment(fileId: String, account: String, message: String) async -> Bool {
        return await nextcloudService.addComment(fileId: fileId, account: account, message: message)
    }

    func updateComment(fileId: String, account: String, messageId: String, message: String) async -> Bool {
        return await nextcloudService.updateComment(fileId: fileId, account: account, messageId: messageId, message: message)
    }

    func deleteComment(fileId: String, account: String, messageId: String) async -> Bool {
        return await nextcloudService.deleteComment(fileId: fileId, account: account, messageId: messageId)
    }
}
