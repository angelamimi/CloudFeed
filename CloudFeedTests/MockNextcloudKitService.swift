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
    
    func setup() {
        
    }
    
    func appendSession(account: String, urlBase: String, user: String, userId: String, password: String, userAgent: String, nextcloudVersion: Int, groupIdentifier: String) {
        
    }
    
    func loginPoll(token: String, endpoint: String) async -> (urlBase: String, user: String, appPassword: String)? {
        return nil
    }
    
    func getLoginFlowV2(url: String) async -> (token: String, endpoint: String, login: String, serverVersion: Int)? {
        return nil
    }

    func setupAccount(account: String, user: String, userId: String, password: String, urlBase: String) {
    }
    
    func getDirectDownload(metadata: CloudFeed.Metadata) async -> URL? {
        return nil
    }
    
    func getCapabilities(account: String) async -> (account: String?, data: Data?) {
        return (account: nil, data: nil)
    }
    
    func download(metadata: CloudFeed.Metadata, selector: String, serverUrlFileName: String, fileNameLocalPath: String) async -> Bool {
        return true
    }
    
    func downloadPreview(account: String, fileId fileNamePath: String, previewPath: String, previewWidth: Int, previewHeight: Int, iconPath: String, etagResource: String?) async -> String? {
        return etagResource
    }
    
    func downloadAvatar(account: String, userId: String, fileName: String, fileNameLocalPath: String, etag: String?, avatarSize: Int, avatarSizeRounded: Int) async -> String? {
        return nil
    }
    
    func searchMedia(account: String, mediaPath: String, toDate: Date, fromDate: Date, limit: Int) async -> (files: [CloudFeed.Metadata], error: Bool) {
        return mockSearchMedia(fileName: "mock-search")
    }
    
    func setFavorite(fileName: String, favorite: Bool, ocId: String, account: String) async -> Bool {
        return true
    }
    
    func listingFavorites(account: String) async -> (account: String, files: [CloudFeed.Metadata]?) {
        return mockFavorites(fileName: "mock-favorites")
    }
    
    func getUserProfile(account: String) async -> (profileDisplayName: String, profileEmail: String) {
        return (profileDisplayName: "", profileEmail: "")
    }
}

extension MockNextcloudKitService {
    
    func mockFavorites(fileName: String) -> (account: String, files: [CloudFeed.Metadata]?) {
        
        let resultFiles = parseMetadata(fileName: fileName)
        return (account: "testuser1 https://cloud.test1.com", resultFiles)
    }
    
    func mockSearchMedia(fileName: String) -> (files: [CloudFeed.Metadata], error: Bool) {
        let resultFiles = parseMetadata(fileName: fileName)
        return (resultFiles, false)
    }
    
    func parseMetadata(fileName: String) -> [CloudFeed.Metadata] {
        
        let filesJSON = readMocks(fileName: fileName)
        var resultFiles: [CloudFeed.Metadata] = []
        
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
                file.date = date!
            }
            
            resultFiles.append(CloudFeed.Metadata.init(file: file))
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
