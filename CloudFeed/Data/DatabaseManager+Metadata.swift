//
//  DatabaseManager+Metadata.swift
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

import Foundation
import NextcloudKit
import UIKit
import SwiftData

@Model
final class MetadataModel {
    
    @Attribute(.unique)
    var ocId = ""
    
    var account = ""
    var classFile = ""
    var contentType = ""
    var creationDate = Date()
    var date = Date()
    var etag = ""
    var etagResource = ""
    var favorite: Bool = false
    var fileId = ""
    var fileName = ""
    var fileNameView = ""
    var hasPreview: Bool = false
    var livePhotoFile = ""
    var name = ""
    var path = ""
    var serverUrl = ""
    var size: Int64 = 0
    var uploadDate = Date()
    var urlBase = ""
    var user = ""
    var userId = ""
    var height: Double = 0
    var width: Double = 0
    
    init(ocId: String = "", account: String = "", classFile: String = "", contentType: String = "", creationDate: Date = Date(),
         date: Date = Date(), etag: String = "", etagResource: String = "", favorite: Bool, fileId: String = "",
         fileName: String = "", fileNameView: String = "", hasPreview: Bool, livePhotoFile: String = "", name: String = "",
         path: String = "", serverUrl: String = "", size: Int64, uploadDate: Date = Date(), urlBase: String = "",
         user: String = "", userId: String = "", height: Double, width: Double) {
        self.account = account
        self.classFile = classFile
        self.contentType = contentType
        self.creationDate = creationDate
        self.date = date
        self.etag = etag
        self.etagResource = etagResource
        self.favorite = favorite
        self.fileId = fileId
        self.fileName = fileName
        self.fileNameView = fileNameView
        self.hasPreview = hasPreview
        self.livePhotoFile = livePhotoFile
        self.name = name
        self.ocId = ocId
        self.path = path
        self.serverUrl = serverUrl
        self.size = size
        self.uploadDate = uploadDate
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        self.height = height
        self.width = width
    }
    
    init(dto: Metadata) {
        self.account = dto.account
        self.classFile = dto.classFile
        self.contentType = dto.contentType
        self.creationDate = dto.creationDate
        self.date = dto.date
        self.etag = dto.etag
        self.etagResource = dto.etagResource
        self.favorite = dto.favorite
        self.fileId = dto.fileId
        self.fileName = dto.fileName
        self.fileNameView = dto.fileNameView
        self.hasPreview = dto.hasPreview
        self.livePhotoFile = dto.livePhotoFile
        self.name = dto.name
        self.ocId = dto.ocId
        self.path = dto.path
        self.serverUrl = dto.serverUrl
        self.size = dto.size
        self.uploadDate = dto.uploadDate
        self.urlBase = dto.urlBase
        self.user = dto.user
        self.userId = dto.userId
        self.height = dto.height
        self.width = dto.width
    }
}

struct Metadata: Sendable, Identifiable {
    
    var id: String {
        return ocId
    }
    
    var ocId: String
    var account: String
    var classFile: String
    var contentType: String
    var creationDate: Date
    var date: Date
    var etag: String
    var etagResource: String
    var favorite: Bool
    var fileId: String
    var fileName: String
    var fileNameView: String
    var hasPreview: Bool
    var livePhotoFile: String
    var name: String
    var path: String
    var serverUrl: String
    var size: Int64
    var uploadDate: Date
    var urlBase: String
    var user: String
    var userId: String
    var height: Double
    var width: Double
    
    init(ocId: String, account: String, classFile: String = "", date: Date = Date(), favorite: Bool = false, fileId: String = "",
         fileName: String, livePhotoFile: String = "", serverUrl: String = "") {
        self.account = account
        self.classFile = classFile
        self.contentType = ""
        self.creationDate = Date()
        self.date = date
        self.etag = ""
        self.etagResource = ""
        self.favorite = favorite
        self.fileId = fileId
        self.fileName = fileName
        self.fileNameView =  fileName
        self.hasPreview = false
        self.livePhotoFile = livePhotoFile
        self.name = ""
        self.ocId = ocId
        self.path = ""
        self.serverUrl = serverUrl
        self.size = 0
        self.uploadDate = Date()
        self.urlBase = ""
        self.user = ""
        self.userId = ""
        self.width = 0
        self.height = 0
    }
    
