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

struct Metadata: Hashable {
    var account: String
    var checksums: String
    var chunk: Bool
    var classFile: String
    var contentType: String
    var creationDate: NSDate
    var dataFingerprint: String
    var date: NSDate
    var directory: Bool
    var downloadURL: String
    var e2eEncrypted: Bool
    var etag: String
    var etagResource: String
    var favorite: Bool
    var fileId: String
    var fileName: String
    var fileNameView: String
    var hasPreview: Bool
    var iconName: String
    var iconUrl: String
    var livePhotoFile: String
    var name: String
    var note: String
    var ocId: String
    var path: String
    var quotaUsedBytes: Int64
    var quotaAvailableBytes: Int64
    var resourceType: String
    var serverUrl: String
    var size: Int64
    var status: Int
    var uploadDate = NSDate()
    var url: String
    var urlBase: String
    var user: String
    var userId: String
    var height: Int
    var width: Int
    
    func hash(into hasher: inout Hasher) {
        //TODO: Implement hash???
        hasher.combine(ocId)
    }
    
    /* //TODO: See equals for tableMetadata
     static func == (lhs: Metadata, rhs: Metadata) -> Bool {
         return lhs.dbName == rhs.dbName && lhs.petName == rhs.petName
     }
     
     */
    
    init(obj: tableMetadata) {
        account = obj.account
        checksums = obj.checksums
        chunk = obj.chunk
        contentType = obj.contentType
        creationDate = obj.creationDate
        dataFingerprint = obj.dataFingerprint
        date = obj.date
        directory = obj.directory
        downloadURL = obj.downloadURL
        e2eEncrypted = obj.e2eEncrypted
        etag = obj.etag
        etagResource = obj.etagResource
        favorite = obj.favorite
        fileId = obj.fileId
        fileName = obj.fileName
        fileNameView = obj.fileName
        hasPreview = obj.hasPreview
        iconName = obj.iconName
        iconUrl = obj.iconUrl
        livePhotoFile = obj.livePhotoFile
        name = obj.name
        note = obj.note
        ocId = obj.ocId
        path = obj.path
        quotaUsedBytes = obj.quotaUsedBytes
        quotaAvailableBytes = obj.quotaAvailableBytes
        resourceType = obj.resourceType
        serverUrl = obj.serverUrl
        size = obj.size
        status = obj.status
        classFile = obj.classFile
        uploadDate = obj.uploadDate
        url = obj.url
        urlBase = obj.urlBase
        user = obj.user
        userId = obj.userId
        width = obj.width
        height = obj.height
    }
    
    init(file: NKFile) {
        account = file.account
        checksums = file.checksums
        chunk = false
        contentType = file.contentType
        if let date = file.creationDate {
            creationDate = date as NSDate
        } else {
            creationDate = file.date as NSDate
        }
        dataFingerprint = file.dataFingerprint
        date = file.date as NSDate
        directory = file.directory
        downloadURL = file.downloadURL
        e2eEncrypted = file.e2eEncrypted
        etag = file.etag
        etagResource = ""
        favorite = file.favorite
        fileId = file.fileId
        fileName = file.fileName
        fileNameView = file.fileName
        hasPreview = file.hasPreview
        iconName = file.iconName
        iconUrl = ""
        livePhotoFile = file.livePhotoFile
        name = file.name
        note = file.note
        ocId = file.ocId
        path = file.path
        quotaUsedBytes = file.quotaUsedBytes
        quotaAvailableBytes = file.quotaAvailableBytes
        resourceType = file.resourceType
        serverUrl = file.serverUrl
        size = file.size
        status = 0
        classFile = file.classFile
        if let date = file.uploadDate {
            uploadDate = date as NSDate
        } else {
            uploadDate = file.date as NSDate
        }
        url = ""
        urlBase = file.urlBase
        user = file.user
        userId = file.userId
        width = Int(file.width)
        height = Int(file.height)
    }
}

class tableMetadata: Object {
    
    //TODO: Need this?
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
    @objc dynamic var livePhotoFile = ""
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
    @objc dynamic var height: Int = 0
    @objc dynamic var width: Int = 0
    
    override static func primaryKey() -> String {
        return "ocId"
    }
    
    override init() {
        
    }
    
