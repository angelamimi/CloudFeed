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
    var datePhotosOriginal = Date()
    var etag = ""
    var favorite: Bool = false
    var fileId = ""
    var fileName = ""
    var fileNameView = ""
    var hasPreview: Bool = false
    var livePhotoFile = ""
    var name = ""
    var ownerId = ""
    var ownerDisplayName = ""
    var path = ""
    var serverUrl = ""
    var size: Int64 = 0
    var uploadDate = Date()
    var urlBase = ""
    var user = ""
    var userId = ""
    var height: Double = 0
    var width: Double = 0
    var latitude: Double = 0
    var longitude: Double = 0
    var altitude: Double = 0

    //@Relationship(deleteRule: .cascade, inverse: \MetadataExifModel.metadata)
    //var exifPhotos: [MetadataExifModel]? = []

    init(ocId: String = "", account: String = "", classFile: String = "", contentType: String = "", creationDate: Date = Date(),
         date: Date = Date(), datePhotosOriginal: Date = Date(), etag: String = "", favorite: Bool, fileId: String = "",
         fileName: String = "", fileNameView: String = "", hasPreview: Bool, livePhotoFile: String = "",
         ownerId: String = "", ownerDisplayName: String = "", name: String = "",
         path: String = "", serverUrl: String = "", size: Int64, uploadDate: Date = Date(), urlBase: String = "",
         user: String = "", userId: String = "", height: Double, width: Double, latitude: Double = 0, longitude: Double = 0, altitude: Double = 0) { /*,
         exifPhotos: [MetadataExifModel]?) {*/
        self.account = account
        self.classFile = classFile
        self.contentType = contentType
        self.creationDate = creationDate
        self.date = date
        self.datePhotosOriginal = datePhotosOriginal
        self.etag = etag
        self.favorite = favorite
        self.fileId = fileId
        self.fileName = fileName
        self.fileNameView = fileNameView
        self.hasPreview = hasPreview
        self.livePhotoFile = livePhotoFile
        self.name = name
        self.ocId = ocId
        self.ownerId = ownerId
        self.ownerDisplayName = ownerDisplayName
        self.path = path
        self.serverUrl = serverUrl
        self.size = size
        self.uploadDate = uploadDate
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        self.height = height
        self.width = width
        //self.exifPhotos = exifPhotos
    }

    init(dto: Metadata) {
        self.account = dto.account
        self.classFile = dto.classFile
        self.contentType = dto.contentType
        self.creationDate = dto.creationDate
        self.date = dto.date
        self.datePhotosOriginal = dto.datePhotosOriginal
        self.etag = dto.etag
        self.favorite = dto.favorite
        self.fileId = dto.fileId
        self.fileName = dto.fileName
        self.fileNameView = dto.fileNameView
        self.hasPreview = dto.hasPreview
        self.livePhotoFile = dto.livePhotoFile
        self.name = dto.name
        self.ocId = dto.ocId
        self.ownerId = dto.ownerId
        self.ownerDisplayName = dto.ownerDisplayName
        self.path = dto.path
        self.serverUrl = dto.serverUrl
        self.size = dto.size
        self.uploadDate = dto.uploadDate
        self.urlBase = dto.urlBase
        self.user = dto.user
        self.userId = dto.userId
        self.height = dto.height
        self.width = dto.width
        self.latitude = dto.latitude
        self.longitude = dto.longitude
        self.altitude = dto.altitude
    }

    static func build(model: MetadataModel) -> Metadata {
        return Metadata(ocId: model.ocId,
                        account: model.account,
                        contentType: model.contentType,
                        creationDate: model.creationDate,
                        date: model.date,
                        datePhotosOriginal: model.datePhotosOriginal,
                        etag: model.etag,
                        favorite: model.favorite,
                        fileId: model.fileId,
                        fileName: model.fileName,
                        fileNameView: model.fileNameView,
                        hasPreview: model.hasPreview,
                        livePhotoFile: model.livePhotoFile,
                        name: model.name,
                        ownerId: model.ownerId,
                        ownerDisplayName: model.ownerDisplayName,
                        path: model.path,
                        serverUrl: model.serverUrl,
                        size: model.size,
                        classFile: model.classFile,
                        uploadDate: model.uploadDate,
                        urlBase: model.urlBase,
                        user: model.user,
                        userId: model.userId,
                        width: model.width,
                        height: model.height,
                        latitude: model.latitude,
                        longitude: model.longitude,
                        altitude: model.altitude)
    }

    /*static func buildExif(dto: Metadata, model: MetadataModel) {

        var exifPhotos: [MetadataExifModel] = []
        if let exifs = dto.exifPhotos {
            for exif in exifs {
                for (key, value) in exif {
                    exifPhotos.append(MetadataExifModel(key: key, value: value, metadata: model))
                }
            }
        }

        model.exifPhotos?.append(contentsOf: exifPhotos)
    }*/
}