    init(model: MetadataModel) {
        account = model.account
        contentType = model.contentType
        creationDate = model.creationDate
        date = model.date
        etag = model.etag
        etagResource = model.etagResource
        favorite = model.favorite
        fileId = model.fileId
        fileName = model.fileName
        fileNameView = model.fileNameView
        hasPreview = model.hasPreview
        livePhotoFile = model.livePhotoFile
        name = model.name
        ocId = model.ocId
        path = model.path
        serverUrl = model.serverUrl
        size = model.size
        classFile = model.classFile
        uploadDate = model.uploadDate
        urlBase = model.urlBase
        user = model.user
        userId = model.userId
        width = model.width
        height = model.height
    }
    
    init(file: NKFile) {
        account = file.account
        contentType = file.contentType
        if let date = file.creationDate {
            creationDate = date
        } else {
            creationDate = file.date
        }
        date = file.date
        etag = file.etag
        etagResource = ""
        favorite = file.favorite
        fileId = file.fileId
        fileName = file.fileName
        fileNameView = file.fileName
        hasPreview = file.hasPreview
        livePhotoFile = file.livePhotoFile
        name = file.name
        ocId = file.ocId
        path = file.path
        serverUrl = file.serverUrl
        size = file.size
        classFile = file.classFile
        if let date = file.uploadDate {
            uploadDate = date
        } else {
            uploadDate = file.date
        }
        urlBase = file.urlBase
        user = file.user
        userId = file.userId
        width = file.width
        height = file.height
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
        return classFile == Global.FileType.video.rawValue
    }
    
    var image: Bool {
        return classFile == Global.FileType.image.rawValue
    }
    
    var imageSize: CGSize {
        CGSize(width: width, height: height)
    }
}

