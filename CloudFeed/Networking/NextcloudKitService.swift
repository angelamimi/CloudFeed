//
//  NextcloudKitService.swift
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

@preconcurrency import NextcloudKit
import os.log
import UIKit

protocol NextcloudKitServiceProtocol: Sendable {
    
    func setupAccount(account: String, user: String, userId: String, password: String, urlBase: String)
    func setupVersion(serverVersionMajor: Int)
    func getCapabilities(account: String) async -> (account: String?, data: Data?)
    
    func download(metadata: Metadata, selector: String, serverUrlFileName: String, fileNameLocalPath: String) async -> Bool
    func downloadPreview(account: String, fileId: String, previewPath: String, previewWidth: Int, previewHeight: Int, iconPath: String, etagResource: String?) async -> String?
    func downloadAvatar(account: String, userId: String, fileName: String, fileNameLocalPath: String, etag: String?, avatarSize: Int, avatarSizeRounded: Int) async -> String?
    func getDirectDownload(metadata: Metadata) async -> URL?
    
    func searchMedia(account: String, mediaPath: String, toDate: Date, fromDate: Date, limit: Int) async -> (files: [Metadata], error: Bool)

    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> Bool
    func listingFavorites(account: String) async -> (account: String, files: [Metadata]?)
    
    func getUserProfile(account: String) async -> (profileDisplayName: String, profileEmail: String)
}

final class NextcloudKitService : NextcloudKitServiceProtocol {
    
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
    
    func getCapabilities(account: String) async -> (account: String?, data: Data?) {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getCapabilities(account: account, options: options) { account, data, error in
                continuation.resume(returning: (account, data))
            }
        }
    }
    
    
    // MARK: -
    // MARK: Download
    func download(metadata: Metadata, selector: String, serverUrlFileName: String, fileNameLocalPath: String) async -> Bool {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.download(
                serverUrlFileName: serverUrlFileName,
                fileNameLocalPath: fileNameLocalPath,
                account: metadata.account,
                options: options,
                requestHandler: { request in }) { (account, etag, date, _, allHeaderFields, afError, error) in
                    
                    if afError?.isExplicitlyCancelledError ?? false {
                        
                    } else if error == .success {
                        continuation.resume(returning: false)
                        return
                    }
                    
                    continuation.resume(returning: true)
                }
        }
    }
    
    func downloadPreview(account: String, fileId: String, previewPath: String, previewWidth: Int, previewHeight: Int, iconPath: String, etagResource: String?) async -> String? {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        let size = ImageUtility.getPreviewSize(width: previewWidth, height: previewHeight)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.downloadPreview(fileId: fileId,
                                                fileNamePreviewLocalPath: previewPath,
                                                fileNameIconLocalPath: iconPath,
                                                widthPreview: Int(size.width),
                                                heightPreview: Int(size.height),
                                                sizeIcon: Global.shared.sizeIcon,
                                                etag: etagResource,
                                                account: account,
                                                options: options) { _, imagePreview, _, _, etag, error in
                if error == .success, imagePreview != nil {
                    continuation.resume(returning: etag)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func downloadAvatar(account: String, userId: String, fileName: String, fileNameLocalPath: String, etag: String?, avatarSize: Int, avatarSizeRounded: Int) async -> String? {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            
            NextcloudKit.shared.downloadAvatar(
                user: userId,
                fileNameLocalPath: fileNameLocalPath,
                sizeImage: avatarSize,
                avatarSizeRounded: avatarSizeRounded,
                etag: etag, 
                account: account,
                options: options) { _, _, _, etag, error in
                    
                    guard let etag = etag, error == .success else {
                        Self.logger.error("downloadAvatar() - error: \(error.errorDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: etag)
                }
        }
    }
    
    func getDirectDownload(metadata: Metadata) async -> URL? {
        
        return await withCheckedContinuation { continuation in
            
            NextcloudKit.shared.getDirectDownload(fileId: metadata.fileId, account: metadata.account) { _, url, _, error in
                if error == .success && url != nil {
                    if let url = URL(string: url!) {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: -
    // MARK: Search
    func searchMedia(account: String, mediaPath: String, toDate: Date, fromDate: Date, limit: Int) async -> (files: [Metadata], error: Bool) {

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
                account: account,
                options: options) { responseAccount, files, data, error in
                    
                    //Self.logger.debug("searchMedia() - files count: \(files.count) toDate: \(toDate.formatted(date: .abbreviated, time: .standard)) fromDate: \(fromDate.formatted(date: .abbreviated, time: .standard))")

                    if error == .success && responseAccount == account && files.count > 0 {
                        continuation.resume(returning: (Array(files.map { Metadata.init(file: $0) }), false))
                    } else if error == .success && files.count == 0 {
                        continuation.resume(returning: ([], false))
                    } else if error != .success {
                        Self.logger.error("[ERROR] Media search new media error code \(error.errorCode) \(error.errorDescription)")
                        continuation.resume(returning: ([], true))
                    } else {
                        continuation.resume(returning: ([], true)) //invalid state, like account mismatch
                    }
                }
        }
    }
    
    
    // MARK: -
    // MARK: Favorite
    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> Bool {
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite, account: account) { favAccount, error in
                if error == .success && account == favAccount {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: true)
            }
        }
    }
    
    func listingFavorites(account: String) async -> (account: String, files: [Metadata]?) {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.listingFavorites(showHiddenFiles: false, account: account, options: options) { account, files, data, error in
                guard error == .success else {
                    continuation.resume(returning: (account, nil))
                    return
                }
                
                continuation.resume(returning: (account, Array(files.map { Metadata.init(file: $0) })))
            }
        }
    }
    
    
    // MARK: -
    // MARK: Profile
    func getUserProfile(account: String) async -> (profileDisplayName: String, profileEmail: String) {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getUserProfile(account: account, options: options) { account, userProfile, data, error in
                guard error == .success, let userProfile = userProfile else {
                    // Ops the server has Unauthorized
                    Self.logger.error("[ERROR] The server has response with Unauthorized \(error.errorCode)")
                    continuation.resume(returning: ("", ""))
                    return
                }
                
                continuation.resume(returning: (userProfile.displayName, userProfile.email))
            }
        }
    }
}