    init(metadata: Metadata) {
        account = metadata.account
        checksums = metadata.checksums
        chunk = metadata.chunk
        contentType = metadata.contentType
        creationDate = metadata.creationDate
        dataFingerprint = metadata.dataFingerprint
        date = metadata.date
        directory = metadata.directory
        downloadURL = metadata.downloadURL
        e2eEncrypted = metadata.e2eEncrypted
        etag = metadata.etag
        etagResource = metadata.etagResource
        favorite = metadata.favorite
        fileId = metadata.fileId
        fileName = metadata.fileName
        fileNameView = metadata.fileName
        hasPreview = metadata.hasPreview
        iconName = metadata.iconName
        iconUrl = metadata.iconUrl
        livePhotoFile = metadata.livePhotoFile
        name = metadata.name
        note = metadata.note
        ocId = metadata.ocId
        path = metadata.path
        quotaUsedBytes = metadata.quotaUsedBytes
        quotaAvailableBytes = metadata.quotaAvailableBytes
        resourceType = metadata.resourceType
        serverUrl = metadata.serverUrl
        size = metadata.size
        status = metadata.status
        classFile = metadata.classFile
        uploadDate = metadata.uploadDate
        url = metadata.url
        urlBase = metadata.urlBase
        user = metadata.user
        userId = metadata.userId
        width = metadata.width
        height = metadata.height
    }
}

extension Metadata {
    
    var fileExtension: String { (fileNameView as NSString).pathExtension }
    
    var svg: Bool {
        fileExtension == "svg" || contentType == "image/svg+xml"
    }
    
    var gif: Bool {
        fileExtension == "gif" || contentType == "image/gif"
    }
    
    var png: Bool {
        fileExtension == "png" || contentType == "image/png"
    }
    
    var transparent: Bool {
        svg || gif || png
    }
    
    var livePhoto: Bool {
        !livePhotoFile.isEmpty
    }
    
    var video: Bool {
        return classFile == NKCommon.TypeClassFile.video.rawValue
    }
    
    var image: Bool {
        return classFile == NKCommon.TypeClassFile.image.rawValue
    }
    
    var imageSize: CGSize {
        CGSize(width: width, height: height)
    }
}

