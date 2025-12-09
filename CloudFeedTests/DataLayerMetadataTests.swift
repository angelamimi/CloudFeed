//
//  DataLayerMetadataTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 6/9/25.
//

@testable import CloudFeed
import Foundation
import Testing

struct DataLayerMetadataTests {

    private var databaseManager: DatabaseManager
    
    init() async throws {
        databaseManager = DatabaseManager(modelContainer: DatabaseManager.test)
    }
    
    @Test func getMetadataFromOcId() async throws {
        
        let metadata1 = Metadata.init(ocId: "ocid1", account: "account1", fileName: "file1")
        let metadata2 = Metadata.init(ocId: "ocid2", account: "account1", fileName: "file2")
        let metadata3 = Metadata.init(ocId: "ocid3", account: "account1", fileName: "file3")
        let metadata4 = Metadata.init(ocId: "ocid4", account: "account1", fileName: "file4")

        let _ = await databaseManager.processMetadatas([metadata1, metadata2, metadata3, metadata4], metadatasResult: [])
        
        let result = await databaseManager.getMetadataFromOcId(metadata4.ocId)
        
        #expect(result?.ocId == metadata4.ocId)
    }

    @Test func processMetadatas() async throws {
        
        let metadata1 = Metadata.init(ocId: "ocid1", account: "account1", fileName: "file1")
        let metadata2 = Metadata.init(ocId: "ocid2", account: "account1", fileName: "file2")
        var metadata3 = Metadata.init(ocId: "ocid3", account: "account1", fileName: "file3")
        let metadata4 = Metadata.init(ocId: "ocid4", account: "account1", fileName: "file4")
        
        //Test insert
        let addResults = await databaseManager.processMetadatas([metadata1, metadata2, metadata3, metadata4], metadatasResult: [])
        
        #expect(addResults.added.count == 4)
        #expect(addResults.updated.count == 0)
        #expect(addResults.deleted.count == 0)
        
        //Test update
        metadata3.favorite = true
        
        let updateResults = await databaseManager.processMetadatas([metadata1, metadata2, metadata3, metadata4], metadatasResult: addResults.added)
        
        #expect(updateResults.added.count == 0)
        #expect(updateResults.updated.count == 1)
        #expect(updateResults.deleted.count == 0)
        
        #expect(updateResults.updated[0].favorite == true)
        
        let ocIdResult = await databaseManager.getMetadataFromOcId(metadata3.ocId)
        #expect(ocIdResult?.favorite == true)
        
        //Test delete
        let deleteResults = await databaseManager.processMetadatas([metadata2], metadatasResult: addResults.added)
        
        #expect(deleteResults.added.count == 0)
        #expect(deleteResults.updated.count == 0)
        #expect(deleteResults.deleted.count == 3)
        
        let result1 = await databaseManager.getMetadataFromOcId(metadata1.ocId)
        #expect(result1 == nil)
        
        let result2 = await databaseManager.getMetadataFromOcId(metadata2.ocId)
        #expect(result2 != nil)
        
        let result3 = await databaseManager.getMetadataFromOcId(metadata3.ocId)
        #expect(result3 == nil)
        
        let result4 = await databaseManager.getMetadataFromOcId(metadata4.ocId)
        #expect(result4 == nil)
    }
    
