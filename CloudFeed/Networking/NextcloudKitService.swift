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
import Alamofire
import OpenSSL

protocol NextcloudKitServiceDelegate: AnyObject, Sendable {
    func serverError(error: Int)
    func serverStatusChanged(reachable: Bool)
    func serverCertificateUntrusted(host: String)
}

protocol NextcloudKitServiceProtocol: AnyObject, Sendable {
    
    func setup()
    func appendSession(account: String, urlBase: String, user: String, userId: String, password: String, userAgent: String, groupIdentifier: String)
    func removeSession(account: String)
    func loginPoll(token: String, endpoint: String) async -> (urlBase: String, user: String, appPassword: String)?
    func getLoginFlowV2(url: String, serverVersion: Int) async -> (token: String, endpoint: String, login: String)?
    func checkServerStatus(url: String) async -> (serverVersion: Int?, errorCode: Int?)
    
    func readFolder(account: String, serverUrl: String, depth: String) async -> (account: String, metadatas: [Metadata])?
    func download(metadata: Metadata, serverUrlFileName: String, fileNameLocalPath: String, progressHandler: @escaping (_ metadata: Metadata, _ progress: Progress) -> Void) async
    func downloadPreview(account: String, fileId: String, previewPath: String, iconPath: String, etag: String) async
    func downloadAvatar(account: String, userId: String, fileName: String, fileNameLocalPath: String, etag: String?, avatarSize: Int) async -> String?
    func getDirectDownload(metadata: Metadata) async -> URL?
    
    func searchMedia(account: String, mediaPath: String, toDate: Date, fromDate: Date, limit: Int, serverVersion: Int?) async -> (files: [Metadata], error: Bool)

    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> Bool
    func listingFavorites(account: String) async -> (account: String, files: [Metadata]?)
    
    func getUserProfile(account: String) async -> (profileDisplayName: String, profileEmail: String)
}

final class NextcloudKitService : NextcloudKitServiceProtocol {
    
