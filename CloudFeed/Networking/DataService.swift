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
        NextcloudKit.shared.nkCommonInstance.levelLog = 0
    }
    
    func setup(account: String) {
        
        Task { [weak self] in
            guard let self else { return }
            
            let (account, data) = await nextcloudService.getCapabilities(account: account)
            guard account != nil && data != nil else { return }
            databaseManager.addCapabilitiesJSon(account: account!, data: data!)
        }
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
    
    func appendSession(userAccount: UserAccount) {
        
        let password = store.getPassword(userAccount.account) ?? ""
        let serverVersionMajor = databaseManager.getCapabilitiesServerInt(account: userAccount.account, elements: Global.shared.capabilitiesVersionMajor)
        
        nextcloudService.appendSession(account: userAccount.account, urlBase: userAccount.urlBase, user: userAccount.user, userId: userAccount.userId,
                                       password: password, userAgent: Global.shared.userAgent, nextcloudVersion: serverVersionMajor,
                                       groupIdentifier: Global.shared.groupIdentifier)
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
    func getActiveAccount() -> tableAccount? {
        return databaseManager.getActiveAccount()
    }
    
    func setActiveAccount(_ account: String) -> tableAccount? {
        return databaseManager.setActiveAccount(account)
    }
    
    func getAccounts() -> [String]? {
        return databaseManager.getAccounts()
    }
    
    func deleteAccount(_ account: String) {
        databaseManager.deleteAccount(account)
    }
    
    func addAccount(_ account: String, urlBase: String, user: String, password: String) {
        databaseManager.addAccount(account, urlBase: urlBase, user: user, password: password)
        store.setPassword(account, password: password)
    }
    
    
    // MARK: -
    // MARK: Database Management
    func clearDatabase(account: String?, removeAccount: Bool) {
        databaseManager.clearDatabase(account: account, removeAccount: removeAccount)
    }
    
    func removeDatabase() {
        databaseManager.removeDatabase()
    }
    
    
    // MARK: -
    // MARK: Metadata
    func getMetadata(predicate: NSPredicate) -> Metadata? {
        return databaseManager.getMetadata(predicate: predicate)
    }
    
    func getMetadata(account: String, startServerUrl: String) -> Metadata? {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@)", account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)
        
        return databaseManager.getMetadata(predicate: predicate, sorted: "date", ascending: true)
    }
    
    func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> Metadata? {
        return databaseManager.getMetadata(predicate: predicate, sorted: sorted, ascending: ascending)
    }
    
    func getMetadataFromOcId(_ ocId: String?) -> Metadata? {
        return databaseManager.getMetadataFromOcId(ocId)
    }
    
    func getMetadataLivePhoto(metadata: Metadata) -> Metadata? {
        return databaseManager.getMetadataLivePhoto(metadata: metadata)
    }
    
    
    // MARK: -
    // MARK: Avatar
    @MainActor
    func downloadAvatar(fileName: String, account: tableAccount) async {
        
        let fileNameLocalPath = store.getUserDirectory() + "/" + fileName
        
        guard !FileManager.default.fileExists(atPath: fileNameLocalPath) else {
            return
        }
        
        let etag = databaseManager.getAvatar(fileName: fileName)?.etag
        
        let avatarSize = Global.shared.avatarSizeBase * Int(UIScreen.main.scale)
        
        let etagResult = await nextcloudService.downloadAvatar(account: account.account, userId: account.userId, fileName: fileName,
                                                               fileNameLocalPath: fileNameLocalPath, etag: etag, avatarSize: avatarSize, avatarSizeRounded: Global.shared.avatarSizeRounded)
        
        guard etagResult != nil else { return }
        databaseManager.addAvatar(fileName: fileName, etag: etagResult!)
    }
    
    
    // MARK: -
    // MARK: Favorites
    func toggleFavoriteMetadata(_ metadata: Metadata) async -> Metadata? {
        
        if let metadataLive = databaseManager.getMetadataLivePhoto(metadata: metadata) {
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
            return databaseManager.setMetadataFavorite(ocId: ocId, favorite: favorite)
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
        let listingResult = await nextcloudService.listingFavorites(account: account)
        
        guard listingResult.files != nil else { return true }
        
        databaseManager.updateMetadatasFavorite(account: listingResult.account, metadatas: listingResult.files!)
        
        return false
    }
    
    @MainActor
    func paginateFavoriteMetadata(type: Global.FilterType, fromDate: Date, toDate: Date, offsetDate: Date?, offsetName: String?) -> [Metadata] {
        
        guard let account = Environment.current.currentUser?.account else { return [] }
        guard let mediaPath = getMediaPath() else { return [] }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return [] }
        
        let predicate = buildMediaPredicateByType(favorite: true, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        
        return databaseManager.paginateMetadata(predicate: predicate, offsetDate: offsetDate, offsetName: offsetName)
    }
    
    @MainActor
    func processFavorites(displayedMetadataIds: [Metadata.ID], displayedMetadatas: [Metadata.ID: Metadata], type: Global.FilterType, from: Date?, to: Date?) -> (delete: [Metadata.ID], add: [Metadata], update: [Metadata])? {

        guard let account = Environment.current.currentUser?.account else { return nil }
        guard let mediaPath = getMediaPath() else { return nil }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return nil }

        var delete: [Metadata.ID] = []
        var add: [Metadata] = []
        var update: [Metadata] = []
        var savedFavorites: [Metadata] = []

        let predicate = buildMediaPredicateByType(favorite: true, type: type, account: account, startServerUrl: startServerUrl, fromDate: from ?? Date.distantPast, toDate: to ?? Date.distantFuture)
        
        savedFavorites = databaseManager.paginateMetadata(predicate: predicate, offsetDate: nil, offsetName: nil)
        
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
    func download(metadata: Metadata, selector: String) async {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = store.getCachePath(metadata.ocId, metadata.fileName)!
        
        if databaseManager.getMetadataFromOcId(metadata.ocId) == nil {
            databaseManager.addMetadata(metadata)
        }
        
        let error = await nextcloudService.download(metadata: metadata, selector: selector,
                                                          serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath)
        
        if error == false {
            databaseManager.addLocalFile(metadata: metadata)
        }
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
                                                             previewWidth: metadata.width, previewHeight: metadata.height, iconPath: iconPath, 
                                                             etagResource: etagResource) {
            databaseManager.setMetadataEtagResource(ocId: metadata.ocId, etagResource: etag)
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
        guard let mediaPath = getMediaPath() else { return ([], [], [], [], true) }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return ([], [], [], [], true) }
        
        let searchResult = await nextcloudService.searchMedia(account: account, mediaPath: mediaPath,
                                                              toDate: toDate, fromDate: fromDate, limit: limit)

        if searchResult.error {
            return ([], [], [], [], true)
        }
        
        //convert to metadata
        //let metadataCollection = searchResult.files.count == 0 ? [] : databaseManager.convertFilesToMetadatas(searchResult.files)
        let metadataCollection = searchResult.files
        
        //get stored metadata
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND date >= %@ AND date <= %@",
                                    account, startServerUrl,
                                    NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue,
                                    fromDate as NSDate, toDate as NSDate)
        
        let metadatasResult = databaseManager.getMetadatas(predicate: predicate)
        
        //add, update, delete stored metadata
        let result = databaseManager.processMetadatas(metadataCollection, metadatasResult: metadatasResult)

        let typeResult = filterMediaResult(type: type, result: result)
        
        let storePredicate = buildMediaPredicateByType(favorite: false, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        
        let metadatas: [Metadata]

        if limit == 0 {
            metadatas = databaseManager.fetchMetadata(predicate: storePredicate)
        } else {
            metadatas = databaseManager.paginateMetadata(predicate: storePredicate, offsetDate: offsetDate, offsetName: offsetName)
        }
        
        //Self.logger.debug("searchMedia() - count: \(metadatas.count) added: \(typeResult.added.count) updated: \(typeResult.updated.count) deleted: \(typeResult.deleted.count)")
        return (metadatas, typeResult.added, typeResult.updated, typeResult.deleted, false)
    }
    
    private func filterMediaResult(type: Global.FilterType, result: (added: [Metadata], updated: [Metadata], deleted: [Metadata])) -> (added: [Metadata], updated: [Metadata], deleted: [Metadata]){
        return (added: filterMetadataByType(type: type, metadataCollection: result.added),
                updated: filterMetadataByType(type: type, metadataCollection: result.updated),
                deleted: filterMetadataByType(type: type, metadataCollection: result.deleted))
    }
    
    private func buildMediaPredicateByType(favorite: Bool, type: Global.FilterType, account: String, startServerUrl: String, fromDate: Date, toDate: Date) -> NSPredicate {
        
        let favoriteFormat = favorite ? "favorite == true AND " : ""
        
        switch type {
        case .all:
            //filter out videos of the live photo file pair
            return NSPredicate(format: favoriteFormat + "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND date >= %@ AND date <= %@ AND ((classFile = %@ AND livePhotoFile != '') OR livePhotoFile == '')",
                               account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue,
                               fromDate as NSDate, toDate as NSDate, NKCommon.TypeClassFile.image.rawValue)
        case .image:
            return NSPredicate(format: favoriteFormat + "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND date >= %@ AND date <= %@",
                               account, startServerUrl, NKCommon.TypeClassFile.image.rawValue,
                               fromDate as NSDate, toDate as NSDate)
        case .video:
            return NSPredicate(format: favoriteFormat + "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND date >= %@ AND date <= %@ AND livePhotoFile == ''",
                               account, startServerUrl, NKCommon.TypeClassFile.video.rawValue,
                               fromDate as NSDate, toDate as NSDate)
        }
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
    
    private func getMediaPath() -> String? {
        guard let activeAccount = getActiveAccount() else { return nil }
        return activeAccount.mediaPath
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
    @MainActor
    func getUserProfile() async -> (profileDisplayName: String, profileEmail: String) {
        guard let account = Environment.current.currentUser?.account else { return ("", "") }
        return await nextcloudService.getUserProfile(account: account)
    }

}
