//
//  DatabaseManager+Metadata.swift
//  CloudFeed
//
//  Created by Henrik Storch on 30.11.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
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
import RealmSwift
import NextcloudKit
import os.log

class tableMetadata: Object {
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? tableMetadata {
            return self.fileId == object.fileId
                    && self.account == object.account
                    && self.path == object.path
                    && self.fileName == object.fileName
        } else {
            return false
        }
    }
    
    @objc dynamic var account = ""
    @objc dynamic var checksums = ""
    @objc dynamic var chunk: Bool = false
    @objc dynamic var classFile = ""
    @objc dynamic var contentType = ""
    @objc dynamic var creationDate = NSDate()
    @objc dynamic var dataFingerprint = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var directory: Bool = false
    @objc dynamic var downloadURL = ""
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var etag = ""
    @objc dynamic var etagResource = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var fileName = ""
    @objc dynamic var fileNameView = ""
    @objc dynamic var hasPreview: Bool = false
    @objc dynamic var iconName = ""
    @objc dynamic var iconUrl = ""
    @objc dynamic var livePhoto: Bool = false
    @objc dynamic var name = ""
    @objc dynamic var note = ""
    @objc dynamic var ocId = ""
    @objc dynamic var path = ""
    @objc dynamic var quotaUsedBytes: Int64 = 0
    @objc dynamic var quotaAvailableBytes: Int64 = 0
    @objc dynamic var resourceType = ""
    @objc dynamic var serverUrl = ""
    @objc dynamic var size: Int64 = 0
    @objc dynamic var status: Int = 0
    @objc dynamic var uploadDate = NSDate()
    @objc dynamic var url = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userId = ""
    
    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension tableMetadata {
    
    var fileExtension: String { (fileNameView as NSString).pathExtension }
    var fileNoExtension: String { (fileNameView as NSString).deletingPathExtension }
    
    var svg: Bool { fileExtension == "svg" || contentType == "image/svg+xml" }
    var gif: Bool { fileExtension == "gif" || contentType == "image/gif" }
}

