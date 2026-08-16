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
        databaseManager = DatabaseManager(modelContainer: DatabaseManager.memoryContainer())
    }

    @Test func getMetadataFromOcId() async throws {

        let metadata1 = Metadata(ocId: "ocid1", account: "account1", classFile: Global.FileType.image.rawValue, fileName: "file1", serverUrl: "server1")
        let metadata2 = Metadata(ocId: "ocid2", account: "account1", classFile: Global.FileType.image.rawValue, fileName: "file2", serverUrl: "server1")
        let metadata3 = Metadata(ocId: "ocid3", account: "account1", classFile: Global.FileType.image.rawValue, fileName: "file3", serverUrl: "server1")
        let metadata4 = Metadata(ocId: "ocid4", account: "account1", classFile: Global.FileType.image.rawValue, fileName: "file4", serverUrl: "server1")
        let metadata5 = Metadata(ocId: "ocid5", account: "account2", classFile: Global.FileType.image.rawValue, fileName: "file4", serverUrl: "server2")

        await databaseManager.syncMetadatas(local: [], remote: [metadata1, metadata2, metadata3, metadata4, metadata5], fromDate: .distantPast, toDate: .distantFuture)
        let current = await databaseManager.getMetadatas(account: "account1", startServerUrl: "server1", fromDate: .distantPast, toDate: .distantFuture)

        #expect(current.count == 4)

        let result = await databaseManager.getMetadataFromOcId(metadata4.ocId)

        #expect(result?.ocId == metadata4.ocId)
    }

    @Test func syncMetadatas() async throws {

        let metadata1 = Metadata(ocId: "ocid1", account: "account1", classFile: Global.FileType.image.rawValue, fileName: "file1", serverUrl: "server1")
        let metadata2 = Metadata(ocId: "ocid2", account: "account1", classFile: Global.FileType.image.rawValue, fileName: "file2", serverUrl: "server1")
        let metadata3 = Metadata(ocId: "ocid3", account: "account1", classFile: Global.FileType.image.rawValue, fileName: "file3", serverUrl: "server1")
        let metadata4 = Metadata(ocId: "ocid4", account: "account1", classFile: Global.FileType.image.rawValue, fileName: "file4", serverUrl: "server1")
        let metadata5 = Metadata(ocId: "ocid5", account: "account2", classFile: Global.FileType.image.rawValue, fileName: "file4", serverUrl: "server2")

        //Test insert
        await databaseManager.syncMetadatas(local: [], remote: [metadata1, metadata2, metadata3, metadata4, metadata5], fromDate: .distantPast, toDate: .distantFuture)
        let addResults = await databaseManager.getMetadatas(account: "account1", startServerUrl: "server1", fromDate: .distantPast, toDate: .distantFuture)

        #expect(addResults.count == 4)

        //Test update
        let updatedMetadata3 = Metadata(ocId: "ocid3", account: "account1", classFile: Global.FileType.image.rawValue, favorite: true, fileName: "file3", serverUrl: "server1")

        await databaseManager.syncMetadatas(local: [metadata1, metadata2, metadata3, metadata4, metadata5], remote: [metadata1, metadata2, updatedMetadata3, metadata4, metadata5], fromDate: .distantPast, toDate: .distantFuture)
        let updateResults = await databaseManager.getMetadatas(account: "account1", startServerUrl: "server1", fromDate: .distantPast, toDate: .distantFuture)

        #expect(updateResults.count == 4)

        let updatedMetadata = updateResults.first(where: { $0.ocId == "ocid3" && $0.favorite == true })
        #expect(updatedMetadata != nil)

        //Test delete
        let toDeleteResults = await databaseManager.getMetadatas(account: "account1", startServerUrl: "server1", fromDate: .distantPast, toDate: .distantFuture)
        await databaseManager.syncMetadatas(local: toDeleteResults, remote: [metadata2], fromDate: .distantPast, toDate: .distantFuture)

        let result1 = await databaseManager.getMetadataFromOcId(metadata1.ocId)
        #expect(result1 == nil)

        let result2 = await databaseManager.getMetadataFromOcId(metadata2.ocId)
        #expect(result2 != nil)

        let result3 = await databaseManager.getMetadataFromOcId(metadata3.ocId)
        #expect(result3 == nil)

        let result4 = await databaseManager.getMetadataFromOcId(metadata4.ocId)
        #expect(result4 == nil)
    }

    /*@Test func processMetadatas() async throws {

        let metadata1 = Metadata(ocId: "ocid1", account: "account1", fileName: "file1")
        let metadata2 = Metadata(ocId: "ocid2", account: "account1", fileName: "file2")
        var metadata3 = Metadata(ocId: "ocid3", account: "account1", fileName: "file3")
        let metadata4 = Metadata(ocId: "ocid4", account: "account1", fileName: "file4")

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
    }*/

    @Test func getMetadatas() async throws {

        let account = "account1"
        let serverUrl = "testserver1.com"
        let fromDate = dateFrom("01/01/2001")
        let toDate = dateFrom("01/01/2020")

        let metadata1 = Metadata(ocId: "ocid1", account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2001"), fileName: "file1", serverUrl: serverUrl)
        let metadata2 = Metadata(ocId: "ocid2", account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2002"), fileName: "file2", serverUrl: serverUrl)
        let metadata3 = Metadata(ocId: "ocid3", account: "account2", classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2003"), fileName: "file3", serverUrl: "testserver2.com")
        let metadata4 = Metadata(ocId: "ocid4", account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2004"), fileName: "file4", serverUrl: serverUrl)
        let metadata5 = Metadata(ocId: "ocid5", account: "account2", classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2020"), fileName: "file5", serverUrl: "testserver2.com")
        let metadata6 = Metadata(ocId: "ocid6", account: "account3", classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2021"), fileName: "file6", serverUrl: "testserver3.com")
        let metadata7 = Metadata(ocId: "ocid7", account: account, classFile: Global.FileType.document.rawValue, date: dateFrom("01/01/2022"), fileName: "file7", serverUrl: serverUrl)
        let metadata8 = Metadata(ocId: "ocid8", account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2024"), fileName: "file8", serverUrl: serverUrl)

        await databaseManager.syncMetadatas(local: [], remote: [metadata1, metadata2, metadata3, metadata4, metadata5, metadata6, metadata7, metadata8], fromDate: .distantPast, toDate: .distantFuture)

        let metadatas = await databaseManager.getMetadatas(account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate)

        #expect(metadatas.count == 3)

        for metadata in metadatas {
            #expect(metadata.account == account)
            #expect(metadata.serverUrl == serverUrl)
            #expect(metadata.classFile == Global.FileType.image.rawValue || metadata.classFile == Global.FileType.video.rawValue)
            #expect(metadata.date >= fromDate && metadata.date <= toDate)
        }
    }

    @Test func getMetadataLivePhoto() async throws {

        let metadata1 = Metadata(ocId: "ocid1", account: "account1", classFile: Global.FileType.image.rawValue, fileId: "123", fileName: "file1", livePhotoFile: "456", serverUrl: "testserver1.com")
        let metadata2 = Metadata(ocId: "ocid2", account: "account1", classFile: Global.FileType.video.rawValue, fileId: "456", fileName: "file2", livePhotoFile: "123", serverUrl: "testserver1.com")

        await databaseManager.syncMetadatas(local: [], remote: [metadata1, metadata2], fromDate: .distantPast, toDate: .distantFuture)

        let metadatas = await databaseManager.getMetadatas(account: "account1", startServerUrl: "testserver1.com", fromDate: .distantPast, toDate: .distantFuture)
        #expect(metadatas.count == 2)

        var imageMetadata: Metadata?
        for metadata in metadatas {
            if metadata.classFile == Global.FileType.image.rawValue {
                imageMetadata = metadata
            }
        }

        #expect(imageMetadata != nil)

        if imageMetadata != nil {

            let video = await databaseManager.getMetadataLivePhoto(metadata: imageMetadata!)

            #expect(video != nil)
            #expect(video?.video == true)
            #expect(video?.fileId == metadata1.livePhotoFile)
        }
    }

    /*@Test func paginateMetadata() async throws {

        let account = "account1"
        let serverUrl = "testserver1.com"
        let fromDate = dateFrom("01/01/2001")
        let toDate = dateFrom("01/01/2020")
        var toProcess: [Metadata] = []

        for i in 1...200 {
            var metadata = Metadata(ocId: "ocid" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: serverUrl)
            if i.isMultiple(of: 2) {
                metadata.favorite = true
            }
            if i.isMultiple(of: 10) {
                metadata.classFile = Global.FileType.video.rawValue
            }
            toProcess.append(metadata)
        }

        for i in 1...10 {
            let livePhoto = Metadata(ocId: "ocid1_" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2002"), fileId: "123_" + i.description, fileName: "file1_" + i.description, livePhotoFile: "456_" + i.description, serverUrl: serverUrl)
            let livePhotoVideo = Metadata(ocId: "ocid2_" + i.description, account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2002"), fileId: "456_" + i.description, fileName: "file2_" + i.description, livePhotoFile: "123_" + i.description, serverUrl: serverUrl)
            toProcess.append(livePhoto)
            toProcess.append(livePhotoVideo)
        }

        let results = await databaseManager.processMetadatas(toProcess, metadatasResult: [])
        #expect(results.added.count == 210)

        //Test pagination
        let pagedResults = await databaseManager.paginateMetadata(favorite: false, type: .all, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate, offsetDate: nil, offsetName: nil)
        #expect(pagedResults.count == 200)

        let last = pagedResults[pagedResults.count - 1]
        let nextPagedResults = await databaseManager.paginateMetadata(favorite: false, type: .all, account: account, startServerUrl: serverUrl, fromDate: fromDate, toDate: toDate, offsetDate: last.date, offsetName: last.fileNameView)
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
    }*/

    @Test func fetchMetadata() async throws {

        let account = "account1"
        let serverUrl = "testserver1.com"
        let fromDate = dateFrom("01/01/2001")
        let toDate = dateFrom("01/01/2020")
        var toProcess: [Metadata] = []

        for i in 1...200 {
            var metadata = Metadata(ocId: "ocid" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: serverUrl)
            if i.isMultiple(of: 2) {
                metadata.favorite = true
            }
            if i.isMultiple(of: 10) {
                metadata.classFile = Global.FileType.video.rawValue
            }
            toProcess.append(metadata)
        }

        for i in 1...10 {
            let livePhoto = Metadata(ocId: "ocid1_" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2002"), fileId: "123_" + i.description, fileName: "file1_" + i.description, livePhotoFile: "456_" + i.description, serverUrl: serverUrl)
            let livePhotoVideo = Metadata(ocId: "ocid2_" + i.description, account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2002"), fileId: "456_" + i.description, fileName: "file2_" + i.description, livePhotoFile: "123_" + i.description, serverUrl: serverUrl)
            toProcess.append(livePhoto)
            toProcess.append(livePhotoVideo)
        }

        //Test setup
        await databaseManager.syncMetadatas(local: [], remote: toProcess, fromDate: .distantPast, toDate: .distantFuture)
        let results = await databaseManager.getMetadatas(account: account, startServerUrl: serverUrl, fromDate: .distantPast, toDate: .distantFuture)
        #expect(results.count == 220)

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

        let metadata1 = Metadata(ocId: "ocid1", account: "account1", classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2001"), favorite: false, fileName: "file1", serverUrl: "testserver1.com")
        let metadata2 = Metadata(ocId: "ocid2", account: "account1", classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2001"), favorite: true, fileName: "file2", serverUrl: "testserver1.com")

        await databaseManager.syncMetadatas(local: [], remote: [metadata1, metadata2], fromDate: .distantPast, toDate: .distantFuture)
        let results = await databaseManager.getMetadatas(account: "account1", startServerUrl: "testserver1.com", fromDate: .distantPast, toDate: .distantFuture)
        #expect(results.count == 2)

        let favoriteResult = await databaseManager.setMetadataFavorite(ocId: metadata1.ocId, favorite: true)
        #expect(favoriteResult?.favorite == true)

        let unfavoriteResult = await databaseManager.setMetadataFavorite(ocId: metadata1.ocId, favorite: false)
        #expect(unfavoriteResult?.favorite == false)
    }

    @Test func syncFavorites() async throws {

        let account = "account1"
        let server = "server.com"
        var toProcess: [Metadata] = []

        for i in 1...200 {
            var metadata = Metadata(ocId: "ocid" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: server)
            if i.isMultiple(of: 2) {
                metadata.favorite = true
            }
            toProcess.append(metadata)
        }

        await databaseManager.syncMetadatas(local: [], remote: toProcess, fromDate: .distantPast, toDate: .distantFuture)
        let current = await databaseManager.getMetadatas(account: account, startServerUrl: server, fromDate: .distantPast, toDate: .distantFuture)
        #expect(current.count == 200)

        //replace favorites. first 3 exist. last 2 should be inserted.
        let favorite1 = Metadata(ocId: "ocid1", account: account, favorite: true, fileName: "file1")
        let favorite2 = Metadata(ocId: "ocid2", account: account, favorite: true, fileName: "file2")
        let favorite3 = Metadata(ocId: "ocid3", account: account, favorite: true, fileName: "file3")
        let favorite4 = Metadata(ocId: "ocidabc", account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), favorite: true, fileName: "fileabc", serverUrl: server)
        let favorite5 = Metadata(ocId: "ociddef", account: account, classFile: Global.FileType.video.rawValue, date: dateFrom("01/01/2001"), favorite: true, fileName: "filedef", serverUrl: server)

        await databaseManager.syncFavorites(account: account, startServerUrl: server, metadatas: [favorite1, favorite2, favorite3, favorite4, favorite5])

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
            let metadata = Metadata(ocId: "ocid1_" + i.description, account: account, classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: server)
            toProcess.append(metadata)
        }

        for i in 1...50 {
            let metadata = Metadata(ocId: "ocid2_" + i.description, account: "account2", classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: server)
            toProcess.append(metadata)
        }

        for i in 1...50 {
            let metadata = Metadata(ocId: "ocid3_" + i.description, account: "account3", classFile: Global.FileType.image.rawValue, date: dateFrom("01/01/2001"), fileName: "file" + i.description, serverUrl: server)
            toProcess.append(metadata)
        }

        await databaseManager.syncMetadatas(local: [], remote: toProcess, fromDate: .distantPast, toDate: .distantFuture)
        let account1results = await databaseManager.getMetadatas(account: account, startServerUrl: server, fromDate: .distantPast, toDate: .distantFuture)
        #expect(account1results.count == 50)

        let account2results = await databaseManager.getMetadatas(account: "account2", startServerUrl: server, fromDate: .distantPast, toDate: .distantFuture)
        #expect(account2results.count == 50)

        let account3results = await databaseManager.getMetadatas(account: "account3", startServerUrl: server, fromDate: .distantPast, toDate: .distantFuture)
        #expect(account3results.count == 50)

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
