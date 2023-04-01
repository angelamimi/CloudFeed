//
//  StoreUtility.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//

import Foundation
import ImageIO
import KeychainAccess
import os.log

class StoreUtility {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: StoreUtility.self)
    )
    
    static let shared: StoreUtility = {
        let instance = StoreUtility()
        return instance
    }()
    
    static func getPassword(_ account: String!) -> String! {
        let key = "password" + account
        return Keychain(service: Global.shared.keyChain)[key]
    }
    
    static func setPassword(_ account: String, password: String?) {
        let key = "password" + account
        Keychain(service: Global.shared.keyChain)[key] = password
    }
    
    static func getDirectoryGroup() -> URL? {
        let path = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Global.shared.groupIdentifier)
        return path
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
        
        /*path = StoreUtility.getDirectoryDocuments()
        
        Self.logger.debug("createDirectoryStandard() - path: \(path ?? "NONE")")

        do {
            if !FileManager.default.fileExists(atPath: path!) {
                try FileManager.default.createDirectory(atPath: path!, withIntermediateDirectories: true)
            }
        } catch {
            //TODO: Handle error
            Self.logger.error("createDirectoryStandard() - path: \(path ?? "nil") error: \(error.localizedDescription)")
        }*/
        
        path = dirGroup?.appendingPathComponent(Global.shared.databaseDirectory).path
        do {
            if !FileManager.default.fileExists(atPath: path!) {
                try FileManager.default.createDirectory(atPath: path!, withIntermediateDirectories: true)
            }
        } catch {
            //TODO: Handle error
            Self.logger.error("initDirectories() - path: \(path ?? "nil") error: \(error.localizedDescription)")
        }
        
        /*
        path = dirGroup?.appendingPathComponent(Global.shared.appUserData).path
        do {
            if !FileManager.default.fileExists(atPath: path!) {
                try FileManager.default.createDirectory(atPath: path!, withIntermediateDirectories: true)
            }
        } catch {
            //TODO: Handle error
            Self.logger.error("initDirectories() - path: \(path ?? "nil") error: \(error.localizedDescription)")
        }
         */
    }
    
    static func removeDocumentsDirectory() {
        guard let path = StoreUtility.getDirectoryDocuments() else { return }
        Self.logger.debug("removeDocumentsDirectory() - path: \(path)")
        try? FileManager.default.removeItem(atPath: path)
    }
    
    // Return the path of directory Documents -> NSDocumentDirectory
    static func getDirectoryDocuments() -> String? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path)
        Self.logger.debug("getDirectoryDocuments() - path: \(paths[0])")
        return paths[0]
    }
    
    static func returnFileNamePath(metadataFileName: String, serverUrl: String, urlBase: String, userId: String, account: String) -> String {
        
        //TODO: Hardcoded
        let homeServer = urlBase + "/remote.php/dav/files/" + userId
        
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
}