extension DatabaseManager {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                       category: String(describing: DatabaseManager.self) + "Metadata")
    
    private func copyObject(metadata: tableMetadata) -> tableMetadata {
        return tableMetadata.init(value: metadata)
    }

    func convertFileToMetadata(_ file: NKFile) -> tableMetadata {

        let metadata = tableMetadata()

        metadata.account = file.account
        metadata.checksums = file.checksums
        metadata.contentType = file.contentType
        if let date = file.creationDate {
            metadata.creationDate = date
        } else {
            metadata.creationDate = file.date
        }
        metadata.dataFingerprint = file.dataFingerprint
        metadata.date = file.date
        metadata.directory = file.directory
        metadata.downloadURL = file.downloadURL
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
        metadata.favorite = file.favorite
        metadata.fileId = file.fileId
        metadata.fileName = file.fileName
        metadata.fileNameView = file.fileName
        metadata.hasPreview = file.hasPreview
        metadata.iconName = file.iconName
        metadata.name = file.name
        metadata.note = file.note
        metadata.ocId = file.ocId
        metadata.path = file.path
        metadata.quotaUsedBytes = file.quotaUsedBytes
        metadata.quotaAvailableBytes = file.quotaAvailableBytes
        metadata.resourceType = file.resourceType
        metadata.serverUrl = file.serverUrl
        metadata.size = file.size
        metadata.classFile = file.classFile
        if let date = file.uploadDate {
            metadata.uploadDate = date
        } else {
            metadata.uploadDate = file.date
        }
        metadata.urlBase = file.urlBase
        metadata.user = file.user
        metadata.userId = file.userId

        return metadata
    }
    
    @discardableResult
    func addMetadata(_ metadata: tableMetadata) -> tableMetadata? {

        let realm = try! Realm()
        let result = tableMetadata.init(value: metadata)

        do {
            try realm.write {
                realm.add(result, update: .all)
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
            return nil
        }
        return tableMetadata.init(value: result)
    }
    
    func convertFilesToMetadatas(_ files: [NKFile]) async -> [tableMetadata] {

        var metadatas: [tableMetadata] = []

        for file in files {
            metadatas.append(convertFileToMetadata(file))
        }

        //Handle live photo
        var metadataOutput: [tableMetadata] = []
        metadatas = metadatas.sorted(by: {$0.fileNameView < $1.fileNameView})

        for index in metadatas.indices {
            let metadata = metadatas[index]
            if index < metadatas.count - 1,
                metadata.fileNoExtension == metadatas[index+1].fileNoExtension,
                ((metadata.classFile == NKCommon.TypeClassFile.image.rawValue && metadatas[index+1].classFile == NKCommon.TypeClassFile.video.rawValue) || (metadata.classFile == NKCommon.TypeClassFile.video.rawValue && metadatas[index+1].classFile == NKCommon.TypeClassFile.image.rawValue)){
                metadata.livePhoto = true
                metadatas[index+1].livePhoto = true
            }
            metadataOutput.append(metadata)
        }

        return metadataOutput
    }
    
    func getMetadata(predicate: NSPredicate) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }
    
    func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }
    
    func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let ocId = ocId else { return nil }
        guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else { return nil }

        return tableMetadata.init(value: result)
    }
    
    func getMetadatas(predicate: NSPredicate) -> [tableMetadata] {

        let realm = try! Realm()
        realm.refresh()

        let results = realm.objects(tableMetadata.self).filter(predicate)

        return Array(results.map { tableMetadata.init(value: $0) })
    }
    
    func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {

        let realm = try! Realm()
        var classFile = metadata.classFile
        var fileName = (metadata.fileNameView as NSString).deletingPathExtension

        if !metadata.livePhoto {
            return nil
        }

        if classFile == NKCommon.TypeClassFile.image.rawValue {
            classFile = NKCommon.TypeClassFile.video.rawValue
            fileName = fileName + ".mov"
        } else {
            classFile = NKCommon.TypeClassFile.image.rawValue
            fileName = fileName + ".jpg"
        }
        
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView CONTAINS[cd] %@ AND ocId != %@ AND classFile == %@", 
                                    metadata.account, metadata.serverUrl, fileName, metadata.ocId, classFile)

        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }
    
    func paginateFavoriteMetadata(account: String, startServerUrl: String) -> [tableMetadata] {
        
        let predicate = NSPredicate(format: "favorite == true AND account == %@ AND serverUrl BEGINSWITH %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false) ",
                                    account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)

        return paginateMetadata(predicate: predicate, offsetDate: nil, offsetName: nil)
    }
    
    func paginateFavoriteMetadata(account: String, startServerUrl: String, offsetDate: Date, offsetName: String) -> [tableMetadata] {
        
        let predicate = NSPredicate(format: "favorite == true AND account == %@ AND serverUrl BEGINSWITH %@ AND date <= %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false) ",
                                    account, startServerUrl, offsetDate as NSDate,
                                    NKCommon.TypeClassFile.image.rawValue)

        return paginateMetadata(predicate: predicate, offsetDate: offsetDate, offsetName: offsetName)
    }
    
    func paginateFavoriteMetadata(account: String, startServerUrl: String, fromDate: Date, toDate: Date) -> [tableMetadata] {
        
        let predicate = NSPredicate(format: "favorite == true AND account == %@ AND serverUrl BEGINSWITH %@ AND date >= %@ AND date <= %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false) ",
                                    account, startServerUrl, fromDate as NSDate, toDate as NSDate,
                                    NKCommon.TypeClassFile.image.rawValue)
        
        return paginateMetadata(predicate: predicate, offsetDate: nil, offsetName: nil)
    }
    
    func paginateFavoriteMetadata(account: String, startServerUrl: String, fromDate: Date, toDate: Date, offsetDate: Date, offsetName: String) -> [tableMetadata] {
        
        let predicate = NSPredicate(format: "favorite == true AND account == %@ AND serverUrl BEGINSWITH %@ AND date >= %@ AND date <= %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false) ",
                                    account, startServerUrl, fromDate as NSDate, toDate as NSDate,
                                    NKCommon.TypeClassFile.image.rawValue)
        
        return paginateMetadata(predicate: predicate, offsetDate: offsetDate, offsetName: offsetName)
    }
    
    func paginateMetadata(account: String, startServerUrl: String, fromDate: Date, toDate: Date, offsetDate: Date?, offsetName: String?) -> [tableMetadata] {

        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND date >= %@ AND date <= %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false) ",
                                    account, startServerUrl, fromDate as NSDate, toDate as NSDate,
                                    NKCommon.TypeClassFile.image.rawValue)
        
        return paginateMetadata(predicate: predicate, offsetDate: offsetDate, offsetName: offsetName)
    }
    
    func fetchFavoriteMetadata(account: String, startServerUrl: String) -> [tableMetadata] {
        
        let predicate = NSPredicate(format: "favorite == true AND account == %@ AND serverUrl BEGINSWITH %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false) ",
                                    account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        
        return fetchMetadata(predicate: predicate)
    }
    
    func fetchFilteredFavoriteMetadata(account: String, startServerUrl: String, fromDate: Date, toDate: Date) -> [tableMetadata] {
        
        let predicate = NSPredicate(format: "favorite == true AND account == %@ AND serverUrl BEGINSWITH %@ AND date >= %@ AND date <= %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false) ",
                                    account, startServerUrl, fromDate as NSDate, toDate as NSDate,
                                    NKCommon.TypeClassFile.image.rawValue)
        
        return fetchMetadata(predicate: predicate)
    }
    
    func fetchMetadata(predicate: NSPredicate) -> [tableMetadata] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "date", ascending: false),
                              SortDescriptor(keyPath:  "fileNameView", ascending: false)]
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)
        
        return Array(results.map { tableMetadata.init(value: $0) })
    }
    
    func paginateMetadata(predicate: NSPredicate, offsetDate: Date?, offsetName: String?) -> [tableMetadata] {
    
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "date", ascending: false),
                              SortDescriptor(keyPath:  "fileNameView", ascending: false)]
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)
        
        if offsetName == nil || offsetDate == nil {
            if results.count > 0 {
                return Array(results.prefix(Global.shared.pageSize).map { tableMetadata.init(value: $0) })
            } else {
                return []
            }
        }
        
        var metadatas: [tableMetadata] = []
        
        for index in results.indices {
            let metadata = results[index]
            
            if metadata.date as Date == offsetDate {
                if metadata.fileNameView < offsetName! {
                    metadatas.append(tableMetadata.init(value: metadata))
                }
            } else {
                metadatas.append(tableMetadata.init(value: metadata))
            }
            
            if metadatas.count == Global.shared.pageSize {
                break
            }
        }
        
        return metadatas
    }

    func processMetadatasMedia(predicate: NSPredicate) {
        
        //pull all metadata in order to flag live photos. the 2 file dates do not have to be the same or even near each other
        let realm = try! Realm()

        do {
            try realm.write {
                let sortProperties = [SortDescriptor(keyPath:  "fileNameView", ascending: false)]
                let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)
                
                for index in results.indices {
                    let metadata = results[index]
                    if index < results.count - 1, metadata.fileNoExtension == results[index+1].fileNoExtension {
                        if !metadata.livePhoto {
                            metadata.livePhoto = true
                        }
                        if !results[index+1].livePhoto {
                            results[index+1].livePhoto = true
                        }
                    }
                }
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }
    
    func processMetadatas(_ metadatas: [tableMetadata], metadatasResult: [tableMetadata]) -> (added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata]) {
        
        var updatedOcIds: [String] = []
        var addedOcIds: [String] = []
        
        var added: [tableMetadata] = []
        var updated: [tableMetadata] = []
        var deleted: [tableMetadata] = []
        
        do {

            let realm = try Realm()
            try realm.write {
                
                //delete
                for metadataResult in metadatasResult {
                    if metadatas.firstIndex(where: { $0.ocId == metadataResult.ocId }) == nil {
                        if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", metadataResult.ocId)).first {
                            deleted.append(tableMetadata.init(value: result))
                            realm.delete(result)
                        }
                    }
                }
                
                //add and update
                for metadata in metadatas {

                    if let result = metadatasResult.first(where: { $0.ocId == metadata.ocId }) {
                        
                        if result.status == Global.shared.metadataStatusNormal && (result.etag != metadata.etag || result.fileNameView != metadata.fileNameView || result.date != metadata.date || result.hasPreview != metadata.hasPreview || result.note != metadata.note || result.favorite != metadata.favorite) {
                            
                            updatedOcIds.append(metadata.ocId)
                            realm.add(tableMetadata.init(value: metadata), update: .all)
                        }
                    } else {
                        // add new
                        addedOcIds.append(metadata.ocId)
                        realm.add(tableMetadata.init(value: metadata), update: .all)
                    }
                }
            }
            
            for ocId in addedOcIds {
                if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                    added.append(tableMetadata.init(value: result))
                }
            }
            
            for ocId in updatedOcIds {
                if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                    updated.append(tableMetadata.init(value: result))
                }
            }
            
            return (added, updated, deleted)
    
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }

        return ([], [], [])
    }
    
    func setMetadataFavorite(ocId: String, favorite: Bool) -> tableMetadata? {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.favorite = favorite
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
        
        return getMetadataFromOcId(ocId)
    }
    
    func updateMetadatasFavorite(account: String, metadatas: [tableMetadata]) {

        let realm = try! Realm()

        do {
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND favorite == true", account)
                for result in results {
                    result.favorite = false
                }
                for metadata in metadatas {
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }
}
