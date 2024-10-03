//
//  DatabaseManager+LocalFile.swift
//  CloudFeed
//
//  Created by Marino Faggiana on 01/08/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
import os.log
import RealmSwift

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
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                       category: String(describing: DatabaseManager.self) + "LocalFile")
    
    func addLocalFile(metadata: Metadata) {
        
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
            Self.logger.error("Could not write to database: \(error)")
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