extension DatabaseManager {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                       category: String(describing: DatabaseManager.self) + "Metadata")
    
    /*private func copyObject(metadata: tableMetadata) -> tableMetadata {
        return tableMetadata.init(value: metadata)
    }*/

    //func convertFileToMetadata(_ file: NKFile) -> tableMetadata {
    //func convertFileToMetadata(_ file: NKFile) -> Metadata {

        //let metadata = tableMetadata()
   //     var metadata = Metadata.init(file: file)

        /*
        metadata.account = file.account
        metadata.checksums = file.checksums
        metadata.contentType = file.contentType
        if let date = file.creationDate {
            metadata.creationDate = date as NSDate
        } else {
            metadata.creationDate = file.date as NSDate
        }
        metadata.dataFingerprint = file.dataFingerprint
        metadata.date = file.date as NSDate
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
        metadata.livePhotoFile = file.livePhotoFile
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
            metadata.uploadDate = date as NSDate
        } else {
            metadata.uploadDate = file.date as NSDate
        }
        metadata.urlBase = file.urlBase
        metadata.user = file.user
        metadata.userId = file.userId
        metadata.width = Int(file.width)
        metadata.height = Int(file.height)
        */
        
        //return metadata
    //}
    
    @discardableResult
    //func addMetadata(_ metadata: tableMetadata) -> tableMetadata? {
    func addMetadata(_ metadata: Metadata) -> Metadata? {

        let realm = try! Realm()
        //let result = tableMetadata.init(value: metadata)
        let result = tableMetadata.init(metadata: metadata)

        do {
            try realm.write {
                realm.add(result, update: .all)
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
            return nil
        }
        //return tableMetadata.init(value: result)
        return Metadata.init(obj: result)
    }
    
    //func convertFilesToMetadatas(_ files: [NKFile]) async -> [tableMetadata] {
    /*func convertFilesToMetadatas(_ files: [NKFile]) async -> [Metadata] {

        //var metadatas: [tableMetadata] = []
        var metadatas: [Metadata] = []

        for file in files {
            metadatas.append(convertFileToMetadata(file))
        }
        
        return metadatas
    }*/
    
    //func getMetadata(predicate: NSPredicate) -> tableMetadata? {
    func getMetadata(predicate: NSPredicate) -> Metadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            return nil
        }

        //return tableMetadata.init(value: result)
        return Metadata.init(obj: result)
    }
    
    //func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> tableMetadata? {
    func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> Metadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending).first else {
            return nil
        }

        //return tableMetadata.init(value: result)
        return Metadata.init(obj: result)
    }
    
    //func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
    func getMetadataFromOcId(_ ocId: String?) -> Metadata? {
        let realm = try! Realm()
        realm.refresh()

        guard let ocId = ocId else { return nil }
        guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else { return nil }

        //return tableMetadata.init(value: result)
        return Metadata.init(obj: result)
    }
    
    //func getMetadatas(predicate: NSPredicate) -> [tableMetadata] {
    func getMetadatas(predicate: NSPredicate) -> [Metadata] {

        let realm = try! Realm()
        realm.refresh()

        let results = realm.objects(tableMetadata.self).filter(predicate)

        //return Array(results.map { tableMetadata.init(value: $0) })
        return Array(results.map { Metadata.init(obj: $0) })
    }
    
    //func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {
    func getMetadataLivePhoto(metadata: Metadata) -> Metadata? {

        guard metadata.livePhoto else { return nil }

        do {
            let realm = try Realm()
            guard let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileId == %@", metadata.account, metadata.serverUrl, metadata.livePhotoFile)).first else { return nil }
            //return tableMetadata.init(value: result)
            return Metadata.init(obj: result)
        } catch let error as NSError {
            Self.logger.error("Could not access database: \(error)")
        }

        return nil
    }
    
    //func paginateMetadata(account: String, startServerUrl: String, fromDate: Date, toDate: Date, offsetDate: Date?, offsetName: String?) -> [tableMetadata] {
    func paginateMetadata(account: String, startServerUrl: String, fromDate: Date, toDate: Date, offsetDate: Date?, offsetName: String?) -> [Metadata] {

        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND date >= %@ AND date <= %@ AND ((classFile = %@ AND livePhotoFile != '') OR livePhotoFile == '') ",
                                    account, startServerUrl, fromDate as NSDate, toDate as NSDate,
                                    NKCommon.TypeClassFile.image.rawValue)
        
        return paginateMetadata(predicate: predicate, offsetDate: offsetDate, offsetName: offsetName)
    }
    
    //func fetchMetadata(predicate: NSPredicate) -> [tableMetadata] {
    func fetchMetadata(predicate: NSPredicate) -> [Metadata] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "date", ascending: false),
                              SortDescriptor(keyPath:  "fileNameView", ascending: false)]
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)
        
        //return Array(results.map { tableMetadata.init(value: $0) })
        return Array(results.map { Metadata.init(obj: $0) })
    }
    
    //func paginateMetadata(predicate: NSPredicate, offsetDate: Date?, offsetName: String?) -> [tableMetadata] {
    func paginateMetadata(predicate: NSPredicate, offsetDate: Date?, offsetName: String?) -> [Metadata] {
    
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "date", ascending: false),
                              SortDescriptor(keyPath: "fileNameView", ascending: false)]
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)
        
        if offsetName == nil || offsetDate == nil {
            if results.count > 0 {
                //return Array(results.prefix(Global.shared.pageSize).map { tableMetadata.init(value: $0) })
                return Array(results.prefix(Global.shared.pageSize).map { Metadata.init(obj: $0) })
            } else {
                return []
            }
        }
        
        //var metadatas: [tableMetadata] = []
        var metadatas: [Metadata] = []
        
        for index in results.indices {
            let metadata = results[index]
            
            if metadata.date as Date == offsetDate {
                if metadata.fileNameView < offsetName! {
                    //metadatas.append(tableMetadata.init(value: metadata))
                    metadatas.append(Metadata.init(obj: metadata))
                }
            } else {
                //metadatas.append(tableMetadata.init(value: metadata))
                metadatas.append(Metadata.init(obj: metadata))
            }
            
            if metadatas.count == Global.shared.pageSize {
                break
            }
        }
        
        return metadatas
    }
    
    /*func processMetadatas(_ metadatas: [tableMetadata], metadatasResult: [tableMetadata]) -> (added: [tableMetadata], updated: [tableMetadata], deleted: [tableMetadata]) {
        
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
                        
                        //Self.logger.debug("processMetadatas() - fileName: \(metadata.fileName) livePhotoFile: \(metadata.livePhotoFile)")
                        
                        // add new
                        if metadata.livePhoto && metadata.video {
                            //don't include video part of live photo
                        } else {
                            addedOcIds.append(metadata.ocId)
                        }
                        
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
    }*/
    
    /*func processMetadatas(_ metadatas: [tableMetadata], metadatasResult: [tableMetadata]) async -> (added: [String], updated: [String], deleted: [tableMetadata]) {
        
        do {
            //TODO: Compile error on asyncWrite. see https://github.com/realm/realm-swift/issues/8687
            //let realm = try await Realm()
            
            //try await realm.asyncWrite { }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
        
        
        
        return ([], [], [])
    }*/
    
    func processMetadatas(_ metadatas: [Metadata], metadatasResult: [Metadata]) -> (added: [Metadata], updated: [Metadata], deleted: [Metadata]) {
        
        var updatedOcIds: [String] = []
        var addedOcIds: [String] = []
        
        var added: [Metadata] = []
        var updated: [Metadata] = []
        var deleted: [Metadata] = []
        
        do {

            let realm = try Realm()
            try realm.write {
                
                //delete
                for metadataResult in metadatasResult {
                    if metadatas.firstIndex(where: { $0.ocId == metadataResult.ocId }) == nil {
                        if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", metadataResult.ocId)).first {
                            //deleted.append(tableMetadata.init(value: result))
                            deleted.append(Metadata.init(obj: result))
                            realm.delete(result)
                        }
                    }
                }
                
                //add and update
                for metadata in metadatas {

                    if let result = metadatasResult.first(where: { $0.ocId == metadata.ocId }) {
                        
                        if result.status == Global.shared.metadataStatusNormal && (result.etag != metadata.etag || result.fileNameView != metadata.fileNameView || result.date != metadata.date || result.hasPreview != metadata.hasPreview || result.note != metadata.note || result.favorite != metadata.favorite) {
                            
                            updatedOcIds.append(metadata.ocId)
                            //realm.add(tableMetadata.init(value: metadata), update: .all)
                            realm.add(tableMetadata.init(metadata: metadata), update: .all)
                        }
                    } else {
                        
                        //Self.logger.debug("processMetadatas() - fileName: \(metadata.fileName) livePhotoFile: \(metadata.livePhotoFile)")
                        
                        // add new
                        if metadata.livePhoto && metadata.video {
                            //don't include video part of live photo
                        } else {
                            addedOcIds.append(metadata.ocId)
                        }
                        
                        //realm.add(tableMetadata.init(value: metadata), update: .all)
                        realm.add(tableMetadata.init(metadata: metadata), update: .all)
                    }
                }
            }
            
            for ocId in addedOcIds {
                if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                    //added.append(tableMetadata.init(value: result))
                    added.append(Metadata.init(obj: result))
                }
            }
            
            for ocId in updatedOcIds {
                if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                    //updated.append(tableMetadata.init(value: result))
                    updated.append(Metadata.init(obj: result))
                }
            }
            
            return (added, updated, deleted)
    
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }

        return ([], [], [])
    }
    
    /*func processMetadatas(_ metadatas: [tableMetadata], metadatasResult: [tableMetadata]) async -> (added: [String], updated: [String], deleted: [tableMetadata]) {
        
        var updatedOcIds: [String] = []
        var addedOcIds: [String] = []
        var deleted: [tableMetadata] = []
        
        do {

            let realm = try await Realm()
            
            try await realm.asyncWrite {
                
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
                        
                        //Self.logger.debug("processMetadatas() - fileName: \(metadata.fileName) livePhotoFile: \(metadata.livePhotoFile)")
                        
                        // add new
                        if metadata.livePhoto && metadata.video {
                            //don't include video part of live photo
                        } else {
                            addedOcIds.append(metadata.ocId)
                        }
                        
                        realm.add(tableMetadata.init(value: metadata), update: .all)
                    }
                }
            }
            
            return (addedOcIds, updatedOcIds, deleted)
    
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }

        return ([], [], [])
    }*/
    
    /*func getMetadatas(addedOcIds: [String], updatedOcIds: [String]) -> (added: [tableMetadata], updated: [tableMetadata]) {
        
        var added: [tableMetadata] = []
        var updated: [tableMetadata] = []
        
        let realm = try! Realm()
        
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
        
        return (added, updated)
    }*/
    
    //func setMetadataFavorite(ocId: String, favorite: Bool) -> tableMetadata? {
    func setMetadataFavorite(ocId: String, favorite: Bool) -> Metadata? {

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
    
    //func updateMetadatasFavorite(account: String, metadatas: [tableMetadata]) {
    func updateMetadatasFavorite(account: String, metadatas: [Metadata]) {

        let realm = try! Realm()

        do {
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND favorite == true", account)
                for result in results {
                    result.favorite = false
                }
                for metadata in metadatas {
                    //realm.add(metadata, update: .all)
                    realm.add(tableMetadata.init(metadata: metadata), update: .all)
                }
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }
    
    func setMetadataEtagResource(ocId: String, etagResource: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.etagResource = etagResource
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }
    
    /*func setMetadataEtagResource(ocId: String, etagResource: String) async {

        do {
            let realm = try await Realm()
     
            //TODO: Compile error on asyncWrite. see https://github.com/realm/realm-swift/issues/8687
     
            try await realm.asyncWrite ({
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.etagResource = etagResource
            })
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }*/
}
