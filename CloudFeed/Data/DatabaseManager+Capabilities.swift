//
//  DatabaseManager+Capabilities.swift
//  CloudFeed
//
//  Created by Marino Faggiana on 29/05/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Angela Jarosz
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
import SwiftyJSON

class tableCapabilities: Object {

    @objc dynamic var account = ""
    @objc dynamic var jsondata: Data?

    override static func primaryKey() -> String {
        return "account"
    }
}

extension DatabaseManager {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                       category: String(describing: DatabaseManager.self) + "Capabilities")
    
    func addCapabilitiesJSon(account: String, data: Data) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                let addObject = tableCapabilities()
                
                addObject.account = account
                addObject.jsondata = data
                
                realm.add(addObject, update: .all)
            }
        } catch let error {
            Self.logger.error("Could not write to database: \(error)")
        }
    }
    
    func getCapabilitiesServerInt(account: String, elements: [String]) -> Int {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first,
              let jsondata = result.jsondata else {
            return 0
        }
        
        let json = JSON(jsondata)
        return json[elements].intValue
    }
}
