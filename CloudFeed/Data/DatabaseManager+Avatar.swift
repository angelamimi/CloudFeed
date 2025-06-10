//
//  DatabaseManager+Avatar.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 6/8/25.
//  Copyright © 2025 Angela Jarosz. All rights reserved.
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

import os.log
import SwiftData
import UIKit

@Model
final class AvatarModel {

    var date = Date()
    var etag = ""
    var fileName = ""
    
    init(date: Date = Date(), etag: String = "", fileName: String = "") {
        self.date = date
        self.etag = etag
        self.fileName = fileName
    }
}

struct Avatar {
    var date: Date
    var etag: String
    var fileName: String
    
    init(model: AvatarModel) {
        self.date = model.date
        self.etag = model.etag
        self.fileName = model.fileName
    }
}

extension DatabaseManager {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DatabaseManager.self) + String(describing: Avatar.self)
    )
    
    func addAvatar(fileName: String, etag: String) {
        modelContext.insert(AvatarModel(date: Date(), etag: etag, fileName: fileName))
        try? modelContext.save()
    }
    
    func getAvatar(fileName: String) -> Avatar? {
        
        let predicate = #Predicate<AvatarModel> { avatarModel in
            avatarModel.fileName == fileName
        }
        
        let fetchDescriptor = FetchDescriptor<AvatarModel>(predicate: predicate)
        
        if let results = try? modelContext.fetch(fetchDescriptor), let avatar = results.first {
            return Avatar(model: avatar)
        }
        
        return nil
    }
}
