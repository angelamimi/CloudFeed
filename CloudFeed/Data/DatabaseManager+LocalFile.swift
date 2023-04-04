//
//  DatabaseManager+LocalFile.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/2/23.
//

import Foundation
import RealmSwift
import NextcloudKit

class tableLocalFile: Object {

    @objc dynamic var account = ""
    @objc dynamic var etag = ""
    @objc dynamic var exifDate: NSDate?
    @objc dynamic var exifLatitude = ""
    @objc dynamic var exifLongitude = ""
    @objc dynamic var exifLensModel: String?
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileName = ""
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension DatabaseManager {
    
    func addLocalFile(metadata: tableMetadata) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                let addObject = getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) ?? tableLocalFile()
                
                addObject.account = metadata.account
                addObject.etag = metadata.etag
                addObject.exifDate = NSDate()
                addObject.exifLatitude = "-1"
                addObject.exifLongitude = "-1"
                addObject.ocId = metadata.ocId
                addObject.fileName = metadata.fileName
                
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    func getTableLocalFile(predicate: NSPredicate) -> tableLocalFile? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableLocalFile.self).filter(predicate).first else {
            return nil
        }
        
        return tableLocalFile.init(value: result)
    }
}
