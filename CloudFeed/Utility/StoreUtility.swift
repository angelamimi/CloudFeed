//
//  StoreUtility.swift
//  CloudFeed
//
//  Created by Marino Faggiana on 28/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import Foundation
import ImageIO
import KeychainAccess
import os.log

class StoreUtility {
    
    static let shared: StoreUtility = {
        let instance = StoreUtility()
        return instance
    }()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: StoreUtility.self)
    )
    
    static func getPassword(_ account: String!) -> String! {
        let key = "password" + account
        return Keychain(service: Global.shared.keyChain)[key]
    }
    
    static func setPassword(_ account: String, password: String?) {
        let key = "password" + account
        Keychain(service: Global.shared.keyChain)[key] = password
    }
    
    static func transformedSize(_ value: Int64) -> String {
        let string = ByteCountFormatter.string(fromByteCount: value, countStyle: .binary)
        return string
    }
    
    static func getDirectoryGroup() -> URL? {
        let path = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Global.shared.groupIdentifier)
        return path
    }
    
    static func getDirectoryUserData() -> String {
        if let group = StoreUtility.getDirectoryGroup() {
            let path = group.appendingPathComponent(Global.shared.userDataDirectory).path
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            }
            return path
        }
        return ""
    }
    
    static func removeDirectoryUserData() {
        try? FileManager.default.removeItem(atPath: StoreUtility.getDirectoryUserData())
    }
    
    static func getDirectoryProviderStorage() -> String? {
        if let group = getDirectoryGroup() {
            let path = group.appendingPathComponent(Global.shared.providerStorage).path
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            }
            return path
        }
        return nil
    }
    
    static func getDirectoryProviderStorageOcId(_ ocId: String?) -> String? {
        let path = "\(getDirectoryProviderStorage() ?? "")/\(ocId ?? "")"

        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }

        return path
    }
    
    public static func getDirectoryProviderStorageOcId(_ ocId: String?, fileNameView: String?) -> String? {
        
        let fileNamePath = "\(getDirectoryProviderStorageOcId(ocId) ?? "")/\(fileNameView ?? "")"
        
        // if do not exists create file 0 length
        // causes files with lenth 0 to never be downloaded, because already exist
        // also makes it impossible to delete any file with length 0 (from cache)
        if !FileManager.default.fileExists(atPath: fileNamePath) {
            FileManager.default.createFile(atPath: fileNamePath, contents: nil, attributes: nil)
        }
        
        return fileNamePath
    }
    
    static func getDirectoryProviderStorageIconOcId(_ ocId: String?, etag: String?) -> String {
        return "\(self.getDirectoryProviderStorageOcId(ocId) ?? "")/\(etag ?? "").small.\(Global.shared.extensionPreview)"
    }

    static func getDirectoryProviderStoragePreviewOcId(_ ocId: String?, etag: String?) -> String {
        return "\(self.getDirectoryProviderStorageOcId(ocId) ?? "")/\(etag ?? "").preview.\(Global.shared.extensionPreview)"
    }
    
    static func removeGroupDirectoryProviderStorage() {
        guard let path = StoreUtility.getDirectoryProviderStorage() else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
    
    static func initStorage() {
        
        var path : String?
        let dirGroup = StoreUtility.getDirectoryGroup()
        
        path = dirGroup?.appendingPathComponent(Global.shared.databaseDirectory).path
        do {
            if !FileManager.default.fileExists(atPath: path!) {
                try FileManager.default.createDirectory(atPath: path!, withIntermediateDirectories: true)
            }
        } catch {
            Self.logger.error("initDirectories() - path: \(path ?? "nil") error: \(error)")
        }
        
        path = dirGroup?.appendingPathComponent(Global.shared.userDataDirectory).path
        do {
            if !FileManager.default.fileExists(atPath: path!) {
                try FileManager.default.createDirectory(atPath: path!, withIntermediateDirectories: true)
            }
        } catch {
            Self.logger.error("initDirectories() - path: \(path ?? "nil") error: \(error)")
        }
    }
    
    static func initTemporaryDirectory() {
        
        let path = NSTemporaryDirectory()
        
        do {
            if !FileManager.default.fileExists(atPath: path) {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            }
        } catch {
            Self.logger.error("initTemporaryDirectory() - path: \(path) error: \(error)")
        }
    }
    
    static func removeDocumentsDirectory() {
        guard let path = StoreUtility.getDocumentDirectoryPath() else { return }
        //Self.logger.debug("removeDocumentsDirectory() - path: \(path)")
        try? FileManager.default.removeItem(atPath: path)
    }
    
    private static func getDocumentDirectoryPath() -> String? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path)
        //Self.logger.debug("getDocumentDirectoryPath() - path: \(paths[0])")
        return paths[0]
    }
    
    static func buildFileNamePath(metadataFileName: String, serverUrl: String, urlBase: String, userId: String, account: String) -> String {
        
        let homeServer = urlBase + Global.shared.davLocation + userId
        
        var fileName = "\(serverUrl.replacingOccurrences(of: homeServer, with: ""))/\(metadataFileName)"

        if fileName.hasPrefix("/") {
            fileName = (fileName as NSString).substring(from: 1)
        }
        
        return fileName
    }
    
    static func getFormattedDate(_ date: Date) -> String {
        
        var title: String = ""

        if date == StoreUtility.datetimeWithOutTime(Date.distantPast) {
            title = ""
        } else {
            if let style = DateFormatter.Style(rawValue: 0) {
                title = DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: style)
            }
        }
        
        return title
    }
    
    static func datetimeWithOutTime(_ date: Date?) -> Date? {
        
        var datDate = date
        if datDate == nil {
            return nil
        }

        var comps: DateComponents? = nil
        if let datDate {
            comps = Calendar.current.dateComponents([.year, .month, .day], from: datDate)
        }
        if let comps {
            datDate = Calendar.current.date(from: comps)
        }

        return datDate
    }
    
    static func setExif(_ metadata: tableMetadata, withCompletionHandler completition: @escaping (_ data: NSMutableDictionary) -> Void) {

        let details = NSMutableDictionary()
        
        if (metadata.classFile != "image") || !StoreUtility.fileProviderStorageExists(metadata) {
            completition(details)
            return
        }
        
        let url = URL(fileURLWithPath: StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        let originalSource = CGImageSourceCreateWithURL(url as CFURL, nil)
        if originalSource == nil {
            completition(details)
            return
        }
        
        let fileProperties = CGImageSourceCopyProperties(originalSource!, nil)
        if fileProperties == nil {
            completition(details)
            return
        }
        
        let properties = NSMutableDictionary(dictionary: fileProperties!)

        if let valFileSize = properties[kCGImagePropertyFileSize] {
            //fileSize = valFileSize as! Int
            details[kCGImagePropertyFileSize] = valFileSize
        }
        
        //Self.logger.debug("setExif() - fileSize: \(fileSize)")
        
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource!, 0, nil)
        if imageProperties == nil {
            completition(details)
            return
        }
        
        let imageDict = NSMutableDictionary(dictionary: imageProperties!)
        
        if let width = imageDict[kCGImagePropertyPixelWidth], let height = imageDict[kCGImagePropertyPixelHeight] {
            details[kCGImagePropertyPixelWidth] = width
            details[kCGImagePropertyPixelHeight] = height
        }
        
        if let dpiWidth = imageDict[kCGImagePropertyDPIWidth], let dpiHeight = imageDict[kCGImagePropertyDPIHeight] {
            details[kCGImagePropertyDPIWidth] = dpiWidth
            details[kCGImagePropertyDPIHeight] = dpiHeight
        }
        
        if let colorModel = imageDict[kCGImagePropertyColorModel] {
            details[kCGImagePropertyColorModel] = colorModel
        }
        
        if let depth = imageDict[kCGImagePropertyDepth] {
            details[kCGImagePropertyDepth] = depth
        }
        
        if let profile = imageDict[kCGImagePropertyProfileName] {
            details[kCGImagePropertyProfileName] = profile
        }
        
        /*for (key, value) in imageDict {
            print(key)
        }*/
        
        if let exif = imageDict[kCGImagePropertyExifDictionary] as? [NSString: AnyObject] {
            
            /*for (key, value) in exif {
                print(key)
            }*/
            
            if let date = exif[kCGImagePropertyExifDateTimeOriginal] {
                details[kCGImagePropertyExifDateTimeOriginal] = date
            }
            
            if let lensMake = exif[kCGImagePropertyExifLensMake] {
                details[kCGImagePropertyExifLensMake] = lensMake
            }
            
            if let lensModel = exif[kCGImagePropertyExifLensModel] {
                details[kCGImagePropertyExifLensModel] = lensModel
            }
            
            if let aperture = exif[kCGImagePropertyExifFNumber] as? Double {
                details[kCGImagePropertyExifFNumber] = aperture
            }
            
            if let exposure = exif[kCGImagePropertyExifExposureBiasValue] as? Int {
                details[kCGImagePropertyExifExposureBiasValue] = exposure
            }
            
            if let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Int])?[0] {
                details[kCGImagePropertyExifISOSpeedRatings] = iso
            }
            
            if let brightness = exif[kCGImagePropertyExifBrightnessValue] as? Double {
                details[kCGImagePropertyExifBrightnessValue] = brightness
            }
        }
        
        completition(details)
    }
    
    static func fileProviderStorageExists(_ tableMetadata: tableMetadata) -> Bool {
        
        let fileNameViewPath: String! = StoreUtility.getDirectoryProviderStorageOcId(tableMetadata.ocId, fileNameView: tableMetadata.fileNameView)
        
        do {
            let fileNameViewSize: UInt64 = try FileManager.default.attributesOfItem(atPath: fileNameViewPath)[FileAttributeKey.size] as? UInt64 ?? 0
            return fileNameViewSize == tableMetadata.size;
        } catch { }
        
        return false
    }
    
    static func getExtension(_ fileName: String?) -> String? {
        
        let fileNameArray = fileName?.components(separatedBy: CharacterSet(charactersIn: "."))
        var ext = "\(fileNameArray?.last ?? "")"
        
        ext = ext.uppercased()
        
        return ext
    }
    
    static func fileProviderStorageSize(_ ocId: String?, fileNameView: String?) -> Int64 {
        
        let fileNamePath : String = StoreUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView) ?? ""

        var fileSize: Int64
        do {
            fileSize = Int64((try FileManager.default.attributesOfItem(atPath: fileNamePath)[FileAttributeKey.size] as? UInt64 ?? 0))
            return fileSize
        } catch {
        }

        return 0
    }
    
    static func fileProviderStoragePreviewIconExists(_ ocId: String?, etag: String?) -> Bool {
        
        let fileNamePathPreview = getDirectoryProviderStoragePreviewOcId(ocId, etag: etag)
        let fileNamePathIcon = getDirectoryProviderStorageIconOcId(ocId, etag: etag)
        
        var fileSizePreview: UInt64? = nil
        do {
            fileSizePreview = try FileManager.default.attributesOfItem(atPath: fileNamePathPreview)[FileAttributeKey.size] as? UInt64 ?? 0
        } catch {
        }
        
        var fileSizeIcon: UInt64? = nil
        do {
            fileSizeIcon = try FileManager.default.attributesOfItem(atPath: fileNamePathIcon)[FileAttributeKey.size] as? UInt64 ?? 0
        } catch {
        }
        
        if (fileSizePreview ?? 0) > 0 && (fileSizeIcon ?? 0) > 0 {
            return true
        } else {
            return false
        }
    }
    
    static func removeTemporaryDirectory() {
        try? FileManager.default.removeItem(atPath: NSTemporaryDirectory())
    }
    
    static func deleteAllChainStore() {
        let keychain = Keychain(service: Global.shared.keyChain)
        try? keychain.removeAll()
    }
}
