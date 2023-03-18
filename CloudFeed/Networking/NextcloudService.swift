//
//  NextcloudService.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/13/23.
//

import UIKit
import NextcloudKit
import os.log

class NextcloudService: NSObject {
    
    static let shared: NextcloudService = {
        let instance = NextcloudService()
        return instance
    }()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: NextcloudService.self)
    )
    
    func initService(account: String, urlBase: String, user: String, userId: String, password: String) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        guard !appDelegate.account.isEmpty else { return }
        
        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: urlBase)

        let serverVersionMajor = DatabaseManager.shared.getCapabilitiesServerInt(account: account, elements: Global.shared.capabilitiesVersionMajor)
        if serverVersionMajor > 0 {
            NextcloudKit.shared.setup(nextcloudVersion: serverVersionMajor)
        }
        
        let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)

        NextcloudKit.shared.getCapabilities(options: options) { account, data, error in
            guard error == .success, let data = data else { return }
            DatabaseManager.shared.addCapabilitiesJSon(data, account: account)
        }
    }

    func downloadPreview(metadata: tableMetadata) async -> (image: UIImage?, etag: String?) {
        
        var fileNamePath: String
        var fileNamePreviewLocalPath: String
        var fileNameIconLocalPath: String
        
        fileNamePath = StoreUtility.returnFileNamePath(metadataFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)
        fileNamePreviewLocalPath = StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        fileNameIconLocalPath = StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
        
        Self.logger.debug("downloadPreview()------")
        Self.logger.debug("fileNamePath = \(fileNamePath)")
        Self.logger.debug("fileNamePreviewLocalPath = \(fileNamePreviewLocalPath)")
        Self.logger.debug("fileNameIconLocalPath = \(fileNameIconLocalPath)")
        Self.logger.debug("-----------------------")
        
        var etagResource: String?
        if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
            etagResource = metadata.etagResource
        }
        
        let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)

        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.downloadPreview(
                fileNamePathOrFileId: fileNamePath,
                fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                widthPreview: Global.shared.sizePreview,
                heightPreview: Global.shared.sizePreview,
                fileNameIconLocalPath: fileNameIconLocalPath,
                sizeIcon: Global.shared.sizeIcon,
                etag: etagResource,
                options: options) { _, _, imageIcon, _, etag, error in
                    
                    if error == .success, let imageIcon = imageIcon {
                        Self.logger.debug("downloadPreview() - SUCCESS image size: \(imageIcon.size.width), \(imageIcon.size.height)")
                        continuation.resume(returning: (imageIcon, etag))
                    } else {
                        Self.logger.debug("downloadPreview() - FAILED")
                        continuation.resume(returning: (nil, etag))
                    }
                }
        }
    }
    
    func searchMedia(account: String, mediaPath: String, startServerUrl: String, lessDate: Date, greaterDate: Date) async -> (ocIdAdd: [String], ocIdUpdate: [String], ocIdDelete: [String], metadatas: [tableMetadata]) {
        
        let files = await searchMedia(account: account, mediaPath: mediaPath, lessDate: lessDate, greaterDate: greaterDate)
        
        let metadataCollection = await DatabaseManager.shared.convertFilesToMetadatas(files, useMetadataFolder: false)
        
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND date > %@ AND date < %@", account, startServerUrl, NKCommon.typeClassFile.image.rawValue, NKCommon.typeClassFile.video.rawValue, greaterDate as NSDate, lessDate as NSDate)
        let metadatasResult = DatabaseManager.shared.getMetadatas(predicate: predicate)
        
        let metadatas = DatabaseManager.shared.getMetadatasMedia(predicate: predicate)
        
        let result = DatabaseManager.shared.processMetadatas(metadataCollection.metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
        
        return (result.ocIdAdd, result.ocIdUpdate, result.ocIdDelete, metadatas)
    }
    
    private func searchMedia(account: String, mediaPath: String, lessDate: Date, greaterDate: Date) async -> [NKFile] {

        let limit: Int = 1000
        let options = NKRequestOptions(timeout: 300)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.searchMedia(
                path: mediaPath,
                lessDate: lessDate,
                greaterDate: greaterDate,
                elementDate: "d:getlastmodified/",
                limit: limit,
                showHiddenFiles: false,
                options: options) { responseAccount, files, data, error in
                    
                    Self.logger.debug("searchNewMedia.searchMedia() - files count: \(files.count) lessDate: \(lessDate) greaterDate: \(greaterDate)")
                    
                    if error == .success && responseAccount == account && files.count > 0 {
                        continuation.resume(returning: files)
                    } else if error == .success && files.count == 0 {
                        //TODO: Nothing found for valid search. Do another search with a different time frame?
                        continuation.resume(returning: [])
                    } else if error != .success {
                        //TODO: Handle error?
                        NKCommon.shared.writeLog("[ERROR] Media search new media error code \(error.errorCode) " + error.errorDescription)
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(returning: [])
                    }
                }
        }
    }
    
    func processFiles(files: [NKFile], predicate: NSPredicate, lessDate: Date, greaterDate: Date) async -> (ocIdAdd: [String], ocIdUpdate: [String], ocIdDelete: [String]) {
        
        let metadataCollection = await DatabaseManager.shared.convertFilesToMetadatas(files, useMetadataFolder: false)
        
        let metadatasResult = DatabaseManager.shared.getMetadatas(predicate: predicate)
        
        return DatabaseManager.shared.processMetadatas(metadataCollection.metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
    }
}
