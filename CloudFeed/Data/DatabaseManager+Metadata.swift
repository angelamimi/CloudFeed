//
//  DatabaseManager+Metadata.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/13/23.
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
}

extension DatabaseManager {
    
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
            NKCommon.shared.writeLog("Could not write to database: \(error)")
            return nil
        }
        return tableMetadata.init(value: result)
    }
    
    func convertFilesToMetadatas(_ files: [NKFile], useMetadataFolder: Bool) async -> (metadataFolder: tableMetadata, metadatasFolder: [tableMetadata], metadatas: [tableMetadata]) {

        var counter: Int = 0

        var metadataFolder = tableMetadata()
        var metadataFolders: [tableMetadata] = []
        var metadatas: [tableMetadata] = []

        for file in files {

            let metadata = convertFileToMetadata(file)

            if counter == 0 && useMetadataFolder {
                metadataFolder = tableMetadata.init(value: metadata)
            } else {
                metadatas.append(metadata)
                if metadata.directory {
                    metadataFolders.append(metadata)
                }
            }

            counter += 1
        }

        //Handle live photo
        var metadataOutput: [tableMetadata] = []
        metadatas = metadatas.sorted(by: {$0.fileNameView < $1.fileNameView})

        for index in metadatas.indices {
            let metadata = metadatas[index]
            if index < metadatas.count - 1,
                metadata.fileNoExtension == metadatas[index+1].fileNoExtension,
                ((metadata.classFile == NKCommon.typeClassFile.image.rawValue && metadatas[index+1].classFile == NKCommon.typeClassFile.video.rawValue) || (metadata.classFile == NKCommon.typeClassFile.video.rawValue && metadatas[index+1].classFile == NKCommon.typeClassFile.image.rawValue)){
                metadata.livePhoto = true
                metadatas[index+1].livePhoto = true
            }
            metadataOutput.append(metadata)
        }

        return (metadataFolder, metadataFolders, metadataOutput)
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
    
    func getOldestMetada() -> tableMetadata? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "serverUrl", ascending: false),
                              SortDescriptor(keyPath:  "date", ascending: false),
                              SortDescriptor(keyPath:  "fileNameView", ascending: false)]
        
        guard let result = realm.objects(tableMetadata.self).sorted(by: sortProperties).last else { return nil }
        
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

        if classFile == NKCommon.typeClassFile.image.rawValue {
            classFile = NKCommon.typeClassFile.video.rawValue
            fileName = fileName + ".mov"
        } else {
            classFile = NKCommon.typeClassFile.image.rawValue
            fileName = fileName + ".jpg"
        }

        guard let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView CONTAINS[cd] %@ AND ocId != %@ AND classFile == %@", metadata.account, metadata.serverUrl, fileName, metadata.ocId, classFile)).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }
    
    func paginateMetadata(account: String, startServerUrl: String, greaterDate: Date, lessDate: Date, offsetDate: Date?, offsetName: String?) -> [tableMetadata] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND date > %@ AND date < %@ AND ((classFile = %@ AND livePhoto = true) OR livePhoto = false) ",
                                    account, startServerUrl, greaterDate as NSDate, lessDate as NSDate,
                                    NKCommon.typeClassFile.image.rawValue)
        
        let sortProperties = [SortDescriptor(keyPath: "date", ascending: false),
                              SortDescriptor(keyPath:  "fileNameView", ascending: false)]
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)
        
        if offsetName == nil || offsetDate == nil {
            if results.count > 0 {
                let resultArray = Array(results.map { tableMetadata.init(value: $0) })
                return Array(resultArray.prefix(10))
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
            
            if metadatas.count == 10 {
                break
            }
        }
        
        return metadatas
    }
    
    func getMetadatasMediaPage(predicate: NSPredicate) -> [tableMetadata] {
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "serverUrl", ascending: false),
                              SortDescriptor(keyPath:  "date", ascending: false),
                              SortDescriptor(keyPath:  "fileNameView", ascending: false)]

        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)

        return Array(results.map { tableMetadata.init(value: $0) })
    }

    func processMetadatasMedia(predicate: NSPredicate) {
        //pull all metadata in order to flag live photos. the 2 file dates do not have to be the same or even near each other
        
        let realm = try! Realm()
        //var metadatas: [tableMetadata] = []
        
        /*
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Global.shared.groupIdentifier)
        let databaseFileUrlPath = dirGroup?.appendingPathComponent(Global.shared.databaseDirectory + "/" + Global.shared.databaseDefault)
        
        var config = Realm.Configuration()
        print("************** \(config.fileURL)")
        print("************** \(databaseFileUrlPath)")*/

        do {
            try realm.write {
                let sortProperties = [SortDescriptor(keyPath: "serverUrl", ascending: false),
                                      SortDescriptor(keyPath:  "fileNameView", ascending: false)]
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
                    /*if metadata.livePhoto {
                        if metadata.classFile == NKCommon.typeClassFile.image.rawValue {
                            //print("APPENDING \(metadata.ocId) \(metadata.fileNameView)")
                            //metadatas.append(tableMetadata.init(value: metadata))
                        }
                        continue
                    } else {
                        //print("APPENDING \(metadata.ocId) \(metadata.fileNameView)")
                        //metadatas.append(tableMetadata.init(value: metadata))
                    }*/
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }

        //return metadatas
    }
    
    //@discardableResult
    func processMetadatas(_ metadatas: [tableMetadata], metadatasResult: [tableMetadata], addCompareLivePhoto: Bool = true, addExistsInLocal: Bool = false, addCompareEtagLocal: Bool = false, addDirectorySynchronized: Bool = false) -> [String] { //-> (ocIdAdd: [String], ocIdUpdate: [String], ocIdDelete: [String]) {

        let realm = try! Realm()
        //var ocIdAdd: [String] = []
        var ocIdDelete: [String] = []
        //var ocIdUpdate: [String] = []
        
        do {
            try realm.write {

                // DELETE
                for metadataResult in metadatasResult {
                    if metadatas.firstIndex(where: { $0.ocId == metadataResult.ocId }) == nil {
                        if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", metadataResult.ocId)).first {
                            let deleteId = result.ocId
                            realm.delete(result)
                            //ocIdDelete.append(result.ocId)
                            ocIdDelete.append(deleteId)
                        }
                    }
                }

                // UPDATE/NEW
                for metadata in metadatas {

                    if let result = metadatasResult.first(where: { $0.ocId == metadata.ocId }) {
                        if result.status == Global.shared.metadataStatusNormal && (result.etag != metadata.etag || result.fileNameView != metadata.fileNameView || result.date != metadata.date || result.hasPreview != metadata.hasPreview || result.note != metadata.note || result.favorite != metadata.favorite) {
                            //ocIdUpdate.append(metadata.ocId)
                            realm.add(tableMetadata.init(value: metadata), update: .all)
                        } else if result.status == Global.shared.metadataStatusNormal && addCompareLivePhoto && result.livePhoto != metadata.livePhoto {
                            //ocIdUpdate.append(metadata.ocId)
                            realm.add(tableMetadata.init(value: metadata), update: .all)
                        }
                    } else {
                        // new
                        //ocIdAdd.append(metadata.ocId)
                        realm.add(tableMetadata.init(value: metadata), update: .all)
                    }
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }

        //print("!!!!!!!!! added: \(ocIdAdd.count) updated: \(ocIdUpdate.count) deleted: \(ocIdDelete.count)")
        //return (ocIdAdd, ocIdUpdate, ocIdDelete)
        print("!!!!!!!!! deleted: \(ocIdDelete.count)")
        return ocIdDelete
    }
    
    func setMetadataFavorite(ocId: String, favorite: Bool) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.favorite = favorite
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
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
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
}
