//
//  DataService.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/1/23.
//
import Alamofire
import os.log
import NextcloudKit
import UIKit

class DataService: NSObject {
    
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
    
    func setup(account: String, user: String, userId: String, password: String, urlBase: String) {
        
        nextcloudService.setupAccount(account: account, user: user, userId: userId, password: password, urlBase: urlBase)

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
    
    func downloadAvatar(user: String, account: tableAccount) async {
        
        let userBaseUrl = NextcloudUtility.shared.getUserBaseUrl(account)
        let fileName = userBaseUrl + "-" + user + ".png"
        let fileNameLocalPath = String(StoreUtility.getDirectoryUserData()) + "/" + fileName
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
        
        let fileName = StoreUtility.buildFileNamePath(metadataFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)
        let favorite = !metadata.favorite
        let ocId = metadata.ocId
        
        let error = await nextcloudService.setFavorite(fileName: fileName, favorite: favorite, ocId: ocId, account: metadata.account)
        
        if error == .success {
            return databaseManager.setMetadataFavorite(ocId: ocId, favorite: favorite)
        }
        
        return nil
    }
    
    func getFavorites() async -> Bool {
        
        let listingResult = await nextcloudService.listingFavorites()
        
        guard listingResult.files != nil else { return true }
        
        let convertResult = await databaseManager.convertFilesToMetadatas(listingResult.files!)
        databaseManager.updateMetadatasFavorite(account: listingResult.account, metadatas: convertResult.metadatas)
        
        return false
    }
    
    func paginateFavoriteMetadata(offsetDate: Date?, offsetName: String?) -> [tableMetadata] {
        
        let account = Environment.current.currentUser?.account
        guard account != nil else { return [] }
        
        let mediaPath = getMediaPath()
        guard mediaPath != nil else { return [] }
        
        let startServerUrl = getStartServerUrl(mediaPath: mediaPath)
        guard startServerUrl != nil else { return [] }
        
        return databaseManager.paginateFavoriteMetadata(account: account!, startServerUrl: startServerUrl!, offsetDate: offsetDate, offsetName: offsetName)
    }
    
    func processFavorites(displayedMetadatas: [tableMetadata]) -> (delete: [tableMetadata], add: [tableMetadata])? {
        
        guard let account = Environment.current.currentUser?.account else { return nil }
        guard let mediaPath = getMediaPath() else { return nil }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return nil }
        guard let fromDate = displayedMetadatas.last?.date as? Date else { return nil }
        
        var delete: [tableMetadata] = []
        var add: [tableMetadata] = []

        let savedMetadatas = databaseManager.fetchFavoriteMetadata(account: account, startServerUrl: startServerUrl,
                                              fromDate: fromDate, toDate: Date.now)
        
        //Self.logger.debug("processFavorites() - fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
        //Self.logger.debug("processFavorites() - savedMetadatas count: \(savedMetadatas.count) displayedMetadatas count: \(displayedMetadatas.count)")
        
        //if displayed but doesn't exist in db, flag for delete
        for displayedMetadata in displayedMetadatas {
            if savedMetadatas.firstIndex(where: { $0.ocId == displayedMetadata.ocId }) == nil {
                delete.append(displayedMetadata)
            }
        }
        
        //if exists in db, but is not displayed, flag for add
        for savedMetadata in savedMetadatas {
            if displayedMetadatas.firstIndex(where: { $0.ocId == savedMetadata.ocId }) == nil {
                add.append(savedMetadata)
            }
        }
        
        return (delete, add)
    }

    
    // MARK: -
    // MARK: Download
    func download(metadata: tableMetadata, selector: String) async {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
        
        if databaseManager.getMetadataFromOcId(metadata.ocId) == nil {
            databaseManager.addMetadata(tableMetadata.init(value: metadata))
        }
        
        let errorResult = await nextcloudService.download(metadata: metadata, selector: selector,
                                                          serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath)
        
        if errorResult == .success {
            databaseManager.addLocalFile(metadata: metadata)
            StoreUtility.setExif(metadata) { _ in }
        }
    }
    
    func downloadPreview(metadata: tableMetadata) async {
       
        var fileNamePath: String
        var fileNamePreviewLocalPath: String
        var fileNameIconLocalPath: String
        
        fileNamePath = StoreUtility.buildFileNamePath(metadataFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)
        fileNamePreviewLocalPath = StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        fileNameIconLocalPath = StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
        
        var etagResource: String?
        if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
            etagResource = metadata.etagResource
        }
        
        await nextcloudService.downloadPreview(fileNamePath: fileNamePath, fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                                               fileNameIconLocalPath: fileNameIconLocalPath, etagResource: etagResource)
    }
    
    func downloadVideoPreview(metadata: tableMetadata) async {
        
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue
            && !FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            
            if let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                
                let url = HTTPCache.shared.getProxyURL(stringURL: stringURL)
                let image = NextcloudUtility.shared.imageFromVideo(url: url, at: 1)
                
                let fileNamePathIcon = StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
                
                //Save the preview image
                try? image?.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: fileNamePathIcon))
            }
        }
    }
    
    // MARK: -
    // MARK: Search
    func paginateMetadata(fromDate: Date, toDate: Date, offsetDate: Date?, offsetName: String?) -> [tableMetadata] {
        
        guard let account = Environment.current.currentUser?.account else { return [] }
        guard let mediaPath = getMediaPath() else { return [] }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return [] }
        
        return databaseManager.paginateMetadata(account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate,
                                                offsetDate: offsetDate, offsetName: offsetName)
    }
    
    func searchMedia(toDate: Date, fromDate: Date, limit: Int) async -> (metadatas: [tableMetadata], added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata], error: Bool) {
        
        guard let account = Environment.current.currentUser?.account else { return ([], [], [], [], true) }
        guard let mediaPath = getMediaPath() else { return ([], [], [], [], true) }
        guard let startServerUrl = getStartServerUrl(mediaPath: mediaPath) else { return ([], [], [], [], true) }
        
        //remote search
        let searchResult = await nextcloudService.searchMedia(account: account, mediaPath: mediaPath, 
                                                              toDate: toDate, fromDate: fromDate, limit: limit)
        
        if searchResult.files.count == 0 {
            return ([], [], [], [], searchResult.error)
        }
        
        //convert to metadata
        let metadataCollection = await databaseManager.convertFilesToMetadatas(searchResult.files)
        
        //get currently stored metadata
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND date >= %@ AND date <= %@",
                                    account, startServerUrl,
                                    NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue,
                                    fromDate as NSDate, toDate as NSDate)
        
        let metadatasResult = databaseManager.getMetadatas(predicate: predicate)
        
        //add, update, delete stored metadata
        let processResult = databaseManager.processMetadatas(metadataCollection.metadatas, metadatasResult: metadatasResult)
        
        let metadataPredicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@)", account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)
        
        //flag stored live photo files
        databaseManager.processMetadatasMedia(predicate: metadataPredicate)
        
        //filter out videos of the live photo file pair
        let pagePredicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND date >= %@ AND date <= %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false)", account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue, fromDate as NSDate, toDate as NSDate, NKCommon.TypeClassFile.image.rawValue)
        let metadatas = databaseManager.getMetadatasMediaPage(predicate: pagePredicate)
    
        return (metadatas, processResult.added, processResult.updated, processResult.deleted, false)
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