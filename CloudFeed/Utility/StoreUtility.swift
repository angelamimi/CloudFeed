//
//  StoreUtility.swift
//  CloudFeed
//
//  Created by Marino Faggiana on 3/7/24.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
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

import UIKit
import ImageIO
import KeychainAccess
import os.log

//@MainActor
class StoreUtility {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: StoreUtility.self)
    )
    
    var cacheDirectory: String {
        guard let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
            return ""
        }
        return path
    }
    
    func getPassword(_ account: String!) -> String! {
        let key = "password" + account
        return Keychain(service: Global.shared.keyChain)[key]
    }
    
    func setPassword(_ account: String, password: String?) {
        let key = "password" + account
        Keychain(service: Global.shared.keyChain)[key] = password
    }
    
    @MainActor
    func getMediaColumnCount() -> Int! {

        let defaultCount = UIDevice.current.userInterfaceIdiom == .pad ? Global.shared.layoutColumnCountDefaultPad : Global.shared.layoutColumnCountDefault
        
        guard try! Keychain(service: Global.shared.keyChain).contains("mediaColumnCount") else {
            setMediaColumnCount(defaultCount)
            return defaultCount
        }
        
        if let value = Keychain(service: Global.shared.keyChain)["mediaColumnCount"], let result = Int(value) {
            return result
        }
        
        return defaultCount
    }
    
    func setMediaColumnCount(_ count: Int) {
        Keychain(service: Global.shared.keyChain)["mediaColumnCount"] = String(count)
    }

    @MainActor
    func getFavoriteColumnCount() -> Int! {
        
        let defaultCount = UIDevice.current.userInterfaceIdiom == .pad ? Global.shared.layoutColumnCountDefaultPad : Global.shared.layoutColumnCountDefault
        
        guard try! Keychain(service: Global.shared.keyChain).contains("favoriteColumnCount") else {
            //let defaultCount = Global.shared.layoutColumnCountDefault
            setFavoriteColumnCount(defaultCount)
            return defaultCount
        }
        
        if let value = Keychain(service: Global.shared.keyChain)["favoriteColumnCount"], let result = Int(value) {
            return result
        }
        
        return defaultCount
    }
    
    func setFavoriteColumnCount(_ count: Int) {
        Keychain(service: Global.shared.keyChain)["favoriteColumnCount"] = String(count)
    }
    
    func getMediaLayoutType() -> String! {
        
        guard try! Keychain(service: Global.shared.keyChain).contains("mediaLayoutType") else {
            let defaultLayoutType = Global.shared.layoutTypeSquare
            setMediaLayoutType(defaultLayoutType)
            return defaultLayoutType
        }
        
        return Keychain(service: Global.shared.keyChain)["mediaLayoutType"]
    }
    
    func setMediaLayoutType(_ type: String) {
        Keychain(service: Global.shared.keyChain)["mediaLayoutType"] = type
    }
    
    func getFavoriteLayoutType() -> String! {
        
        guard try! Keychain(service: Global.shared.keyChain).contains("favoriteLayoutType") else {
            let defaultLayoutType = Global.shared.layoutTypeSquare
            setMediaLayoutType(defaultLayoutType)
            return defaultLayoutType
        }
        
        return Keychain(service: Global.shared.keyChain)["favoriteLayoutType"]
    }
    
    func setFavoriteLayoutType(_ type: String) {
        Keychain(service: Global.shared.keyChain)["favoriteLayoutType"] = type
    }
    
    func getCacheDirectoryURL() -> URL? {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    
    func getUserDirectory() -> String {
        
        let path = cacheDirectory + "/user"
        
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        
        return path
    }
    
    func getFileCachePath() -> String? {
        
        guard let cacheURL = getCacheDirectoryURL() else { return nil }
        let filePath = cacheURL.appendingPathComponent("files").path
        
        if !FileManager.default.fileExists(atPath: filePath) {
            try? FileManager.default.createDirectory(atPath: filePath, withIntermediateDirectories: true, attributes: nil)
        }
        
        return filePath
    }
    
    private func getCachePathForOcId(_ ocId: String) -> String? {
        
        let path = "\(getFileCachePath() ?? "")/\(ocId)"
        
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }

        return path
    }
    
    func getPreviewPath(_ ocId: String, _ etag: String) -> String {
        return "\(self.getCachePathForOcId(ocId) ?? "")/\(etag).small.\(Global.shared.extensionPreview)"
    }
    
    func getIconPath(_ ocId: String, _ etag: String) -> String {
        return "\(self.getCachePathForOcId(ocId) ?? "")/\(etag).ico.\(Global.shared.extensionPreview)"
    }
    
    func getImagePath(_ ocId: String, _ etag: String) -> String {
        return "\(self.getCachePathForOcId(ocId) ?? "")/\(etag).full.\(Global.shared.extensionPreview)"
    }
    
    func getCachePath(_ ocId: String, _ fileNameView: String) -> String? {
        
        let fileNamePath = "\(getCachePathForOcId(ocId) ?? "")/\(fileNameView)"

        if !FileManager.default.fileExists(atPath: fileNamePath) {
            FileManager.default.createFile(atPath: fileNamePath, contents: nil)
        }
        
        return fileNamePath
    }
    
    //func fileExists(_ metadata: tableMetadata) -> Bool {
    func fileExists(_ metadata: Metadata) -> Bool {
        
        let filePath: String! = getCachePath(metadata.ocId, metadata.fileNameView)
        
        do {
            let size: UInt64 = try FileManager.default.attributesOfItem(atPath: filePath)[FileAttributeKey.size] as? UInt64 ?? 0
            return size == metadata.size;
        } catch { }
        
        return false
    }
    
    func clearCache() {
        
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        do {
            let contents = try fileManager.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

            for content in contents {
                do {
                    try fileManager.removeItem(at: content)
                } catch let error as NSError {
                    Self.logger.error("Failed to clear from cache with error: \(error.localizedDescription)")
                }
            }
        } catch let error {
            Self.logger.error("Failed to clear cache with error: \(error.localizedDescription)")
        }
    }
    
    func fileSize(_ ocId: String, _ fileNameView: String) -> Int64 {
        
        guard let path = getCachePath(ocId, fileNameView) else { return 0 }

        var fileSize: Int64
        do {
            fileSize = Int64((try FileManager.default.attributesOfItem(atPath: path)[FileAttributeKey.size] as? UInt64 ?? 0))
            return fileSize
        } catch {
        }

        return 0
    }
    
    func previewExists(_ ocId: String, _ etag: String) -> Bool {
        
        let path = getPreviewPath(ocId, etag)
        
        var fileSizePreview: UInt64? = nil
        do {
            fileSizePreview = try FileManager.default.attributesOfItem(atPath: path)[FileAttributeKey.size] as? UInt64 ?? 0
        } catch {
        }
        
        if (fileSizePreview ?? 0) > 0 {
            return true
        } else {
            return false
        }
    }

    func removeDocumentsDirectory() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path)
        if paths.count > 0 {
            try? FileManager.default.removeItem(atPath: paths[0])
        }
    }
    
    /*func removeTemporaryDirectory() {
        try? FileManager.default.removeItem(atPath: NSTemporaryDirectory())
    }*/
    
    func deleteAllChainStore() {
        let keychain = Keychain(service: Global.shared.keyChain)
        try? keychain.removeAll()
    }
}
