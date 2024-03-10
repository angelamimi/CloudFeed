//
//  MockNextcloudKitService.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 9/18/23.
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

@testable import CloudFeed
import NextcloudKit
import UIKit

final class MockNextcloudKitService: NextcloudKitServiceProtocol {
    
    enum FavoritesMockAction: String {
        case withData = "mock-favorites"
        case empty = "empty"
        case error = "error"
    }
    
    enum SearchMockAction: String {
        case withData = "mock-search"
        case empty = "empty"
        case error = "error"
    }
    
    var listingFavoritesAction: FavoritesMockAction?
    var searchMediaAction: SearchMockAction?
    
    
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
    
    func downloadPreview(fileNamePath: String, fileNamePreviewLocalPath: String, etagResource: String?) async {
        
    }
    
    func downloadAvatar(userId: String, fileName: String, fileNameLocalPath: String, etag: String?) async -> String? {
        return nil
    }
    
    func searchMedia(account: String, mediaPath: String, toDate: Date, fromDate: Date, limit: Int) async -> (files: [NKFile], error: Bool) {
        
        switch searchMediaAction {
        case .error:
            return ([], true)
        case .empty:
            return ([], false)
        case .withData:
            return mockSearchMedia(fileName: "mock-search")
        default:
            return ([], true)
        }
    }
    
    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> NKError {
        return NKError.success
    }
    
    func listingFavorites() async -> (account: String, files: [NKFile]?) {
        
        switch listingFavoritesAction {
        case .error:
            return ("", nil)
        case .empty:
            return (account: "testuser1 https://cloud.test1.com", [])
        case .withData:
            return mockFavorites(fileName: "mock-favorites")
        default:
            return ("", nil)
        }
    }
    
    func getUserProfile() async -> (profileDisplayName: String, profileEmail: String) {
        return (profileDisplayName: "", profileEmail: "")
    }
}

extension MockNextcloudKitService {
    
    func mockFavorites(fileName: String) -> (account: String, files: [NKFile]?) {
        
        let resultFiles = parseMetadata(fileName: fileName)
        return (account: "testuser1 https://cloud.test1.com", resultFiles)
    }
    
    func mockSearchMedia(fileName: String) -> (files: [NKFile], error: Bool) {
        
        let resultFiles = parseMetadata(fileName: fileName)
        return (resultFiles, false)
    }
    
    func parseMetadata(fileName: String) -> [NKFile] {
        
        let filesJSON = readMocks(fileName: fileName)
        var resultFiles: [NKFile] = []
        
        for fileJSON in filesJSON {

            let file = NKFile()
            file.account = fileJSON["account"] as! String
            file.contentType = fileJSON["contentType"] as! String
            file.favorite = fileJSON["favorite"] as! String == "true" ? true : false
            file.fileName = fileJSON["fileName"] as! String
            file.ocId = fileJSON["ocId"] as! String
            file.path = fileJSON["path"] as! String
            file.serverUrl = fileJSON["serverUrl"] as! String
            file.classFile = fileJSON["classFile"] as! String
            file.livePhotoFile = fileJSON["livePhotoFile"] as! String? ?? ""
            
            if fileJSON["date"] is String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss"
                let date = dateFormatter.date(from: fileJSON["date"] as! String)
                file.date = (date as? NSDate)!
            }
            
            resultFiles.append(file)
        }
        
        return resultFiles
    }
    
    func readMocks(fileName: String) -> [NSDictionary] {
        
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
