//
//  MockNextcloudKitService.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 9/18/23.
//

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
    
    func download(metadata: tableMetadata, selector: String, serverUrlFileName: String, fileNameLocalPath: String) async -> NKError {
        return NKError.success
    }
    
    func downloadPreview(fileNamePath: String, fileNamePreviewLocalPath: String, fileNameIconLocalPath: String, etagResource: String?) async {
        
    }
    
    func downloadAvatar(userId: String, fileName: String, fileNameLocalPath: String, etag: String?) async -> String? {
        return nil
    }
    
    func searchMedia(account: String, mediaPath: String, lessDate: Date, greaterDate: Date, limit: Int) async -> (files: [NKFile], error: Bool) {
        return (files: [], false)
    }
    
    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> NKError {
        return NKError.success
    }
    
    func listingFavorites() async -> (account: String, files: [NKFile]?) {
        
        let filesJSON = MockNextcloudKitService.mockFavorites()
        var resultFiles: [NKFile] = []
        
        for fileJSON in filesJSON {

            let file = NKFile()
            file.account = fileJSON["account"] as! String
            file.contentType = fileJSON["contentType"] as! String
            file.favorite = fileJSON["favorite"] as! String == "true" ? true : false
            file.fileName = fileJSON["fileName"] as! String
            file.ocId = fileJSON["ocId"] as! String
            file.path = fileJSON["path"] as! String
            
            resultFiles.append(file)
        }
        
        return (account: "codemistressmimi https://cloud.angelamimi.com", resultFiles)
    }
    
    func getUserProfile() async -> (profileDisplayName: String, profileEmail: String) {
        return (profileDisplayName: "", profileEmail: "")
    }
}

extension MockNextcloudKitService {
    
    static func mockFavorites() -> [NSDictionary] {
        
        let fileName = "mock-favorites"
        
        guard let url = Bundle(for: MockNextcloudKitService.self).url(forResource: fileName, withExtension: "json") else {
            fatalError(fileName + " not found")
        }
        
        guard let rawData = try? Data(contentsOf: url) else {
            fatalError("Failed to load data from " + fileName)
        }
        
        guard let data = try? JSONSerialization.jsonObject(with: rawData, options: .allowFragments) as? [NSDictionary] else {
            fatalError("Failed to decode data from " + fileName)
        }
        
        return data
    }
}
