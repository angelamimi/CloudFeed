//
//  Database.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//

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

class tableCapabilities: Object {

    @objc dynamic var account = ""
    @objc dynamic var jsondata: Data?

    override static func primaryKey() -> String {
        return "account"
    }
}
