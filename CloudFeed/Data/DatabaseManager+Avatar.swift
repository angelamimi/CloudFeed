//
//  DatabaseManager+Avatar.swift
//  CloudFeed
//
//  Created by Marino Faggiana on 20/01/23.
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
import UIKit

class tableAvatar: Object {

    @objc dynamic var date = NSDate()
    @objc dynamic var etag = ""
    @objc dynamic var fileName = ""
    @objc dynamic var loaded: Bool = false

    override static func primaryKey() -> String {
        return "fileName"
    }
}

extension DatabaseManager {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: DatabaseManager.self) + "Avatar")
    
    func addAvatar(fileName: String, etag: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                // Add new
                let addObject = tableAvatar()
                
                addObject.date = NSDate()
                addObject.etag = etag
                addObject.fileName = fileName
                addObject.loaded = true
                
                realm.add(addObject, update: .all)
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }
    
    func getAvatar(fileName: String) -> tableAvatar? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first else {
            return nil
        }
        
        return tableAvatar.init(value: result)
    }
    
    func getAvatarImage(fileName: String) -> UIImage? {
        
        let cachePath = store.getUserDirectory() + "/" + fileName
        
        do {
            let realm = try Realm()
            realm.refresh()
            
            let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first
            if result == nil {
                FileSystemUtility.shared.deleteFile(filePath: cachePath)
                return nil
            } else if result?.loaded == false {
                return nil
            }
            
            return UIImage(contentsOfFile: cachePath)
            
        } catch	let error as NSError {
            Self.logger.debug("Failed to load avatar with error \(error.localizedDescription)")
        }
        
        FileSystemUtility.shared.deleteFile(filePath: cachePath)
        return nil
    }
}