@Model
final class MetadataExifModel {
    var key: String
    var value: String

    @Relationship
    var metadata: MetadataModel?

    init(key: String, value: String, metadata: MetadataModel?) {
        self.key = key
        self.value = value
        self.metadata = metadata
    }
}

nonisolated struct Metadata: Sendable, Identifiable {

    var id: String {
        return ocId
    }

    var ocId: String
    var account: String
    var classFile: String
    var contentType: String
    var creationDate: Date
    var datePhotosOriginal: Date
    var date: Date
    var etag: String
    var favorite: Bool
    var fileId: String
    var fileName: String
    var fileNameView: String
    var hasPreview: Bool
    var livePhotoFile: String
    var name: String
    var ownerId: String
    var ownerDisplayName: String
    var path: String
    var serverUrl: String
    var size: Int64
    var uploadDate: Date
    var urlBase: String
    var user: String
    var userId: String
    var height: Double
    var width: Double
    var latitude: Double
    var longitude: Double
    var altitude: Double
    //var exifPhotos: [[String: String]]?

    init(ocId: String, account: String, classFile: String = "", date: Date = Date(), favorite: Bool = false, fileId: String = "",
         fileName: String, livePhotoFile: String = "", serverUrl: String = "") {
        self.account = account
        self.classFile = classFile
        self.contentType = ""
        self.creationDate = Date()
        self.date = date
        self.datePhotosOriginal = date
        self.etag = ""
        self.favorite = favorite
        self.fileId = fileId
        self.fileName = fileName
        self.fileNameView = fileName
        self.hasPreview = false
        self.livePhotoFile = livePhotoFile
        self.name = ""
        self.ocId = ocId
        self.ownerId = ""
        self.ownerDisplayName = ""
        self.path = ""
        self.serverUrl = serverUrl
        self.size = 0
        self.uploadDate = Date()
        self.urlBase = ""
        self.user = ""
        self.userId = ""
        self.width = 0
        self.height = 0
        self.latitude = 0
        self.longitude = 0
        self.altitude = 0
        //self.exifPhotos = nil
    }

    init(ocId: String,
         account: String,
         contentType: String,
         creationDate: Date,
         date: Date,
         datePhotosOriginal: Date,
         etag: String,
         favorite: Bool,
         fileId: String,
         fileName: String,
         fileNameView: String,
         hasPreview: Bool,
         livePhotoFile: String,
         name: String,
         ownerId: String,
         ownerDisplayName: String,
         path: String,
         serverUrl: String,
         size: Int64,
         classFile: String,
         uploadDate: Date,
         urlBase: String,
         user: String,
         userId: String,
         width: Double,
         height: Double,
         latitude: Double,
         longitude: Double,
         altitude: Double) {
        self.account = account
        self.classFile = classFile
        self.contentType = contentType
        self.creationDate = creationDate
        self.date = date
        self.datePhotosOriginal = datePhotosOriginal
        self.etag = etag
        self.favorite = favorite
        self.fileId = fileId
        self.fileName = fileName
        self.fileNameView = fileName
        self.hasPreview = hasPreview
        self.livePhotoFile = livePhotoFile
        self.name = name
        self.ocId = ocId
        self.ownerId = ownerId
        self.ownerDisplayName = ownerDisplayName
        self.path = path
        self.serverUrl = serverUrl
        self.size = size
        self.uploadDate = uploadDate
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        self.width = width
        self.height = height
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        //self.exifPhotos = nil
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
        if let fileDatePhotosOriginal = file.datePhotosOriginal {
            datePhotosOriginal = fileDatePhotosOriginal
        } else {
            datePhotosOriginal = date
        }
        etag = file.etag
        favorite = file.favorite
        fileId = file.fileId
        fileName = file.fileName
        fileNameView = file.fileName
        hasPreview = file.hasPreview
        livePhotoFile = file.livePhotoFile
        name = file.name
        ocId = file.ocId
        ownerId = file.ownerId
        ownerDisplayName = file.ownerDisplayName
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
        latitude = file.latitude
        longitude = file.longitude
        altitude = file.altitude

        /*if file.exifPhotos.isEmpty == false {
            exifPhotos = [[:]]
            for exif in file.exifPhotos {
                for key in exif.keys {
                    if let val = exif[key], val != nil {
                        exifPhotos!.append([key: val!])
                    }
                }
            }
        }*/
    }
}

