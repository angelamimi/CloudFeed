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

struct StoreUtility: Sendable {
    
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
    
    var certificatesDirectory: URL? {
        
        let directory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        
        do {
            let url = directory!.appendingPathComponent( "Certificates", isDirectory: true)
            
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
            return url
        } catch  {
            return nil
        }
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
    
    func fileExists(_ metadata: Metadata) -> Bool {
        
        let filePath: String! = getCachePath(metadata.ocId, metadata.fileNameView)
        
        do {
            let size: UInt64 = try FileManager.default.attributesOfItem(atPath: filePath)[FileAttributeKey.size] as? UInt64 ?? 0
            return size == metadata.size;
        } catch { }
        
        return false
    }
    
    func cleanupFileCache() {
        
        guard let cachePath = getFileCachePath(), let fileCacheDirectory = URL(string: cachePath) else { return }
        let maxFileCache = 1024 * 1024 * Global.shared.fileCacheLimit
        let deleteLimit = maxFileCache / 2 //delete half the cache
        var totalSize = FileSystemUtility.getDirectorySize(directory: cachePath)
        
        guard totalSize > maxFileCache else {
            return
        }
        
        //Self.logger.debug("cleanupFileCache() - totalSize: \(totalSize) maxFileCache: \(maxFileCache) file cache path: \(cachePath) ")
        
        let fileManager = FileManager.default
        let keys = [URLResourceKey.contentAccessDateKey, URLResourceKey.totalFileAllocatedSizeKey]
        
        guard let enumerator = fileManager.enumerator(at: fileCacheDirectory, includingPropertiesForKeys: keys, options: .skipsHiddenFiles) else { return }
        guard let urls = enumerator.allObjects as? [URL] else { return }
        
        let sorted = urls.sorted(by: { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
            
            return date1.compare(date2) == .orderedAscending
        })
        
        for url in sorted {
            guard let resourceValues = try? url.resourceValues(forKeys: [.contentAccessDateKey, .totalFileAllocatedSizeKey]) else { continue }
            //guard let contentAccessDate = resourceValues.contentAccessDate else { continue }
            guard let size = resourceValues.totalFileAllocatedSize else { continue }
            
            //remove file if over the limit
            if totalSize > deleteLimit {
                do {
                    //Self.logger.debug("cleanupFileCache() - \(contentAccessDate.formatted(date: .abbreviated, time: .standard)) \(size)")
                    try fileManager.removeItem(at: url)
                    removeParentDirectoryIfEmpty(fileDirectory: url)
                } catch let error as NSError {
                    Self.logger.error("Failed to remove from cache with error: \(error.localizedDescription)")
                }
                totalSize -= Int64(size)
            } else {
                break
            }
        }
    }
    
    private func removeParentDirectoryIfEmpty(fileDirectory: URL) {
        
        let directory = fileDirectory.deletingLastPathComponent()
        guard directory.absoluteString != getFileCachePath() else { return }
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: .skipsHiddenFiles)
            if contents.isEmpty {
                try? fileManager.removeItem(at: directory)
            }
        } catch let error {
            Self.logger.error("Cleanup of empty cache directory failed with error: \(error.localizedDescription)")
        }
    }
    
    func clearCache() async {
        
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

    func removeDocumentsDirectory() async {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path)
        if paths.count > 0 {
            try? FileManager.default.removeItem(atPath: paths[0])
        }
    }
    
    func deleteAllChainStore() {
        let keychain = Keychain(service: Global.shared.keyChain)
        try? keychain.removeAll()
    }
    
    func copyFile(atPath: String, toPath: String) -> Bool {

        if FileManager.default.fileExists(atPath: toPath) {
            try? FileManager.default.removeItem(atPath: toPath)
        }

        do {
            try FileManager.default.copyItem(atPath: atPath, toPath: toPath)
            return true
        } catch {
            return false
        }
    }
}