extension DatabaseManager {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DatabaseManager.self) + String(describing: Metadata.self)
    )
    
    func getMetadataFromOcId(_ ocId: String) -> Metadata? {
        
        let predicate = #Predicate<MetadataModel> { metadata in
            metadata.ocId == ocId
        }
        
        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate)
        
        if let result = try? modelContext.fetch(fetchDescriptor), let metadata = result.first {
            return Metadata.init(model: metadata)
        }
        
        return nil
    }
    
    func processMetadatas(_ metadatas: [Metadata], metadatasResult: [Metadata]) async -> (added: [Metadata], updated: [Metadata], deleted: [Metadata]) {
        
        var updatedOcIds: [String] = []
        var addedOcIds: [String] = []
        
        var added: [Metadata] = []
        var updated: [Metadata] = []
        var deleted: [Metadata] = []
        
        do {
            //delete
            for metadataResult in metadatasResult {
                if metadatas.firstIndex(where: { $0.ocId == metadataResult.ocId }) == nil {
                    if let result = try getMetadataModel(metadataResult.ocId) {
                        deleted.append(Metadata.init(model: result))
                        modelContext.delete(result)
                    }
                }
            }

            //add and update
            for metadata in metadatas {
                
                if let result = metadatasResult.first(where: { $0.ocId == metadata.ocId }) {
                    
                    if result.etag != metadata.etag || result.fileNameView != metadata.fileNameView || result.date != metadata.date || result.hasPreview != metadata.hasPreview || result.favorite != metadata.favorite {
                        
                        if let model = try getMetadataModel(metadata.ocId) {
                            updatedOcIds.append(metadata.ocId)
                            model.etag = metadata.etag
                            model.fileNameView = metadata.fileNameView
                            model.date = metadata.date
                            model.hasPreview = metadata.hasPreview
                            model.favorite = metadata.favorite
                        }
                    }
                } else {
                    
                    // add new
                    if metadata.livePhoto && metadata.video {
                        //don't include video part of live photo
                    } else {
                        addedOcIds.append(metadata.ocId)
                    }

                    modelContext.insert(MetadataModel(dto: metadata))
                }
            }
            
            try modelContext.save()
            
            for ocId in addedOcIds {
                if let result = try getMetadataModel(ocId) {
                    added.append(Metadata.init(model: result))
                }
            }
            
            for ocId in updatedOcIds {
                if let result = try getMetadataModel(ocId) {
                    updated.append(Metadata.init(model: result))
                }
            }
            
            return (added, updated, deleted)
            
        } catch let error as NSError {
            Self.logger.error("Metadata processing failed: \(error.localizedDescription)")
        }
        
        return ([], [], [])
    }
    
    func getMetadatas(account: String, startServerUrl: String, fromDate: Date, toDate: Date) -> [Metadata] {
        
        let image = Global.FileType.image.rawValue
        let video = Global.FileType.video.rawValue
        
        let predicate = #Predicate<MetadataModel> { metadata in
            metadata.account == account
            && metadata.serverUrl.starts(with: startServerUrl)
            && metadata.date >= fromDate && metadata.date <= toDate
            && (metadata.classFile == image || metadata.classFile == video)
        }
        
        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate)
        
        if let results = try? modelContext.fetch(fetchDescriptor) {
            return results.map ({ Metadata.init(model: $0) })
        }
        
        return []
    }
    
    func getMetadataLivePhoto(metadata: Metadata) -> Metadata? {

        guard metadata.livePhoto else { return nil }

        let account = metadata.account
        let serverUrl = metadata.serverUrl
        let fileId = metadata.livePhotoFile
        
        let predicate = #Predicate<MetadataModel> { model in
            model.account == account
            && model.serverUrl == serverUrl
            && model.fileId == fileId
        }
        
        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate)
        
        if let result = try? modelContext.fetch(fetchDescriptor), let metadataResult = result.first {
            return Metadata.init(model: metadataResult)
        }

        return nil
    }
    
    func paginateMetadata(favorite: Bool, type: Global.FilterType, account: String, startServerUrl: String, fromDate: Date, toDate: Date, offsetDate: Date?, offsetName: String?) -> [Metadata] {
        
        let predicate = buildMediaPredicate(favorite: favorite, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        let sortBy = [SortDescriptor<MetadataModel>(\.date, order: .reverse),
                      SortDescriptor<MetadataModel>(\.fileNameView, comparator: .localizedStandard, order: .reverse)]
        
        let fetchDescriptor = FetchDescriptor(predicate: predicate, sortBy: sortBy)
        
        if let results = try? modelContext.fetch(fetchDescriptor) {

            if offsetName == nil || offsetDate == nil {
                if results.count > 0 {
                    return Array(results.prefix(Global.shared.pageSize).map { Metadata.init(model: $0) })
                } else {
                    return []
                }
            }
            
            var metadatas: [Metadata] = []
            
            for index in results.indices {
                let metadata = results[index]
                
                if metadata.date as Date == offsetDate {
                    if metadata.fileNameView.compare(offsetName!, options: [.numeric, .caseInsensitive, .diacriticInsensitive]) == .orderedAscending {
                        metadatas.append(Metadata.init(model: metadata))
                    }
                } else if metadata.date < offsetDate! {
                    metadatas.append(Metadata.init(model: metadata))
                }
                
                if metadatas.count == Global.shared.pageSize {
                    break
                }
            }
            
            return metadatas
        }
        
        return []
    }
    
    func fetchMetadata(favorite: Bool, type: Global.FilterType, account: String, startServerUrl: String, fromDate: Date, toDate: Date) -> [Metadata] {
        
        let predicate = buildMediaPredicate(favorite: favorite, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        let sortBy = [SortDescriptor<MetadataModel>(\.date, order: .reverse),
                      SortDescriptor<MetadataModel>(\.fileNameView, order: .reverse)]
        
        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate, sortBy: sortBy)
        
        if let results = try? modelContext.fetch(fetchDescriptor) {
            return results.map ({ Metadata.init(model: $0) })
        }
        
        return []
    }
    
    func setMetadataFavorite(ocId: String, favorite: Bool) -> Metadata? {
        
        let predicate = #Predicate<MetadataModel> { metadata in
            metadata.ocId == ocId
        }
        
        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate)
        
        if let result = try? modelContext.fetch(fetchDescriptor), let metadata = result.first {
            metadata.favorite = favorite
            try? modelContext.save()
            return getMetadataFromOcId(ocId)
        }
        
        return nil
    }
    
    func updateMetadatasFavorite(account: String, startServerUrl: String, metadatas: [Metadata]) async {
        
        let predicate = #Predicate<MetadataModel> { model in
            model.favorite == true
        }
        
        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate)
        
        //clear all existing favorites
        if let favorites = try? modelContext.fetch(fetchDescriptor) {
            
            for favorite in favorites {
                favorite.favorite = false
            }
            
            try? modelContext.save()
        }
        
        //set new favorites
        for metadata in metadatas {
            if let model = try? getMetadataModel(metadata.ocId) {
                model.favorite = true
            } else {
                modelContext.insert(MetadataModel(dto: metadata))
            }
        }

        try? modelContext.save()
    }
    
    func setMetadataEtagResource(ocId: String, etagResource: String) {
        
        let metadata = try? getMetadataModel(ocId)
        
        metadata?.etagResource = etagResource
        
        try? modelContext.save()
    }
    
    func deleteMetadata(_ account: String) {
        
        let predicate = #Predicate<MetadataModel> { model in
            model.account == account
        }
        
        try? modelContext.delete(model: MetadataModel.self, where: predicate)
        try? modelContext.save()
    }
    
    private func buildMediaPredicate(favorite: Bool, type: Global.FilterType, account: String, startServerUrl: String, fromDate: Date, toDate: Date) -> Predicate<MetadataModel> {
        
        let imageFileType = Global.FileType.image.rawValue
        let videoFileType = Global.FileType.video.rawValue
        
        let favoritePredicate = #Predicate<MetadataModel> { metadata in
            (favorite == true && metadata.favorite == true) || favorite == false
        }
        
        let basePredicate = #Predicate<MetadataModel> { metadata in
            metadata.account == account
            && metadata.serverUrl.starts(with: startServerUrl)
            && metadata.date >= fromDate
            && metadata.date <= toDate
        }
        
        let typePredicate: Predicate<MetadataModel>
        
        switch type {
        case .all:
            typePredicate = #Predicate<MetadataModel> { metadata in
                metadata.classFile == imageFileType || metadata.classFile == videoFileType
            }
            
            //filter out videos of the live photo file pair
            let livePredicate = #Predicate<MetadataModel> { metadata in
                (metadata.classFile == imageFileType && metadata.livePhotoFile != "") || metadata.livePhotoFile == ""
            }
            
            return #Predicate<MetadataModel> { metadata in
                favoritePredicate.evaluate(metadata)
                && basePredicate.evaluate(metadata)
                && livePredicate.evaluate(metadata)
                && typePredicate.evaluate(metadata)
            }
        case .image:
            typePredicate = #Predicate<MetadataModel> { metadata in
                metadata.classFile == imageFileType
            }
            
            return #Predicate<MetadataModel> { metadata in
                favoritePredicate.evaluate(metadata)
                && basePredicate.evaluate(metadata)
                && typePredicate.evaluate(metadata)
            }
        case .video:
            typePredicate = #Predicate<MetadataModel> { metadata in
                metadata.classFile == videoFileType
            }
            
            //filter out videos of the live photo file pair
            let livePredicate = #Predicate<MetadataModel> { metadata in
                metadata.livePhotoFile == ""
            }
            
            return #Predicate<MetadataModel> { metadata in
                favoritePredicate.evaluate(metadata)
                && basePredicate.evaluate(metadata)
                && livePredicate.evaluate(metadata)
                && typePredicate.evaluate(metadata)
            }
        }
    }
    
    private func getMetadataModel(_ ocId: String) throws -> MetadataModel? {
        let predicate = #Predicate<MetadataModel> { metadataModel in
            metadataModel.ocId == ocId
        }

        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate)
        let results = try modelContext.fetch(fetchDescriptor)
        
        return results.first
    }
}
