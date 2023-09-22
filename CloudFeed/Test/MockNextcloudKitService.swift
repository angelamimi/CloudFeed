//
//  MockNextcloudKitService.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 9/18/23.
//

@testable import CloudFeed
import NextcloudKit
import UIKit

final class MockNextcloudKitService: NextcloudKitServiceProtocol {
    
    func setupAccount(account: String, user: String, userId: String, password: String, urlBase: String) {
        
    }
    
    func setupVersion(serverVersionMajor: Int) {
        
    }
    
    func getCapabilities() async -> (account: String?, data: Data?) {
        return (account: nil, data: nil)
    }
    
    func download(metadata: CloudFeed.tableMetadata, selector: String, serverUrlFileName: String, fileNameLocalPath: String) async -> NextcloudKit.NKError {
        return nil
    }
    
    func downloadPreview(fileNamePath: String, fileNamePreviewLocalPath: String, fileNameIconLocalPath: String, etagResource: String?) async {
        
    }
    
    func downloadAvatar(userId: String, fileName: String, fileNameLocalPath: String, etag: String?) async -> String? {
        return nil
    }
    
    func searchMedia(account: String, mediaPath: String, lessDate: Date, greaterDate: Date, limit: Int) async -> (files: [NextcloudKit.NKFile], error: Bool) {
        return (files: [], false)
    }
    
    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> NextcloudKit.NKError {
        return nil
    }
    
    func listingFavorites() async -> (account: String, files: [NextcloudKit.NKFile]?) {
        return (account: "", [])
    }
    
    func getUserProfile() async -> (profileDisplayName: String, profileEmail: String) {
        return (profileDisplayName: "", profileEmail: "")
    }
    
    
}