    let certificatesDirectory: URL
    private let delegate: NextcloudKitServiceDelegate
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: NextcloudKitService.self)
    )
    
    init(certificatesDirectory: URL, delegate: NextcloudKitServiceDelegate) {
        self.certificatesDirectory = certificatesDirectory
        self.delegate = delegate
    }
    
    // MARK: -
    // MARK: NextcloudKit Setup
    
    func setup() {
        NextcloudKit.shared.setup(delegate: self)
        NextcloudKit.configureLogger(logLevel: NKLogLevel.disabled)
    }
    
    func appendSession(account: String, urlBase: String, user: String, userId: String, password: String, userAgent: String, groupIdentifier: String) {

        NextcloudKit.shared.appendSession(account: account, urlBase: urlBase, user: user,
                                          userId: userId, password: password,
                                          userAgent: userAgent, groupIdentifier: groupIdentifier)
    }
    
    func removeSession(account: String) {
        NextcloudKit.shared.nkCommonInstance.nksessions.remove(account: account)
    }
    
    func getLoginFlowV2(url: String, serverVersion: Int) async -> (token: String, endpoint: String, login: String)? {
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getLoginFlowV2(serverUrl: url) { token, endpoint, login, _, error in
                
                if error == .success, let token, let endpoint, let login {
                    continuation.resume(returning: (token: token, endpoint: endpoint, login: login))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func checkServerStatus(url: String) async -> (serverVersion: Int?, errorCode: Int?) {
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getServerStatus(serverUrl: url) { _, serverInfoResult in
                switch serverInfoResult {
                case .success(let serverInfo):
                    continuation.resume(returning: (serverVersion: serverInfo.versionMajor, errorCode: nil))
                case .failure(let error):
                    continuation.resume(returning: (serverVersion: nil, errorCode: error.errorCode))
                }
            }
        }
    }
    
    func loginPoll(token: String, endpoint: String) async -> (urlBase: String, user: String, appPassword: String)? {
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getLoginFlowV2Poll(token: token, endpoint: endpoint) { server, loginName, appPassword, _, error in
                if error == .success, let urlBase = server, let user = loginName, let appPassword {
                    continuation.resume(returning: (urlBase: urlBase, user: user, appPassword: appPassword))
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    
    // MARK: -
    // MARK: Directories
    func readFolder(account: String, serverUrl: String, depth: String) async -> (account: String, metadatas: [Metadata])? {
        
        let options = NKRequestOptions(queue: .main)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: depth, showHiddenFiles: false, account: account, options: options) { account, files, _, error in
                if error == .success, let files {
                    let metadatas = files.filter { $0.directory }.map({ Metadata.init(file: $0) })
                    continuation.resume(returning: (account: account, metadatas: metadatas))
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    
    // MARK: -
    // MARK: Download
    func download(metadata: Metadata, serverUrlFileName: String, fileNameLocalPath: String, progressHandler: @escaping (_ metadata: Metadata, _ progress: Progress) -> Void) async {
        
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.download(
                serverUrlFileName: serverUrlFileName,
                fileNameLocalPath: fileNameLocalPath,
                account: metadata.account,
                options: options,
                requestHandler: { request in },
                progressHandler: { progress in
                    progressHandler(metadata, progress)
                }) { (account, etag, date, _, allHeaderFields, afError, error) in
                    continuation.resume()
                }
        }
    }
    
    func downloadPreview(account: String, fileId: String, previewPath: String, iconPath: String, etag: String) async {
        
        let results = await NextcloudKit.shared.downloadPreviewAsync(fileId: fileId, etag: etag, account: account,
                                                                     options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue))
        
        if results.error == .success, let data = results.responseData?.data {
            ImageUtility.saveImageAtPaths(data: data, previewPath: previewPath, iconPath: iconPath)
        }
    }
    
    func downloadAvatar(account: String, userId: String, fileName: String, fileNameLocalPath: String, etag: String?, avatarSize: Int) async -> String? {
       
        let results = await NextcloudKit.shared.downloadAvatarAsync(user: userId,
                                                                    fileNameLocalPath: fileNameLocalPath,
                                                                    sizeImage: avatarSize,
                                                                    etagResource: etag,
                                                                    account: account)
        if  results.error == .success,
            let etagResult = results.etag,
            etagResult != etag {
            return etagResult
        } else {
            return nil
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
    func searchMedia(account: String, mediaPath: String, toDate: Date, fromDate: Date, limit: Int, serverVersion: Int?) async -> (files: [Metadata], error: Bool) {
        
        let limit: Int = limit
        let options = NKRequestOptions(timeout: 120, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        let elementDate: String
        var lessDateAny: Any
        var greaterDateAny: Any

        if serverVersion != nil && serverVersion! >= Global.shared.photoOriginalServerVersion {
            elementDate = "d:getlastmodified" //"nc:metadata-photos-original_date_time" - gifs and svgs disappear
            lessDateAny = Int(toDate.timeIntervalSince1970)
            greaterDateAny = Int(fromDate.timeIntervalSince1970)
        } else {
            elementDate = "d:getlastmodified"
            lessDateAny = toDate
            greaterDateAny = fromDate
        }
        
        let result = await NextcloudKit.shared.searchMediaAsync(path: mediaPath, lessDate: lessDateAny, greaterDate: greaterDateAny,
                                                                elementDate: elementDate, limit: limit, account: account, options: options)
        
        if result.error == .success, let files = result.files {
            return (Array(files.map { Metadata.init(file: $0) }), false)
        } else {
            Self.logger.error("[ERROR] Media search new media error code \(result.error.errorCode) \(result.error.errorDescription)")
            return ([], true)
        }
    }
    
    
    
    // MARK: -
    // MARK: Favorite
    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> Bool {

        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite, account: account) { _, _, error in
                if error == .success {
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
                guard error == .success, let files else {
                    continuation.resume(returning: (account, nil))
                    return
                }
                continuation.resume(returning: (account, files.map { Metadata.init(file: $0) }))
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
    
    //Source: https://github.com/nextcloud/ios/blob/master/iOSClient/Networking/NCNetworking.swift
    private func checkTrustedChallenge(_ session: URLSession,
                                       didReceive challenge: URLAuthenticationChallenge,
                                       completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        let protectionSpace: URLProtectionSpace = challenge.protectionSpace
        let directoryCertificate = certificatesDirectory.path
        let host = challenge.protectionSpace.host
        let certificateSavedPath = directoryCertificate + "/" + host + ".der"
        var isTrusted: Bool

        if let trust: SecTrust = protectionSpace.serverTrust,
           let certificates = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]),
           let certificate = certificates.first {

            //extract certificate text
            saveX509Certificate(certificate, host: host, directoryCertificate: directoryCertificate)

            let isServerTrusted = SecTrustEvaluateWithError(trust, nil)
            let certificateCopyData = SecCertificateCopyData(certificate)
            let data = CFDataGetBytePtr(certificateCopyData)
            let size = CFDataGetLength(certificateCopyData)
            let certificateData = NSData(bytes: data, length: size)

            certificateData.write(toFile: directoryCertificate + "/" + host + ".tmp", atomically: true)

            if isServerTrusted {
                isTrusted = true
            } else if let certificateDataSaved = NSData(contentsOfFile: certificateSavedPath), certificateData.isEqual(to: certificateDataSaved as Data) {
                isTrusted = true
            } else {
                isTrusted = false
            }
        } else {
            isTrusted = false
        }

        if isTrusted {
            completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
        } else {
            delegate.serverCertificateUntrusted(host: host)
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private func saveX509Certificate(_ certificate: SecCertificate, host: String, directoryCertificate: String) {
        
        let certNamePathTXT = directoryCertificate + "/" + host + ".txt"
        let data: CFData = SecCertificateCopyData(certificate)
        let mem = BIO_new_mem_buf(CFDataGetBytePtr(data), Int32(CFDataGetLength(data)))
        let x509cert = d2i_X509_bio(mem, nil)

        if x509cert == nil {
            nkLog(error: "[ERROR] OpenSSL couldn't parse X509 Certificate")
        } else {
            // save details
            if FileManager.default.fileExists(atPath: certNamePathTXT) {
                do {
                    try FileManager.default.removeItem(atPath: certNamePathTXT)
                } catch { }
            }
            let fileCertInfo = fopen(certNamePathTXT, "w")
            if fileCertInfo != nil {
                let output = BIO_new_fp(fileCertInfo, BIO_NOCLOSE)
                X509_print_ex(output, x509cert, UInt(XN_FLAG_COMPAT), UInt(X509_FLAG_COMPAT))
                BIO_free(output)
            }
            fclose(fileCertInfo)
            X509_free(x509cert)
        }

        BIO_free(mem)
    }
}

extension NextcloudKitService: NextcloudKitDelegate {

    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            //not implemented
            completionHandler(.performDefaultHandling, nil)
        } else {
            checkTrustedChallenge(session, didReceive: challenge, completionHandler: completionHandler)
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        
    }
    
    func networkReachabilityObserver(_ typeReachability: NKTypeReachability) {
        delegate.serverStatusChanged(reachable: typeReachability == .reachableCellular || typeReachability == .reachableEthernetOrWiFi)
    }
    
    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        //Self.logger.debug("downloadProgress")
    }
    
    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {
        //Self.logger.debug("uploadProgress")
    }
    
    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        //Self.logger.debug("downloadingFinish")
    }
    
    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError) {
        //Self.logger.debug("downloadComplete")
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError) {
        //Self.logger.debug("uploadComplete")
    }
    
    func request<Value: Sendable>(_ request: Alamofire.DataRequest, didParseResponse response: Alamofire.AFDataResponse<Value>) {
        if let statusCode = response.response?.statusCode, statusCode == Global.shared.errorMaintenance {
            delegate.serverError(error: statusCode)
        }
    }
}