    @Test func getMetadatas() async throws {
        
        let account = "account1"
        let serverUrl = "testserver1.com"
        let fromDate = dateFrom("01/01/2001")
        let toDate = dateFrom("01/01/2020")
        
        let metadata1 = Metadata.init(ocId: "ocid1", account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2001"), fileName: "file1", serverUrl: serverUrl)
        let metadata2 = Metadata.init(ocId: "ocid2", account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2002"), fileName: "file2", serverUrl: serverUrl)
        let metadata3 = Metadata.init(ocId: "ocid3", account: "account2", classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2003"), fileName: "file3", serverUrl: "testserver2.com")
        let metadata4 = Metadata.init(ocId: "ocid4", account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2004"), fileName: "file4", serverUrl: serverUrl)
        let metadata5 = Metadata.init(ocId: "ocid5", account: "account2", classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2020"), fileName: "file5", serverUrl: "testserver2.com")
        let metadata6 = Metadata.init(ocId: "ocid6", account: "account3", classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2021"), fileName: "file6", serverUrl: "testserver3.com")
        let metadata7 = Metadata.init(ocId: "ocid7", account: account, classFile: Global.FileType.document.rawValue , date: dateFrom("01/01/2022"), fileName: "file7", serverUrl: serverUrl)
        let metadata8 = Metadata.init(ocId: "ocid8", account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2024"), fileName: "file8", serverUrl: serverUrl)
        
        let results = await databaseManager.processMetadatas([metadata1, metadata2, metadata3, metadata4, metadata5, metadata6, metadata7, metadata8], metadatasResult: [])
        
        #expect(results.added.count == 8)
        
        let metadatas = await databaseManager.getMetadatas(account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate)
        
        #expect(metadatas.count == 3)
        
        for metadata in metadatas {
            #expect(metadata.account == account)
            #expect(metadata.serverUrl == serverUrl)
            #expect(metadata.classFile == Global.FileType.image.rawValue || metadata.classFile == Global.FileType.video.rawValue)
            #expect(metadata.datePhotosOriginal >= fromDate && metadata.datePhotosOriginal <= toDate)
        }
    }
    
    @Test func getMetadataLivePhoto() async throws {
        
        let metadata1 = Metadata.init(ocId: "ocid1", account: "account1", classFile: Global.FileType.image.rawValue, fileId: "123", fileName: "file1", livePhotoFile: "456", serverUrl: "testserver1.com")
        let metadata2 = Metadata.init(ocId: "ocid2", account: "account1", classFile: Global.FileType.video.rawValue, fileId: "456", fileName: "file2", livePhotoFile: "123", serverUrl: "testserver1.com")
        
        let results = await databaseManager.processMetadatas([metadata1, metadata2], metadatasResult: [])
        
        #expect(results.added.count == 1)
        
        let video = await databaseManager.getMetadataLivePhoto(metadata: results.added[0])
        
        #expect(video != nil)
        #expect(video?.video == true)
        #expect(video?.fileId == metadata1.livePhotoFile)
    }
    
    @Test func paginateMetadata() async throws {
        
        let account = "account1"
        let serverUrl = "testserver1.com"
        let fromDate = dateFrom("01/01/2001")
        let toDate = dateFrom("01/01/2020")
        var toProcess: [Metadata] = []
        
        for i in 1...200 {
            var metadata = Metadata.init(ocId: "ocid" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: serverUrl)
            if i.isMultiple(of: 2) {
                metadata.favorite = true
            }
            if i.isMultiple(of: 10) {
                metadata.classFile = Global.FileType.video.rawValue
            }
            toProcess.append(metadata)
        }
        
        for i in 1...10 {
            let livePhoto = Metadata.init(ocId: "ocid1_" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2002"), fileId: "123_" + i.description, fileName: "file1_" + i.description, livePhotoFile: "456_" + i.description, serverUrl: serverUrl)
            let livePhotoVideo = Metadata.init(ocId: "ocid2_" + i.description, account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2002"), fileId: "456_" + i.description, fileName: "file2_" + i.description, livePhotoFile: "123_" + i.description, serverUrl: serverUrl)
            toProcess.append(livePhoto)
            toProcess.append(livePhotoVideo)
        }
        
        let results = await databaseManager.processMetadatas(toProcess, metadatasResult: [])
        #expect(results.added.count == 210)
        
        //Test pagination
        let pagedResults = await databaseManager.paginateMetadata(favorite: false, type: .all, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate, offsetDate: nil, offsetName: nil)
        #expect(pagedResults.count == 200)
        
        let last = pagedResults[pagedResults.count - 1]
        let nextPagedResults = await databaseManager.paginateMetadata(favorite: false, type: .all, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate, offsetDate: last.datePhotosOriginal, offsetName: last.fileNameView)
        #expect(nextPagedResults.count == 10)
        
        //Test favorites only
        let favoriteResults = await databaseManager.paginateMetadata(favorite: true, type: .all, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate, offsetDate: nil, offsetName: nil)
        #expect(favoriteResults.count == 100)
        
        for fav in favoriteResults {
            #expect(fav.favorite)
        }
        
        //Test images only
        let imageResults = await databaseManager.paginateMetadata(favorite: false, type: .image, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate, offsetDate: nil, offsetName: nil)
        #expect(imageResults.count == 190)
        
        for image in imageResults {
            #expect(image.image)
        }
        
        //Test videos only
        let videoResults = await databaseManager.paginateMetadata(favorite: false, type: .video, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate, offsetDate: nil, offsetName: nil)
        #expect(videoResults.count == 20)
        
        for video in videoResults {
            #expect(video.livePhoto == false)
            #expect(video.video)
        }
    }
    
    @Test func fetchMetadata() async throws {
        
        let account = "account1"
        let serverUrl = "testserver1.com"
        let fromDate = dateFrom("01/01/2001")
        let toDate = dateFrom("01/01/2020")
        var toProcess: [Metadata] = []
        
        for i in 1...200 {
            var metadata = Metadata.init(ocId: "ocid" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: serverUrl)
            if i.isMultiple(of: 2) {
                metadata.favorite = true
            }
            if i.isMultiple(of: 10) {
                metadata.classFile = Global.FileType.video.rawValue
            }
            toProcess.append(metadata)
        }
        
        for i in 1...10 {
            let livePhoto = Metadata.init(ocId: "ocid1_" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2002"), fileId: "123_" + i.description, fileName: "file1_" + i.description, livePhotoFile: "456_" + i.description, serverUrl: serverUrl)
            let livePhotoVideo = Metadata.init(ocId: "ocid2_" + i.description, account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2002"), fileId: "456_" + i.description, fileName: "file2_" + i.description, livePhotoFile: "123_" + i.description, serverUrl: serverUrl)
            toProcess.append(livePhoto)
            toProcess.append(livePhotoVideo)
        }
        
        let results = await databaseManager.processMetadatas(toProcess, metadatasResult: [])
        #expect(results.added.count == 210)
        
        //Test fetching all
        let fetched = await databaseManager.fetchMetadata(favorite: false, type: .all, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate)
        #expect(fetched.count == 210)
        
        //Test fetching favorites
        let favorites = await databaseManager.fetchMetadata(favorite: true, type: .all, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate)
        #expect(favorites.count == 100)
        
        for fav in favorites {
            #expect(fav.favorite)
        }
        
        //Test fetching images only
        let images = await databaseManager.fetchMetadata(favorite: false, type: .image, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate)
        #expect(images.count == 190)
        
        for image in images {
            #expect(image.image)
        }
        
        //Test fetching videos only
        let videos = await databaseManager.fetchMetadata(favorite: false, type: .video, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate)
        #expect(videos.count == 20)
        
        for video in videos {
            #expect(video.livePhoto == false)
            #expect(video.video)
        }
        
        //Test filtering by date
        let dateFiltered = await databaseManager.fetchMetadata(favorite: false, type: .all, account: account, startServerUrl: serverUrl, fromDate: dateFrom("01/01/2001"), toDate: dateFrom("01/01/2001"))
        #expect(dateFiltered.count == 200)
    }
    
    @Test func setMetadataFavorite() async throws {
    
        let metadata1 = Metadata.init(ocId: "ocid1", account: "account1", classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2001"), favorite: false, fileName: "file1", serverUrl: "testserver1.com")
        let metadata2 = Metadata.init(ocId: "ocid2", account: "account1", classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2001"), favorite: true, fileName: "file2", serverUrl: "testserver1.com")
        
        let results = await databaseManager.processMetadatas([metadata1, metadata2], metadatasResult: [])
        #expect(results.added.count == 2)
        
        let favoriteResult = await databaseManager.setMetadataFavorite(ocId: metadata1.ocId, favorite: true)
        #expect(favoriteResult?.favorite == true)
        
        let unfavoriteResult = await databaseManager.setMetadataFavorite(ocId: metadata1.ocId, favorite: false)
        #expect(unfavoriteResult?.favorite == false)
    }
    
    @Test func updateMetadatasFavorite() async throws {
        
        let account = "account1"
        let server = "server.com"
        var toProcess: [Metadata] = []
        
        for i in 1...200 {
            var metadata = Metadata.init(ocId: "ocid" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: server)
            if i.isMultiple(of: 2) {
                metadata.favorite = true
            }
            toProcess.append(metadata)
        }
        
        let results = await databaseManager.processMetadatas(toProcess, metadatasResult: [])
        #expect(results.added.count == 200)
        
        //replace favorites. first 3 exist. last 2 should be inserted.
        let favorite1 = Metadata.init(ocId: "ocid1", account: account, favorite: true, fileName: "file1")
        let favorite2 = Metadata.init(ocId: "ocid2", account: account, favorite: true, fileName: "file2")
        let favorite3 = Metadata.init(ocId: "ocid3", account: account, favorite: true, fileName: "file3")
        let favorite4 = Metadata.init(ocId: "ocidabc", account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), favorite: true, fileName: "fileabc", serverUrl: server)
        let favorite5 = Metadata.init(ocId: "ociddef", account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2001"), favorite: true, fileName: "filedef", serverUrl: server)
        
        await databaseManager.updateMetadatasFavorite(account: account, startServerUrl: server, metadatas: [favorite1, favorite2, favorite3, favorite4, favorite5])
        
        //get all favorites and verify
        let favorites = await databaseManager.fetchMetadata(favorite: true, type: .all, account: account, startServerUrl: server, fromDate: .distantPast, toDate: .distantFuture)
        #expect(favorites.count == 5)
        
        for favorite in favorites {
            #expect(favorite.favorite)
        }
    }
    
    @Test func deleteMetadata() async throws {
        
        let account = "account1"
        let server = "server.com"
        var toProcess: [Metadata] = []
        
        for i in 1...50 {
            let metadata = Metadata.init(ocId: "ocid1_" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: server)
            toProcess.append(metadata)
        }
        
        for i in 1...50 {
            let metadata = Metadata.init(ocId: "ocid2_" + i.description, account: "account2", classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: server)
            toProcess.append(metadata)
        }
        
        for i in 1...50 {
            let metadata = Metadata.init(ocId: "ocid3_" + i.description, account: "account3", classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: server)
            toProcess.append(metadata)
        }
        
        let results = await databaseManager.processMetadatas(toProcess, metadatasResult: [])
        #expect(results.added.count == 150)
        
        await databaseManager.deleteMetadata(account)
        
        let remaining1 = await databaseManager.fetchMetadata(favorite: false, type: .all, account: account, startServerUrl: server, fromDate: .distantPast, toDate: .distantFuture)
        #expect(remaining1.count == 0)
        
        let remaining2 = await databaseManager.fetchMetadata(favorite: false, type: .all, account: "account2", startServerUrl: server, fromDate: .distantPast, toDate: .distantFuture)
        #expect(remaining2.count == 50)
        
        let remaining3 = await databaseManager.fetchMetadata(favorite: false, type: .all, account: "account3", startServerUrl: server, fromDate: .distantPast, toDate: .distantFuture)
        #expect(remaining3.count == 50)
    }
    
    private func dateFrom(_ value: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy"
        return dateFormatter.date(from: value)!
    }
}
