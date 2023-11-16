//
//  NextcloudKitService.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/1/23.
//
import NextcloudKit
import os.log
import UIKit

protocol NextcloudKitServiceProtocol: AnyObject {
    
    func setupAccount(account: String, user: String, userId: String, password: String, urlBase: String)
    func setupVersion(serverVersionMajor: Int)
    func getCapabilities() async -> (account: String?, data: Data?)
    
    func download(metadata: tableMetadata, selector: String, serverUrlFileName: String, fileNameLocalPath: String) async -> NKError
    func downloadPreview(fileNamePath: String, fileNamePreviewLocalPath: String, fileNameIconLocalPath: String, etagResource: String?) async
    func downloadAvatar(userId: String, fileName: String, fileNameLocalPath: String, etag: String?) async -> String?
    
    func searchMedia(account: String, mediaPath: String, toDate: Date, fromDate: Date, limit: Int) async -> (files: [NKFile], error: Bool)
    
    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> NKError
    func listingFavorites() async -> (account: String, files: [NKFile]?)
    
    func getUserProfile() async -> (profileDisplayName: String, profileEmail: String)
}

class NextcloudKitService : NextcloudKitServiceProtocol {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: NextcloudKitService.self)
    )
    
    // MARK: -
    // MARK: NextcloudKit Setup
    func setupAccount(account: String, user: String, userId: String, password: String, urlBase: String) {
        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
    }
    
    func setupVersion(serverVersionMajor: Int) {
        NextcloudKit.shared.setup(nextcloudVersion: serverVersionMajor)
    }
    
    func getCapabilities() async -> (account: String?, data: Data?) {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getCapabilities(options: options) { account, data, error in
                continuation.resume(returning: (account, data))
            }
        }
    }
    
    
    // MARK: -
    // MARK: Download
    func download(metadata: tableMetadata, selector: String, serverUrlFileName: String, fileNameLocalPath: String) async -> NKError {
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.download(
                serverUrlFileName: serverUrlFileName,
                fileNameLocalPath: fileNameLocalPath,
                queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue,
                requestHandler: { request in }) { (account, etag, date, _, allHeaderFields, afError, error) in
                    
                    if afError?.isExplicitlyCancelledError ?? false {
                        
                    } else if error == .success {
                        continuation.resume(returning: error)
                        return
                    }
                    
                    continuation.resume(returning: NKError.invalidData)
                }
        }
    }
    
    func downloadPreview(fileNamePath: String, fileNamePreviewLocalPath: String, fileNameIconLocalPath: String, etagResource: String?) async {
     
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let result = await NextcloudKit.shared.downloadPreview(fileNamePathOrFileId: fileNamePath,
                                                                      fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                                                                      widthPreview: Global.shared.sizePreview,
                                                                      heightPreview: Global.shared.sizePreview,
                                                                      fileNameIconLocalPath: fileNameIconLocalPath,
                                                                      sizeIcon: Global.shared.sizeIcon,
                                                                      etag: etagResource,
                                                                      options: options)
        
        print("downloadPreview() - fileNamePath: \(fileNamePath)")
        print("downloadPreview() - icon size: \(result.imageIcon?.size ?? CGSize(width: 0, height: 0))")
        print("downloadPreview() - preview size: \(result.imagePreview?.size ?? CGSize(width: 0, height: 0))")
        print("downloadPreview() - original size: \(result.imageOriginal?.size ?? CGSize(width: 0, height: 0))")
    }
    
    func downloadAvatar(userId: String, fileName: String, fileNameLocalPath: String, etag: String?) async -> String? {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            
            //TODO: REFACTOR! Was account.userId
            NextcloudKit.shared.downloadAvatar(
                user: userId,
                fileNameLocalPath: fileNameLocalPath,
                sizeImage: Global.shared.avatarSize,
                avatarSizeRounded: Global.shared.avatarSizeRounded,
                etag: etag, options: options) { _, _, _, etag, error in
                    
                    guard let etag = etag, error == .success else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: etag)
                }
        }
    }
    
    
    // MARK: -
    // MARK: Search
    func searchMedia(account: String, mediaPath: String, toDate: Date, fromDate: Date, limit: Int) async -> (files: [NKFile], error: Bool) {
        
        let limit: Int = limit
        let options = NKRequestOptions(timeout: 300)
        
        let greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: fromDate)!
        let lessDate = Calendar.current.date(byAdding: .second, value: 1, to: toDate)!
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.searchMedia(
                path: mediaPath,
                lessDate: lessDate,
                greaterDate: greaterDate,
                elementDate: "d:getlastmodified/",
                limit: limit,
                showHiddenFiles: false,
                options: options) { responseAccount, files, data, error in
                    
                    Self.logger.debug("searchMedia() - files count: \(files.count) toDate: \(toDate.formatted(date: .abbreviated, time: .standard)) fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")
                    
                    if error == .success && responseAccount == account && files.count > 0 {
                        continuation.resume(returning: (files, false))
                    } else if error == .success && files.count == 0 {
                        //TODO: Nothing found for valid search. Do another search with a different time frame?
                        continuation.resume(returning: ([], false))
                    } else if error != .success {
                        //TODO: Handle error?
                        NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(error.errorCode) " + error.errorDescription)
                        continuation.resume(returning: ([], true))
                    } else {
                        continuation.resume(returning: ([], true)) //invalid state, like account mismatch
                    }
                }
        }
    }
    
    
    // MARK: -
    // MARK: Favorite
    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> NKError {
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite) { favAccount, error in
                if error == .success && account == favAccount {
                    continuation.resume(returning: error)
                    return
                }
                continuation.resume(returning: NKError.invalidData)
            }
        }
    }
    
    func listingFavorites() async -> (account: String, files: [NKFile]?) {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.listingFavorites(showHiddenFiles: false, options: options) { account, files, data, error in
                guard error == .success else {
                    continuation.resume(returning: (account, nil))
                    return
                }
                
                continuation.resume(returning: (account, files))
            }
        }
    }
    
    
    // MARK: -
    // MARK: Profile
    func getUserProfile() async -> (profileDisplayName: String, profileEmail: String) {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getUserProfile(options: options) { account, userProfile, data, error in
                guard error == .success, let userProfile = userProfile else {
                    // Ops the server has Unauthorized
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] The server has response with Unauthorized \(error.errorCode)")
                    continuation.resume(returning: ("", ""))
                    return
                }
                
                continuation.resume(returning: (userProfile.displayName, userProfile.email))
            }
        }
    }
}
