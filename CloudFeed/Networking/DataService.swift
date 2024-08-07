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
import NextcloudKit
import UIKit

class DataService: NSObject {
    
    let store = StoreUtility()
    
    private let nextcloudService: NextcloudKitServiceProtocol
    private let databaseManager: DatabaseManager
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DataService.self)
    )
    
    init(nextcloudService: NextcloudKitServiceProtocol, databaseManager: DatabaseManager) {
        self.nextcloudService = nextcloudService
        self.databaseManager = databaseManager
    }
    
    func setup(account: String, user: String, userId: String, urlBase: String) {
        
        let password = store.getPassword(account)
        
        nextcloudService.setupAccount(account: account, user: user, userId: userId, password: password!, urlBase: urlBase)

        NextcloudKit.shared.nkCommonInstance.levelLog = 0
        
        let serverVersionMajor = databaseManager.getCapabilitiesServerInt(account: account, elements: Global.shared.capabilitiesVersionMajor)
        if serverVersionMajor > 0 {
            nextcloudService.setupVersion(serverVersionMajor: serverVersionMajor)
        }
        
        Task { [weak self] in
            guard let self else { return }
            
            let (account, data) = await nextcloudService.getCapabilities()
            guard account != nil && data != nil else { return }
            databaseManager.addCapabilitiesJSon(account: account!, data: data!)
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
    func getMetadata(predicate: NSPredicate) -> tableMetadata? {
        return databaseManager.getMetadata(predicate: predicate)
    }
    
    func getMetadata(account: String, startServerUrl: String) -> tableMetadata? {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@)", account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)
        
        return databaseManager.getMetadata(predicate: predicate, sorted: "date", ascending: true)
    }
    
    func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> tableMetadata? {
        return databaseManager.getMetadata(predicate: predicate, sorted: sorted, ascending: ascending)
    }
    
    func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        return databaseManager.getMetadataFromOcId(ocId)
    }
    
    func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {
        return databaseManager.getMetadataLivePhoto(metadata: metadata)
    }
    
    
    // MARK: -
    // MARK: Avatar
    func getAvatarImage(fileName: String) -> UIImage? {
        return databaseManager.getAvatarImage(fileName: fileName)
    }
    
    func downloadAvatar(fileName: String, account: tableAccount) async {
        
        let fileNameLocalPath = store.getUserDirectory() + "/" + fileName
        
        guard !FileManager.default.fileExists(atPath: fileNameLocalPath) else {
            return
        }
        
        let etag = databaseManager.getAvatar(fileName: fileName)?.etag
        
        let etagResult = await nextcloudService.downloadAvatar(userId: account.userId, fileName: fileName, fileNameLocalPath: fileNameLocalPath, etag: etag)
        
        guard etagResult != nil else { return }
        databaseManager.addAvatar(fileName: fileName, etag: etagResult!)
    }
    
    
    // MARK: -
    // MARK: Favorites
    func toggleFavoriteMetadata(_ metadata: tableMetadata) async -> tableMetadata? {
        
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
    
    private func toggleFavorite(metadata: tableMetadata) async -> tableMetadata? {
        
        let fileName = buildFileNamePath(metadataFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)
        let favorite = !metadata.favorite
        let ocId = metadata.ocId
        
        let error = await nextcloudService.setFavorite(fileName: fileName, favorite: favorite, ocId: ocId, account: metadata.account)
        
        if error == .success {
            return databaseManager.setMetadataFavorite(ocId: ocId, favorite: favorite)
        }
        
        return nil
    }
    
    private func buildFileNamePath(metadataFileName: String, serverUrl: String, urlBase: String, userId: String, account: String) -> String {
        
        let homeServer = urlBase + Global.shared.davLocation + userId
        
        var fileName = "\(serverUrl.replacingOccurrences(of: homeServer, with: ""))/\(metadataFileName)"

        if fileName.hasPrefix("/") {
            fileName = (fileName as NSString).substring(from: 1)
        }
        
        return fileName
    }
    
    func getFavorites() async -> Bool {
        
        let listingResult = await nextcloudService.listingFavorites()
        
        guard listingResult.files != nil else { return true }
        
        let convertResult = await databaseManager.convertFilesToMetadatas(listingResult.files!)
        databaseManager.updateMetadatasFavorite(account: listingResult.account, metadatas: convertResult)
        
        return false
    }
    
    func paginateFavoriteMetadata(type: Global.FilterType, fromDate: Date, toDate: Date, offsetDate: Date?, offsetName: String?) -> [tableMetadata] {
        
        guard let account = Environment.current.currentUser?.account else { return [] }
        guard let mediaPath = getMediaPath() else { return [] }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return [] }
        
        let predicate = buildMediaPredicateByType(favorite: true, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        
        return databaseManager.paginateMetadata(predicate: predicate, offsetDate: offsetDate, offsetName: offsetName)
    }
    
    func processFavorites(displayedMetadatas: [tableMetadata], type: Global.FilterType, from: Date?, to: Date?) -> (delete: [tableMetadata], add: [tableMetadata])? {
        
        guard let account = Environment.current.currentUser?.account else { return nil }
        guard let mediaPath = getMediaPath() else { return nil }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return nil }

        var delete: [tableMetadata] = []
        var add: [tableMetadata] = []
        var savedFavorites: [tableMetadata] = []

        let predicate = buildMediaPredicateByType(favorite: true, type: type, account: account, startServerUrl: startServerUrl, fromDate: from ?? Date.distantPast, toDate: to ?? Date.distantFuture)
        
        savedFavorites = databaseManager.paginateMetadata(predicate: predicate, offsetDate: nil, offsetName: nil)
        
        //Self.logger.debug("processFavorites() - savedFavorites count: \(savedFavorites.count) displayedMetadatas count: \(displayedMetadatas.count)")
        
        //if displayed but doesn't exist in db, flag for delete
        for displayedMetadata in displayedMetadatas {
            if savedFavorites.firstIndex(where: { $0.ocId == displayedMetadata.ocId }) == nil {
                delete.append(displayedMetadata)
            }
        }
        
        //if exists in db, but is not displayed, flag for add
        for saved in savedFavorites {
            if displayedMetadatas.firstIndex(where: { $0.ocId == saved.ocId }) == nil {
                add.append(saved)
            }
        }
        
        //Self.logger.debug("processFavorites() - add: \(add.count) delete: \(delete.count)")
        
        return (delete, add)
    }

    
    // MARK: -
    // MARK: Download
    func download(metadata: tableMetadata, selector: String) async {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = store.getCachePath(metadata.ocId, metadata.fileName)!
        
        if databaseManager.getMetadataFromOcId(metadata.ocId) == nil {
            databaseManager.addMetadata(tableMetadata.init(value: metadata))
        }
        
        let errorResult = await nextcloudService.download(metadata: metadata, selector: selector,
                                                          serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath)
        
        if errorResult == .success {
            databaseManager.addLocalFile(metadata: metadata)
        }
    }
    
    func downloadPreview(metadata: tableMetadata) async {
       
        var previewPath: String
        var iconPath: String
        
        previewPath = store.getPreviewPath(metadata.ocId, metadata.etag)
        iconPath = store.getIconPath(metadata.ocId, metadata.etag)
        
        var etagResource: String?
        if FileManager.default.fileExists(atPath: iconPath) {
            etagResource = metadata.etagResource
        }
        
        await nextcloudService.downloadPreview(fileId: metadata.fileId, previewPath: previewPath, previewWidth: metadata.width, previewHeight: metadata.height, iconPath: iconPath, etagResource: etagResource)
    }
    
    func downloadVideoPreview(metadata: tableMetadata) async {
            
        if metadata.video && !FileManager().fileExists(atPath: store.getIconPath(metadata.ocId, metadata.etag)) {
            
            if let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                
                let url = HTTPCache.shared.getProxyURL(stringURL: stringURL)
                let image = await ImageUtility.imageFromVideo(url: url)
                let path = store.getIconPath(metadata.ocId, metadata.etag)
                
                //Save the preview image
                try? image?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: path))
            }
        }
    }
    
    // MARK: -
    // MARK: Search
    func searchMedia(type: Global.FilterType, toDate: Date, fromDate: Date, offsetDate: Date?, offsetName: String?, limit: Int) async -> (metadatas: [tableMetadata], added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata], error: Bool) {
        
        guard let account = Environment.current.currentUser?.account else { return ([], [], [], [], true) }
        guard let mediaPath = getMediaPath() else { return ([], [], [], [], true) }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return ([], [], [], [], true) }
        
        let searchResult = await nextcloudService.searchMedia(account: account, mediaPath: mediaPath,
                                                              toDate: toDate, fromDate: fromDate, limit: limit)

        if searchResult.error {
            return ([], [], [], [], true)
        }
        
        //convert to metadata
        let metadataCollection = searchResult.files.count == 0 ? [] : await databaseManager.convertFilesToMetadatas(searchResult.files)
        
        //get stored metadata
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND date >= %@ AND date <= %@",
                                    account, startServerUrl,
                                    NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue,
                                    fromDate as NSDate, toDate as NSDate)
        
        let metadatasResult = databaseManager.getMetadatas(predicate: predicate)
        
        //add, update, delete stored metadata
        let result = databaseManager.processMetadatas(metadataCollection, metadatasResult: metadatasResult)
        let typeResult = type == .all ? result : filterMediaResult(type: type, result: result)
        
        let storePredicate = buildMediaPredicateByType(favorite: false, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        
        let metadatas: [tableMetadata]

        if limit == 0 {
            metadatas = databaseManager.fetchMetadata(predicate: storePredicate)
        } else {
            metadatas = databaseManager.paginateMetadata(predicate: storePredicate, offsetDate: offsetDate, offsetName: offsetName)
        }
        
        //Self.logger.debug("searchMedia() - count: \(metadatas.count) added: \(typeResult.added.count) updated: \(typeResult.updated.count) deleted: \(typeResult.deleted.count)")
        return (metadatas, typeResult.added, typeResult.updated, typeResult.deleted, false)
    }
    
    private func filterMediaResult(type: Global.FilterType, result: (added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata])) -> (added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata]){
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
    
    private func filterMetadataByType(type: Global.FilterType, metadataCollection: [tableMetadata]) -> [tableMetadata] {
        
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
    func getUserProfile() async -> (profileDisplayName: String, profileEmail: String) {
        return await nextcloudService.getUserProfile()
    }

}
