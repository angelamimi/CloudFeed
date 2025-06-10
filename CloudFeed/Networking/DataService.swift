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
@preconcurrency import NextcloudKit
import SwiftyJSON
import UIKit

final class DataService: NSObject, Sendable {
    
    let store: StoreUtility
    
    private let nextcloudService: NextcloudKitServiceProtocol
    private let databaseManager: DatabaseManager
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DataService.self)
    )
    
    init(store: StoreUtility, nextcloudService: NextcloudKitServiceProtocol, databaseManager: DatabaseManager) {
        self.store = store
        self.nextcloudService = nextcloudService
        self.databaseManager = databaseManager
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
        let serverVersionMajor = await getCapabilitiesServerVersionMajor(account: account)
        
        nextcloudService.appendSession(account: account, urlBase: urlBase, user: user, userId: userId,
                                       password: password, userAgent: Global.shared.userAgent, nextcloudVersion: serverVersionMajor,
                                       groupIdentifier: Global.shared.groupIdentifier)
    }
    
    func getCapabilitiesServerVersionMajor(account: String) async -> Int {
        
        if let data = await nextcloudService.getCapabilities(account: account) {
            let json = JSON(data)
            return json[Global.shared.capabilitiesVersionMajor].intValue
        }
        
        return 0
    }
    
    func removeSession(account: String) {
        nextcloudService.removeSession(account: account)
    }
    
    func writeCertificate(host: String) {
        
        if let path = store.certificatesDirectory?.path {
            
            let certificateAtPath = path + "/" + host + ".tmp"
            let certificateToPath = path + "/" + host + ".der"
            
            if !store.copyFile(atPath: certificateAtPath, toPath: certificateToPath) {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Write certificare error")
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
        await store.clearCache()
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
        await databaseManager.updateAccount(account: account, displayName: profile.profileDisplayName)
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
    
    
    // MARK: -
    // MARK: Avatar
    @MainActor
    func downloadAvatar(fileName: String, account: Account) async {
        
        let fileNameLocalPath = store.getUserDirectory() + "/" + fileName
        
        var etag: String? = nil
        if FileManager.default.fileExists(atPath: fileNameLocalPath) {
            etag = await databaseManager.getAvatar(fileName: fileName)?.etag
        }
        
        let avatarSize = Global.shared.avatarSizeBase * Int(UIScreen.main.scale)
        let etagResult = await nextcloudService.downloadAvatar(account: account.account, userId: account.userId, fileName: fileName,
                                                               fileNameLocalPath: fileNameLocalPath, etag: etag, avatarSize: avatarSize, avatarSizeRounded: Global.shared.avatarSizeRounded)

        guard etagResult != nil else { return }
        await databaseManager.addAvatar(fileName: fileName, etag: etagResult!)
    }
    
    
    // MARK: -
    // MARK: Favorites
    func toggleFavoriteMetadata(_ metadata: Metadata) async -> Metadata? {
        
        if let metadataLive = await databaseManager.getMetadataLivePhoto(metadata: metadata) {
            let result = await toggleFavorite(metadata: metadataLive)
            if result == nil {
                return nil
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
        
        let error = await nextcloudService.setFavorite(fileName: fileName, favorite: favorite, ocId: ocId, account: metadata.account)
        
        if error {
            return nil
        } else {
            return await databaseManager.setMetadataFavorite(ocId: ocId, favorite: favorite)
        }
    }
    
    private func buildFileNamePath(metadataFileName: String, serverUrl: String, urlBase: String, userId: String, account: String) -> String {
        
        let homeServer = urlBase + Global.shared.davLocation + userId
        
        var fileName = "\(serverUrl.replacingOccurrences(of: homeServer, with: ""))/\(metadataFileName)"

        if fileName.hasPrefix("/") {
            fileName = (fileName as NSString).substring(from: 1)
        }
        
        return fileName
    }
    
    @MainActor
    func getFavorites() async -> Bool {
        
        guard let account = Environment.current.currentUser?.account else { return false }
        guard let mediaPath = await getMediaPath() else { return false }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return false }
        
        let listingResult = await nextcloudService.listingFavorites(account: account)
        
        guard listingResult.files != nil else { return true }
        
        await databaseManager.updateMetadatasFavorite(account: listingResult.account, startServerUrl: startServerUrl, metadatas: listingResult.files!)
        
        return false
    }
    
    @MainActor
    func paginateFavoriteMetadata(type: Global.FilterType, fromDate: Date, toDate: Date, offsetDate: Date?, offsetName: String?) async -> [Metadata] {
        
        guard let account = Environment.current.currentUser?.account else { return [] }
        guard let mediaPath = await getMediaPath() else { return [] }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return [] }
        
        return await databaseManager.paginateMetadata(favorite: true, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate, offsetDate: nil, offsetName: nil)
    }
    
    @MainActor
    func processFavorites(displayedMetadataIds: [Metadata.ID], displayedMetadatas: [Metadata.ID: Metadata], type: Global.FilterType, from: Date?, to: Date?) async -> (delete: [Metadata.ID], add: [Metadata], update: [Metadata])? {

        guard let account = Environment.current.currentUser?.account else { return nil }
        guard let mediaPath = await getMediaPath() else { return nil }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return nil }

        var delete: [Metadata.ID] = []
        var add: [Metadata] = []
        var update: [Metadata] = []
        var savedFavorites: [Metadata] = []

        savedFavorites = await databaseManager.paginateMetadata(favorite: true, type: type, account: account, startServerUrl: startServerUrl,
                                                                fromDate: from ?? Date.distantPast, toDate: to ?? Date.distantFuture,
                                                                offsetDate: nil, offsetName: nil)
        
        //Self.logger.debug("processFavorites() - savedFavorites count: \(savedFavorites.count) displayedMetadataIds count: \(displayedMetadataIds.count)")
        
        //if displayed but doesn't exist in db, flag for delete
        for displayedMetadataId in displayedMetadataIds {
            if savedFavorites.firstIndex(where: { $0.id == displayedMetadataId }) == nil {
                delete.append(displayedMetadataId)
            }
        }
        
        for saved in savedFavorites {
            if displayedMetadataIds.firstIndex(where: { $0 == saved.id }) == nil {
                //if exists in db, but is not displayed, flag for add
                add.append(saved)
            } else {
                //exists in db, but changed. flag for update
                if let displayed = displayedMetadatas[saved.id], displayed.fileNameView != saved.fileNameView  {
                    update.append(saved)
                }
            }
        }
        
        return (delete, add, update)
    }

    
    // MARK: -
    // MARK: Download
    func download(metadata: Metadata, progressHandler: @escaping @Sendable (_ metadata: Metadata, _ progress: Progress) -> Void) async {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = store.getCachePath(metadata.ocId, metadata.fileName)!

        await nextcloudService.download(metadata: metadata, serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, progressHandler: progressHandler)
    }
    
    func downloadPreview(metadata: Metadata?) async {
        
        guard let metadata = metadata else { return }
        
        var previewPath: String
        var iconPath: String
        
        previewPath = store.getPreviewPath(metadata.ocId, metadata.etag)
        iconPath = store.getIconPath(metadata.ocId, metadata.etag)
        
        var etagResource: String?
        if FileManager.default.fileExists(atPath: iconPath) {
            etagResource = metadata.etagResource
        }
        
        if let etag = await nextcloudService.downloadPreview(account: metadata.account, fileId: metadata.fileId, previewPath: previewPath,
                                                             iconPath: iconPath, etagResource: etagResource) {
            await databaseManager.setMetadataEtagResource(ocId: metadata.ocId, etagResource: etag)
        }
    }
    
    func getVideoFrame(metadata: Metadata) -> UIImage? {
        
        let path = store.getImagePath(metadata.ocId, metadata.etag)
        
        if FileManager().fileExists(atPath: path) {
            return UIImage(contentsOfFile: path)
        }
        
        return nil
    }
    
    func downloadVideoFrame(metadata: Metadata, url: URL, size: CGSize) async -> UIImage? {
        
        let path = store.getImagePath(metadata.ocId, metadata.etag)
        
        if FileManager().fileExists(atPath: path) {
            return UIImage(contentsOfFile: path)
        } else {
            let image = await ImageUtility.imageFromVideo(url: url, size: size)
            try? image?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: path))
            
            return image
        }
    }
    
    func downloadVideoPreview(metadata: Metadata?) async {
        
        guard metadata != nil else { return }
        
        let path = store.getIconPath(metadata!.ocId, metadata!.etag)

        if metadata!.video && !FileManager().fileExists(atPath: path) {

            if let url = await getDirectDownload(metadata: metadata!) {
                
                let image = await ImageUtility.imageFromVideo(url: url, size: CGSize(width: Global.shared.sizeIcon, height: Global.shared.sizeIcon))
                
                //Save the preview image
                try? image?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: path))
            }
        }
    }
    
    func getDirectDownload(metadata: Metadata) async -> URL? {
        return await nextcloudService.getDirectDownload(metadata: metadata)
    }
    
    // MARK: -
    // MARK: Search
    @MainActor
    func searchMedia(type: Global.FilterType, toDate: Date, fromDate: Date, offsetDate: Date?, offsetName: String?, limit: Int) async -> (metadatas: [Metadata], added: [Metadata], updated: [Metadata], deleted: [Metadata], error: Bool) {
        
        guard let account = Environment.current.currentUser?.account else { return ([], [], [], [], true) }
        guard let mediaPath = await getMediaPath() else { return ([], [], [], [], true) }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return ([], [], [], [], true) }
        
        let searchResult = await nextcloudService.searchMedia(account: account, mediaPath: mediaPath,
                                                              toDate: toDate, fromDate: fromDate, limit: limit)

        if searchResult.error {
            return ([], [], [], [], true)
        }
        
        //get stored metadata
        let metadatasResult = await databaseManager.getMetadatas(account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        
        //add, update, delete stored metadata
        let result = await databaseManager.processMetadatas(searchResult.files, metadatasResult: metadatasResult)

        let typeResult = filterMediaResult(type: type, result: result)
        
        let metadatas: [Metadata]

        if limit == 0 {
            metadatas = await databaseManager.fetchMetadata(favorite: false, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        } else {
            metadatas = await databaseManager.paginateMetadata(favorite: false, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate, offsetDate: offsetDate, offsetName: offsetName)
        }
        
        //Self.logger.debug("searchMedia() - count: \(metadatas.count) added: \(typeResult.added.count) updated: \(typeResult.updated.count) deleted: \(typeResult.deleted.count)")
        return (metadatas, typeResult.added, typeResult.updated, typeResult.deleted, false)
    }
    
    private func filterMediaResult(type: Global.FilterType, result: (added: [Metadata], updated: [Metadata], deleted: [Metadata])) -> (added: [Metadata], updated: [Metadata], deleted: [Metadata]){
        return (added: filterMetadataByType(type: type, metadataCollection: result.added),
                updated: filterMetadataByType(type: type, metadataCollection: result.updated),
                deleted: filterMetadataByType(type: type, metadataCollection: result.deleted))
    }
    
    private func filterMetadataByType(type: Global.FilterType, metadataCollection: [Metadata]) -> [Metadata] {
        
        if type == .all {
            return metadataCollection
        } else {
            return metadataCollection.filter {
                switch type {
                case .image:
                    return $0.image
                case .video:
                    return $0.video && $0.livePhotoFile == ""
                default:
                    return false
                }
            }
        }
    }
    
    private func getMediaPath() async -> String? {
        //guard let activeAccount = await getActiveAccount() else { return nil }
        return "" //activeAccount.mediaPath //TODO: This is always empty. Changing mediaPath locally is not implemented
    }
    
    @MainActor
    private func getStartServerUrl(mediaPath: String?) -> String? {

        guard mediaPath != nil else { return nil }
        
        let urlBase = Environment.current.currentUser?.urlBase
        let userId = Environment.current.currentUser?.userId
        
        guard urlBase != nil && userId != nil else { return nil }
        
        let startServerUrl = urlBase! + Global.shared.davLocation + userId! + mediaPath!
        
        return startServerUrl
    }
    
    
    // MARK: -
    // MARK: Profile
    func getUserProfile(account: String) async -> (profileDisplayName: String, profileEmail: String) {
        return await nextcloudService.getUserProfile(account: account)
    }
    
    
    // MARK: -
    // MARK: Settings
    func saveDisplayStyle(style: UIUserInterfaceStyle?) {
        store.setDisplayStyle(style: style)
    }
    
    func getDisplayStyle() -> UIUserInterfaceStyle? {
        return store.getDisplayStyle()
    }
}