extension Metadata {

    nonisolated var fileExtension: String { (fileNameView as NSString).pathExtension }

    nonisolated var svg: Bool {
        fileExtension == "svg" || contentType == "image/svg+xml"
    }

    nonisolated var gif: Bool {
        fileExtension == "gif" || contentType == "image/gif"
    }

    nonisolated var png: Bool {
        fileExtension == "png" || contentType == "image/png"
    }

    nonisolated var transparent: Bool {
        svg || gif || png
    }

    nonisolated var livePhoto: Bool {
        !livePhotoFile.isEmpty
    }

    nonisolated var video: Bool {
        return classFile == Global.FileType.video.rawValue
    }

    nonisolated var image: Bool {
        return classFile == Global.FileType.image.rawValue
    }

    nonisolated var imageSize: CGSize {
        CGSize(width: width, height: height)
    }

    nonisolated static func buildAvatarFileName(urlBase: String, userId: String) -> String {
        let url = (URL(string: urlBase)?.host) ?? "localhost"
        let fileName = userId + "@" + url + ".png"
        return fileName
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
            return MetadataModel.build(model: metadata)
        }

        return nil
    }

    func syncMetadatas(local: [Metadata], remote: [Metadata], fromDate: Date?, toDate: Date?) {

        let remoteOcIds = Set(remote.map { $0.ocId })
        let localOcIds = Set(local.map { $0.ocId })

        let toDeleteOcIds = Array(localOcIds.subtracting(remoteOcIds))
        let toAddOcIds = Array(remoteOcIds.subtracting(localOcIds))
        let toUpdateOcIds = Array(remoteOcIds.intersection(localOcIds))

        if toDeleteOcIds.isEmpty && toAddOcIds.isEmpty && toUpdateOcIds.isEmpty {
            return
        }

        syncMetadatasAdd(toAddOcIds: toAddOcIds, remote: remote)
        syncMetadatasUpdate(toUpdateOcIds: toUpdateOcIds, local: local, remote: remote)
        syncMetadatasDelete(toDeleteOcIds: toDeleteOcIds, local: local, fromDate: fromDate, toDate: toDate)
    }

    private func syncMetadatasAdd(toAddOcIds: [String], remote: [Metadata]) {

        let toAdd = remote.filter { toAddOcIds.contains($0.ocId) }

        if toAdd.count > 0 {
            for metadata in toAdd {
                let model = MetadataModel(dto: metadata)
                modelContext.insert(model)
            }

            try? modelContext.save()
        }
    }

    private func syncMetadatasUpdate(toUpdateOcIds: [String], local: [Metadata], remote: [Metadata]) {

        for toUpdateOcId in toUpdateOcIds {

            if let localMetadata = local.first(where: { $0.ocId == toUpdateOcId }),
               let remoteMetadata = remote.first(where: { $0.ocId == toUpdateOcId }) {

                if localMetadata.etag != remoteMetadata.etag
                    || localMetadata.fileNameView != remoteMetadata.fileNameView
                    || localMetadata.date != remoteMetadata.date
                    || localMetadata.datePhotosOriginal != remoteMetadata.datePhotosOriginal
                    || localMetadata.hasPreview != remoteMetadata.hasPreview
                    || localMetadata.favorite != remoteMetadata.favorite {

                    if let model = try? getMetadataModel(remoteMetadata.ocId) {

                        model.etag = remoteMetadata.etag
                        model.fileNameView = remoteMetadata.fileNameView
                        model.date = remoteMetadata.date
                        model.datePhotosOriginal = remoteMetadata.datePhotosOriginal
                        model.hasPreview = remoteMetadata.hasPreview
                        model.favorite = remoteMetadata.favorite
                        model.size = remoteMetadata.size
                        model.width = remoteMetadata.width
                        model.height = remoteMetadata.height

                        Self.logger.debug("Sync update for: \(localMetadata.fileNameView)")

                        modelContext.insert(model)
                    }
                }
            }
        }

        if modelContext.hasChanges {
            try? modelContext.save()
        }
    }

    private func syncMetadatasDelete(toDeleteOcIds: [String], local: [Metadata], fromDate: Date?, toDate: Date?) {

        if toDeleteOcIds.count > 0 {

            var deletes: [String] = []

            if fromDate != nil && toDate != nil {
                for toDeleteOcId in toDeleteOcIds {
                    if local.contains(where: { $0.ocId == toDeleteOcId && $0.date >= fromDate! && $0.date <= toDate! }) {
                        deletes.append(toDeleteOcId)
                    }
                }
            } else {
                deletes = toDeleteOcIds
            }

            if deletes.count > 0 {

                Self.logger.debug("Sync delete count: \(deletes.count)")

                let chunkSize = Global.shared.chunkSize

                for start in stride(from: 0, to: deletes.count, by: chunkSize) {
                    let chunk = Array(deletes[start..<min(start + chunkSize, deletes.count)])
                    try? modelContext.delete(model: MetadataModel.self, where: #Predicate {
                        chunk.contains($0.ocId)
                    })
                }

                try? modelContext.save()
            }
        }
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
            return results.map({ MetadataModel.build(model: $0) })
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
            //return Metadata.init(model: metadataResult)
            return MetadataModel.build(model: metadataResult)
        }

        return nil
    }

    func fetchMetadata(favorite: Bool, type: Global.FilterType, account: String, startServerUrl: String, fromDate: Date, toDate: Date) -> [Metadata] {

        let predicate = buildMediaPredicate(favorite: favorite, type: type, account: account, startServerUrl: startServerUrl, fromDate: fromDate, toDate: toDate)
        let sortBy = [SortDescriptor<MetadataModel>(\.date, order: .reverse),
                      SortDescriptor<MetadataModel>(\.fileNameView, order: .reverse)]

        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate, sortBy: sortBy)

        if let results = try? modelContext.fetch(fetchDescriptor) {
           return results.map({ MetadataModel.build(model: $0) })
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

    func syncFavorites(account: String, startServerUrl: String, metadatas: [Metadata]) async {

        let remotes = metadatas.map { $0.ocId }

        let predicate = #Predicate<MetadataModel> { model in
            model.favorite == true
        }

        let fetchDescriptor = FetchDescriptor<MetadataModel>(predicate: predicate)

        //fetch local favorites
        if let favorites = try? modelContext.fetch(fetchDescriptor) {

            if metadatas.count == 0 && favorites.count > 0 {
                //nothing to do
                return
            }

            if metadatas.count == 0 && favorites.count > 0 {
                //nothing remote. have local. remove all favorites
                for localMetadata in favorites {
                    localMetadata.favorite = false
                    modelContext.insert(localMetadata)
                }
                return
            }

            if metadatas.count > 0 && favorites.count == 0 {
                //all remote. nothing local. add all
                for metadata in metadatas {
                    modelContext.insert(MetadataModel(dto: metadata))
                }
                return
            }

            //toggle what is not in the remote list
            for localMetadata in favorites {
                if localMetadata.favorite && !metadatas.contains(where: { $0.ocId == localMetadata.ocId }) {
                    localMetadata.favorite = false
                    modelContext.insert(localMetadata)
                }
            }

            //insert what is not found locally
            for metadata in metadatas {
                if !favorites.contains(where: { $0.ocId == metadata.ocId }) {
                    modelContext.insert(MetadataModel(dto: metadata))
                }
            }
        }

        if !remotes.isEmpty {

            //toggle non-favorites that should be favorites
            let chunkSize = Global.shared.chunkSize
            var nonFavorites: [MetadataModel] = []

            for start in stride(from: 0, to: remotes.count, by: chunkSize) {
                let chunk = Array(remotes[start..<min(start + chunkSize, remotes.count)])

                let nonFavoritePredicate = #Predicate<MetadataModel> { model in
                    model.favorite == false && chunk.contains(model.ocId)
                }

                let nonFavoriteDescriptor = FetchDescriptor<MetadataModel>(predicate: nonFavoritePredicate)

                if let result = try? modelContext.fetch(nonFavoriteDescriptor) {
                    nonFavorites.append(contentsOf: result)
                }
            }

            for nonFavorite in nonFavorites {
                nonFavorite.favorite = true
                modelContext.insert(nonFavorite)
            }
        }

        if modelContext.hasChanges {
            try? modelContext.save()
        }
    }

    func deleteMetadata(_ account: String) {

        let predicate = #Predicate<MetadataModel> { model in
            model.account == account
        }

        try? modelContext.delete(model: MetadataModel.self, where: predicate)
        try? modelContext.save()
    }

    private func buildMediaPredicate(favorite: Bool, type: Global.FilterType, account: String, startServerUrl: String, fromDate: Date?, toDate: Date?) -> Predicate<MetadataModel> {

        let imageFileType = Global.FileType.image.rawValue
        let videoFileType = Global.FileType.video.rawValue

        let favoritePredicate = #Predicate<MetadataModel> { metadata in
            (favorite == true && metadata.favorite == true) || favorite == false
        }

        var basePredicate: Predicate<MetadataModel>

        if fromDate == nil || toDate == nil {
            basePredicate = #Predicate<MetadataModel> { metadata in
                metadata.account == account
                && metadata.serverUrl.starts(with: startServerUrl)
            }
        } else {
            basePredicate = #Predicate<MetadataModel> { metadata in
                metadata.account == account
                && metadata.serverUrl.starts(with: startServerUrl)
                && metadata.date >= fromDate!
                && metadata.date <= toDate!
            }
        }

        let typePredicate: Predicate<MetadataModel>

        switch type {
        case .all:
            typePredicate = #Predicate<MetadataModel> { metadata in
                metadata.classFile == imageFileType || metadata.classFile == videoFileType
            }

            //filter out videos of the live photo file pair. isEmpty does not eval correctly.
            let livePredicate = #Predicate<MetadataModel> { metadata in
                //(metadata.classFile == imageFileType && metadata.livePhotoFile.isEmpty == false) || metadata.livePhotoFile.isEmpty == true
                //(metadata.classFile == imageFileType && !metadata.livePhotoFile.isEmpty) || metadata.livePhotoFile.isEmpty
                (metadata.classFile == imageFileType && metadata.livePhotoFile != "") || metadata.livePhotoFile == "" //swiftlint:disable:this empty_string
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

            //filter out videos of the live photo file pair. isEmpty does not work here.
            let livePredicate = #Predicate<MetadataModel> { metadata in
                //metadata.livePhotoFile.isEmpty == true
                //metadata.livePhotoFile.isEmpty
                metadata.livePhotoFile == "" //swiftlint:disable:this empty_string
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
