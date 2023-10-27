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
        //NKCommon.shared.levelLog = 1
        NextcloudKit.shared.nkCommonInstance.levelLog = 0
        
        let serverVersionMajor = databaseManager.getCapabilitiesServerInt(account: account, elements: Global.shared.capabilitiesVersionMajor)
        if serverVersionMajor > 0 {
            nextcloudService.setupVersion(serverVersionMajor: serverVersionMajor)
        }
        
        Task {
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
    func favoriteMetadata(_ metadata: tableMetadata) async -> NKError {
        
        if let metadataLive = databaseManager.getMetadataLivePhoto(metadata: metadata) {
            let error = await setFavorite(metadata: metadataLive)
            if error == .success {
                return await setFavorite(metadata: metadata)
            } else {
                return error
            }
        } else {
            return await setFavorite(metadata: metadata)
        }
    }
    
    private func setFavorite(metadata: tableMetadata) async -> NKError {
        let fileName = StoreUtility.returnFileNamePath(metadataFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)
        let favorite = !metadata.favorite
        let ocId = metadata.ocId
        
        let error = await nextcloudService.setFavorite(fileName: fileName, favorite: favorite, ocId: ocId, account: metadata.account)
        
        if error == .success {
            databaseManager.setMetadataFavorite(ocId: ocId, favorite: favorite)
        }
        
        return error
    }
    
    func getFavorites() async -> Bool {
        
        let listingResult = await nextcloudService.listingFavorites()
        
        /*for file in listingResult.files! {
            print("-------------------------!!")
            print(Mirror(reflecting: file).children.compactMap { "\($0.label ?? "Unknown Label"): \($0.value)" }.joined(separator: "\n"))
        }*/
        
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
    
    func processFavorites(displayedMetadatas: [tableMetadata]) -> [tableMetadata] {
        
        let savedMetadatas = paginateFavoriteMetadata(offsetDate: nil, offsetName: nil)
        var delete: [tableMetadata] = []
        
        Self.logger.debug("savedMetadatas count: \(savedMetadatas.count) displayedMetadatas count: \(displayedMetadatas.count)")
        
        for displayedMetadata in displayedMetadatas {
            if savedMetadatas.firstIndex(where: { $0.ocId == displayedMetadata.ocId }) == nil {
                delete.append(displayedMetadata)
            }
        }
        
        return delete
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
        
        fileNamePath = StoreUtility.returnFileNamePath(metadataFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)
        fileNamePreviewLocalPath = StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        fileNameIconLocalPath = StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
        
        Self.logger.debug("downloadPreview() - ocId: \(metadata.ocId)")
        
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
                
                Self.logger.debug("downloadVideoPreview() - ocId: \(metadata.ocId)")
                
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
        
        let account = Environment.current.currentUser?.account
        guard account != nil else { return [] }
        
        let mediaPath = getMediaPath()
        guard mediaPath != nil else { return [] }
        
        let startServerUrl = getStartServerUrl(mediaPath: mediaPath)
        guard startServerUrl != nil else { return [] }
        
        return databaseManager.paginateMetadata(account: account!, startServerUrl: startServerUrl!, fromDate: fromDate, toDate: toDate,
                                                offsetDate: offsetDate, offsetName: offsetName)
    }
    
    func searchMedia(toDate: Date, fromDate: Date, limit: Int) async -> (metadatas: [tableMetadata], deleteOcIds: [String], error: Bool) {
        
        let account = Environment.current.currentUser?.account
        guard account != nil else { return ([], [], true) }
        
        let mediaPath = getMediaPath()
        guard mediaPath != nil else { return ([], [], true) }
        
        let startServerUrl = getStartServerUrl(mediaPath: mediaPath)        
        guard startServerUrl != nil else { return ([], [], true) }
        
        //remote search
        let searchResult = await nextcloudService.searchMedia(account: account!, mediaPath: mediaPath!, toDate: toDate, fromDate: fromDate, limit: limit)
        
        if searchResult.files.count == 0 {
            return ([], [], searchResult.error)
        }
        
        /*for file in searchResult.files {
            Self.logger.debug("searchMedia() - ")
            Self.logger.debug("account:  \(file.account)")
            Self.logger.debug("ocId:  \(file.ocId)")
            Self.logger.debug("name:  \(file.fileName)")
            Self.logger.debug("date:  \(file.date)")
            Self.logger.debug("serverUrl:  \(file.serverUrl)")
            Self.logger.debug("classFile:  \(file.classFile)")
        }*/
        
        //convert to metadata
        let metadataCollection = await databaseManager.convertFilesToMetadatas(searchResult.files)
        
        Self.logger.debug("searchMedia() - count: \(metadataCollection.metadatas.count)")
        
        //get currently stored metadata
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND date >= %@ AND date <= %@",
                                    account!, startServerUrl!,
                                    NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue,
                                    fromDate as NSDate, toDate as NSDate)
        
        let metadatasResult = databaseManager.getMetadatas(predicate: predicate)
        
        Self.logger.debug("searchMedia() - account: \(account!)")
        Self.logger.debug("searchMedia() - startServerUrl: \(startServerUrl!)")
        Self.logger.debug("searchMedia() - toDate:  \(toDate.formatted(date: .abbreviated, time: .standard))")
        Self.logger.debug("searchMedia() - fromDate:  \(fromDate.formatted(date: .abbreviated, time: .standard))")
        
        
        /*Self.logger.debug("searchMedia() ----------------------------------")
        for metadata in metadataCollection.metadatas {
            Self.logger.debug("searchMedia() - date:  \((metadata.date as Date).formatted(date: .abbreviated, time: .standard)) name: \(metadata.fileNameView)")
        }
        Self.logger.debug("searchMedia() ----------------------------------")
        for metadata in metadatasResult {
            Self.logger.debug("searchMedia() - date:  \((metadata.date as Date).formatted(date: .abbreviated, time: .standard)) name: \(metadata.fileNameView)")
        }*/
        
        //add, update, delete stored metadata
        let deleteOcIds = databaseManager.processMetadatas(metadataCollection.metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
        
        let metadataPredicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@)", account!, startServerUrl!, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)
        
        //flag stored live photo files
        databaseManager.processMetadatasMedia(predicate: metadataPredicate)
        
        //filter out videos of the live photo file pair
        let pagePredicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND date >= %@ AND date <= %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false)", account!, startServerUrl!, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue, fromDate as NSDate, toDate as NSDate, NKCommon.TypeClassFile.image.rawValue)
        let metadatas = databaseManager.getMetadatasMediaPage(predicate: pagePredicate)
        
        return (metadatas, deleteOcIds, false)
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
        
        let startServerUrl = urlBase! + "/remote.php/dav/files/" + userId! + mediaPath!
        
        return startServerUrl
    }
    
    
    // MARK: -
    // MARK: Profile
    func getUserProfile() async -> (profileDisplayName: String, profileEmail: String) {
        return await nextcloudService.getUserProfile()
    }

}
