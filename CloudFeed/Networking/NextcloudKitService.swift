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

nonisolated protocol NextcloudKitServiceDelegate: AnyObject, Sendable {
    func serverError(error: Int)
    func serverStatusChanged(reachable: Bool)
    func serverCertificateUntrusted(host: String)
}

nonisolated protocol NextcloudKitServiceProtocol: AnyObject, Sendable {

    func setup()
    func appendSession(account: String, urlBase: String, user: String, userId: String, password: String, userAgent: String, groupIdentifier: String)
    func removeSession(account: String)
    func loginPoll(token: String, endpoint: String) async -> (urlBase: String, user: String, appPassword: String)?
    func getLoginFlowV2(url: String, serverVersion: Int) async -> (token: String, endpoint: String, login: String)?
    func checkServerStatus(url: String) async -> (serverVersion: Int?, errorCode: Int?)

    func readFolder(account: String, serverUrl: String, depth: String) async -> (account: String, metadatas: [Metadata], mediaFileCount: Int)?
    func download(account: String, metadata: Metadata, serverUrlFileName: String, fileNameLocalPath: String, progressHandler: @Sendable @escaping (_ metadata: Metadata, _ progress: Progress) -> Void) async
    func downloadPreview(account: String, fileId: String, previewPath: String, iconPath: String, etag: String) async
    func downloadAvatar(account: String, userId: String, fileNameLocalPath: String, etag: String?, avatarSize: Int) async -> String?
    func getDirectDownload(metadata: Metadata) async -> URL?

    func search(account: String, userId: String, urlBase: String, mediaPath: String, fromDate: Date, toDate: Date,
                update: @concurrent @Sendable @escaping (_ metadatas: [Metadata], _ syncFromDate: Date?, _ syncToDate: Date?, _ fromDate: Date?, _ toDate: Date?) async -> Void,
                finish: @concurrent @Sendable @escaping (_ error: Bool) async -> Void) async

    func setFavorite(fileName: String, favorite: Bool, account: String) async -> Bool
    func listingFavorites(account: String) async -> (account: String, files: [Metadata]?)

    func getUserProfile(account: String) async -> Profile?
    func getCapabilitiesServerVersion(_ account: String) async -> String?
    func getQuota(account: String, userId: String) async -> (quotaUsed: Int64, quotaTotal: Int64)?

    func getComments(fileId: String, account: String) async -> [FileComment]?
    func addComment(fileId: String, account: String, message: String) async -> Bool
    func updateComment(fileId: String, account: String, messageId: String, message: String) async -> Bool
    func deleteComment(fileId: String, account: String, messageId: String) async -> Bool
}

nonisolated struct Profile {

    let name: String?
    let email: String?
    let image: UIImage?
    let mediaPath: String?
    let quotaUsed: Int64?
    let quotaTotal: Int64?

    init(name: String?, email: String?, quotaUsed: Int64?, quotaTotal: Int64?) {
        self.name = name
        self.email = email
        self.image = nil
        self.mediaPath = nil
        self.quotaUsed = quotaUsed
        self.quotaTotal = quotaTotal
    }

    init(name: String?, email: String?, image: UIImage?, mediaPath: String?, quotaUsed: Int64?, quotaTotal: Int64?) {
        self.name = name
        self.email = email
        self.image = image
        self.mediaPath = mediaPath
        self.quotaUsed = quotaUsed
        self.quotaTotal = quotaTotal
    }
}

nonisolated struct FileComment: Sendable, Identifiable {

    var id: String {
        return messageId
    }

    var account = ""
    var actorDisplayName = ""
    var actorId = ""
    var actorType = ""
    var creationDateTime: Date
    var isUnread: Bool = false
    var message = ""
    var messageId = ""
    var objectId = ""
    var objectType = ""
    var path = ""
    var verb = ""

    init(account: String = "", actorDisplayName: String = "", actorId: String = "", creationDateTime: Date = .now, message: String = "", messageId: String = "") {
        self.account = account
        self.actorDisplayName = actorDisplayName
        self.actorId = actorId
        self.creationDateTime = creationDateTime
        self.message = message
        self.messageId = messageId
    }

    init(comment: NKComments, account: String) {
        self.account = account
        self.actorDisplayName = comment.actorDisplayName
        self.actorId = comment.actorId
        self.actorType = comment.actorType
        self.creationDateTime = comment.creationDateTime
        self.message = comment.message
        self.messageId = comment.messageId
        self.objectId = comment.objectId
        self.objectType = comment.objectType
        self.isUnread = comment.isUnread
        self.path = comment.path
        self.verb = comment.verb
    }
}

