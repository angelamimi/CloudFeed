//
//  Database.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//

import RealmSwift
import UIKit

class tableCapabilities: Object {

    @objc dynamic var account = ""
    @objc dynamic var jsondata: Data?

    override static func primaryKey() -> String {
        return "account"
    }
}