nonisolated final class NextcloudKitService: NextcloudKitServiceProtocol {

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
        NextcloudKit.configureLogger(logLevel: NKLogLevel.compact)
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

    func getCapabilitiesServerVersion(_ account: String) async -> String? {

        let resultsCapabilities = await NextcloudKit.shared.getCapabilitiesAsync(account: account) { _ in }

        guard resultsCapabilities.error == .success, let capabilities = resultsCapabilities.capabilities else {
            return nil
        }

        return capabilities.serverVersion
    }

    // MARK: -
    // MARK: Directories
    func readFolder(account: String, serverUrl: String, depth: String) async -> (account: String, metadatas: [Metadata], mediaFileCount: Int)? {

        let options = NKRequestOptions(queue: .main)

        let result = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: depth, showHiddenFiles: false, account: account, options: options)

        if result.error == .success, let files = result.files {

            let mediaFileCount = files.filter { $0.directory == false && $0.hidden == false && ($0.classFile == Global.FileType.image.rawValue || $0.classFile == Global.FileType.video.rawValue) }.count
            let metadatas = files.filter { $0.directory }.map({ Metadata(file: $0) })

            return (account: result.account, metadatas: metadatas, mediaFileCount: mediaFileCount)
        }

        return nil
    }

    // MARK: -
    // MARK: Download
    func download(account: String, metadata: Metadata, serverUrlFileName: String, fileNameLocalPath: String, progressHandler: @Sendable @escaping (_ metadata: Metadata, _ progress: Progress) -> Void) async {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let results = await NextcloudKit.shared.downloadAsync(serverUrlFileName: serverUrlFileName,
                                                              fileNameLocalPath: fileNameLocalPath,
                                                              account: account,
                                                              options: options,
                                                              progressHandler: { progress in progressHandler(metadata, progress)})

        if results.nkError == .success {

        } else {
            Self.logger.error("[ERROR] Code: \(results.nkError.errorCode) Description: \(results.nkError.errorDescription)")
        }
    }

    func downloadPreview(account: String, fileId: String, previewPath: String, iconPath: String, etag: String) async {

        let results = await NextcloudKit.shared.downloadPreviewAsync(fileId: fileId, etag: etag, account: account)

        if results.error == .success, let data = results.responseData?.data {
            await ImageUtility.saveImageAtPaths(data: data, previewPath: previewPath, iconPath: iconPath)
        }
    }

    func downloadAvatar(account: String, userId: String, fileNameLocalPath: String, etag: String?, avatarSize: Int) async -> String? {

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
    @concurrent
    func search(account: String, userId: String, urlBase: String, mediaPath: String, fromDate: Date, toDate: Date,
                update: @concurrent @Sendable @escaping (_ metadatas: [Metadata], _ syncFromDate: Date?, _ syncToDate: Date?, _ fromDate: Date?, _ toDate: Date?) async -> Void,
                finish: @concurrent @Sendable @escaping (_ error: Bool) async -> Void) async {

        let nkCommon = NextcloudKit.shared.nkCommonInstance
        var paginateToken: String?
        let paginateCount = 200
        var paginateTotal = 0
        var page = 0
        var paginateOffset = 0

        let href = "/files/" + userId + mediaPath
        let elementDate = "d:getlastmodified"

        let toDateString = NKLogFileManager.shared.convertDate(toDate, format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let fromDateString = NKLogFileManager.shared.convertDate(fromDate, format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")

        let httpBodyString = String(format: getSearchRequestBody(href: href, elementDate: elementDate, toDate: toDateString, fromDate: fromDateString, limit: 100000.description))

        guard let httpBody = httpBodyString.data(using: .utf8) else {
            await finish(true)
            return
        }

        var totalCount = 0

        while true {

            if Task.isCancelled {
                await finish(false)
                break
            }

            var isPaginate: Bool = false

            let options = NKRequestOptions(timeout: 180, taskDescription: "search", paginate: true,
                                           paginateToken: paginateToken, paginateOffset: paginateOffset, paginateCount: paginateCount,
                                           queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

            let results = await NextcloudKit.shared.searchAsync(serverUrl: urlBase, httpBody: httpBody, showHiddenFiles: false,
                                                                includeHiddenFiles: [], account: account, options: options, taskHandler: { _ in })

            if Task.isCancelled {
                await finish(false)
                break
            }

            if results.error == .success {

                let allHeaderFields = results.responseData?.response?.allHeaderFields

                if let result = nkCommon.findHeader("x-nc-paginate-token", allHeaderFields: allHeaderFields) {
                    paginateToken = result
                }
                if let result = nkCommon.findHeader("x-nc-paginate", allHeaderFields: allHeaderFields) {
                    isPaginate = Bool(result) ?? false
                }
                if let result = nkCommon.findHeader("x-nc-paginate-total", allHeaderFields: allHeaderFields) {
                    paginateTotal = Int(result) ?? 0
                }

                Self.logger.debug("Search success with count: \(results.files?.count ?? -1)")

                if let files = results.files {

                    totalCount += files.count

                    let sorted = files.sorted {
                        $0.date > $1.date
                    }

                    let mapped = sorted.map { Metadata(file: $0) }

                    if mapped.count > 0 {
                        if page == 0 {
                            await update(mapped, nil, .distantFuture, fromDate, toDate)
                        } else if !isPaginate || totalCount >= paginateTotal || paginateOffset >= paginateTotal {
                            await update(mapped, .distantPast, nil, fromDate, toDate)
                        } else {
                            await update(mapped, nil, nil, fromDate, toDate)
                        }
                    }
                }
            } else {
                Self.logger.error("Search failed with error: \(results.error.errorCode) description: \(results.error.errorDescription)")
                await finish(true)
                break
            }

            Self.logger.debug("Search paginateOffset: \(paginateOffset) totalCount: \(totalCount) paginateTotal: \(paginateTotal)")

            if !isPaginate || totalCount >= paginateTotal || paginateOffset >= paginateTotal {
                Self.logger.debug("Search finished paginating")
                await finish(false)
                break
            }

            page += 1
            paginateOffset = page * paginateCount
        }
    }

    private func getSearchRequestBody(href: String, elementDate: String, toDate: String, fromDate: String, limit: String) -> String {
        // NOTE: metadata-photos-size is NC v28+
        // NOTE: metadata-photos-original_date_time may not be reliable
        let request = """
                <?xml version=\"1.0\"?>
                <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
                    <d:basicsearch>

                    <d:select>
                        <d:prop>
                            <id xmlns="http://owncloud.org/ns"/>
                            <fileid xmlns="http://owncloud.org/ns"/>
                            <d:getetag/>
                            <d:getlastmodified />
                            <upload_time xmlns="http://nextcloud.org/ns"/>
                            <size xmlns="http://owncloud.org/ns"/>
                            <has-preview xmlns="http://nextcloud.org/ns"/>
                            <owner-id xmlns=\"http://owncloud.org/ns\"/>
                            <owner-display-name xmlns=\"http://owncloud.org/ns\"/>
                            <metadata-photos-size xmlns=\"http://nextcloud.org/ns\"/>
                            <favorite xmlns=\"http://owncloud.org/ns\"/>
                            <metadata-photos-original_date_time xmlns="http://nextcloud.org/ns"/>
                        </d:prop>
                    </d:select>

                    <!-- ===================================================== -->
                    <!-- FROM: recursive search starting from the given href   -->
                    <!-- ===================================================== -->
                    <d:from>
                        <d:scope>
                            <d:href>\(href)</d:href>
                            <d:depth>infinity</d:depth>
                        </d:scope>
                    </d:from>

                    <!-- ===================================================== -->
                    <!-- WHERE:                                                -->
                    <!-- 1) Filter only image and video content types          -->
                    <!-- 2) Apply a date range on elementDate                  -->
                    <!-- ===================================================== -->
                    <d:where>
                        <d:and>

                            <!-- Media type filter -->
                            <d:or>
                                <d:like>
                                    <d:prop><d:getcontenttype/></d:prop>
                                    <d:literal>image/%%</d:literal>
                                </d:like>
                                <d:like>
                                    <d:prop><d:getcontenttype/></d:prop>
                                    <d:literal>video/%%</d:literal>
                                </d:like>
                            </d:or>

                            <!-- Date / numeric range filter LTE / GTE -->
                            <d:and>
                                <d:lte>
                                    <d:prop><\(elementDate)/></d:prop>
                                    <d:literal>\(toDate)</d:literal>
                                </d:lte>
                                <d:gte>
                                    <d:prop><\(elementDate)/></d:prop>
                                    <d:literal>\(fromDate)</d:literal>
                                </d:gte>
                            </d:and>
                        </d:and>
                    </d:where>

                    <!-- ===================================================== -->
                    <!-- ORDER BY:                                             -->
                    <!-- Primary sort on elementDate (descending)              -->
                    <!-- Secondary sort on displayname for deterministic order -->
                    <!-- ===================================================== -->
                    <d:orderby>
                        <d:order>
                            <d:prop><\(elementDate)/></d:prop>
                            <d:descending/>
                        </d:order>
                        <d:order>
                            <d:prop><d:displayname/></d:prop>
                            <d:descending/>
                        </d:order>
                    </d:orderby>

                    <!-- ===================================================== -->
                    <!-- LIMIT: maximum number of results returned             -->
                    <!-- ===================================================== -->
                    <d:limit>
                        <d:nresults>\(limit)</d:nresults>
                    </d:limit>

                    </d:basicsearch>
                </d:searchrequest>
                """
                return request
    }

    // MARK: -
    // MARK: Favorite
    func setFavorite(fileName: String, favorite: Bool, account: String) async -> Bool {
        let result = await NextcloudKit.shared.setFavoriteAsync(fileName: fileName, favorite: favorite, account: account)
        if result.error == .success {
            return false
        } else {
            return true
        }
    }

    func listingFavorites(account: String) async -> (account: String, files: [Metadata]?) {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let result = await NextcloudKit.shared.listingFavoritesAsync(showHiddenFiles: false, account: account, options: options)

        if result.error == .success, let files = result.files {
            return (account, files.map { Metadata(file: $0) })
        } else {
            return (account, nil)
        }
    }

    // MARK: -
    // MARK: Profile
    func getUserProfile(account: String) async -> Profile? {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getUserProfile(account: account, options: options) { _, userProfile, _, error in
                guard error == .success, let userProfile = userProfile else {
                    Self.logger.error("[ERROR] The server has response with Unauthorized \(error.errorCode)")
                    continuation.resume(returning: nil)
                    return
                }
                let profile = Profile(name: userProfile.displayName, email: userProfile.email, quotaUsed: userProfile.quotaUsed, quotaTotal: userProfile.quotaTotal)
                continuation.resume(returning: profile)
            }
        }
    }

    func getQuota(account: String, userId: String) async -> (quotaUsed: Int64, quotaTotal: Int64)? {

        let resultUserProfile = await NextcloudKit.shared.getUserMetadataAsync(account: account, userId: userId, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _ in }

        if resultUserProfile.error == .success, let userProfile = resultUserProfile.userProfile {
            return (quotaUsed: userProfile.quotaUsed, quotaTotal: userProfile.quotaTotal)
        } else {
            return nil
        }
    }

    // MARK: -
    // MARK: Comments
    func getComments(fileId: String, account: String) async -> [FileComment]? {

        let results = await NextcloudKit.shared.getCommentsAsync(fileId: fileId, account: account)

        if results.error == .success, let nkComments = results.items {
            return Array(nkComments.map { FileComment(comment: $0, account: account) })
        }

        return nil
    }

    func addComment(fileId: String, account: String, message: String) async -> Bool {

        let result = await NextcloudKit.shared.putCommentsAsync(fileId: fileId, message: message, account: account)
        return result.error != .success
    }

    func updateComment(fileId: String, account: String, messageId: String, message: String) async -> Bool {

        let result = await NextcloudKit.shared.updateCommentsAsync(fileId: fileId, messageId: messageId, message: message, account: account)
        return result.error != .success
    }

    func deleteComment(fileId: String, account: String, messageId: String) async -> Bool {

        let result = await NextcloudKit.shared.deleteCommentsAsync(fileId: fileId, messageId: messageId, account: account)
        return result.error != .success
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
        let trust: SecTrust? = protectionSpace.serverTrust

        if trust != nil,
           let certificates = (SecTrustCopyCertificateChain(trust!) as? [SecCertificate]),
           let certificate = certificates.first {

            //extract certificate text
            saveX509Certificate(certificate, host: host, directoryCertificate: directoryCertificate)

            let isServerTrusted = SecTrustEvaluateWithError(trust!, nil)
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

        Self.logger.debug("NextcloudKitService.checkTrustedChallenge() - isTrusted: \(isTrusted)")

        if isTrusted && trust != nil {
            completionHandler(.useCredential, URLCredential(trust: trust!))
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

    nonisolated func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Self.logger.debug("NextcloudKitService.authenticationChallenge() - authenticationMethod: \(challenge.protectionSpace.authenticationMethod)")
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            //not implemented
            completionHandler(.performDefaultHandling, nil)
        } else {
            checkTrustedChallenge(session, didReceive: challenge, completionHandler: completionHandler)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {

    }

    nonisolated func networkReachabilityObserver(_ typeReachability: NKTypeReachability) {
        delegate.serverStatusChanged(reachable: typeReachability == .reachableCellular || typeReachability == .reachableEthernetOrWiFi)
    }

    nonisolated func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {

    }

    nonisolated func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) {

    }

    nonisolated func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

    }

    nonisolated func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError) {

    }

    nonisolated func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError) {

    }

    nonisolated func request<Value: Sendable>(_ request: Alamofire.DataRequest, didParseResponse response: Alamofire.AFDataResponse<Value>) {
        if let statusCode = response.response?.statusCode, statusCode == Global.shared.errorMaintenance {
            delegate.serverError(error: statusCode)
        }
    }
}
