//
//  DataLayerAvatarTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 6/9/25.
//

@testable import CloudFeed
import Testing

struct DataLayerAvatarTests {

    private var databaseManager: DatabaseManager
    
    init() async throws {
        databaseManager = DatabaseManager(modelContainer: DatabaseManager.test)
    }

    @Test func addAvatar() async throws {
        
        let fileName = "filename1"
        let etag = "etag1"
        
        await databaseManager.addAvatar(fileName: fileName, etag: "etag1")
        
        let avatar = await databaseManager.getAvatar(fileName: fileName)
        #expect(avatar?.fileName == fileName)
        #expect(avatar?.etag == etag)
    }
    
    @Test func getAvatar() async throws {
        
        let fileName = "filename3"
        let etag = "etag3"
        
        await databaseManager.addAvatar(fileName: "fileName1", etag: "etag1")
        await databaseManager.addAvatar(fileName: "fileName2", etag: "etag2")
        await databaseManager.addAvatar(fileName: fileName, etag: etag)
        await databaseManager.addAvatar(fileName: "fileName4", etag: "etag4")
        
        let avatar = await databaseManager.getAvatar(fileName: fileName)
        #expect(avatar?.fileName == fileName)
        #expect(avatar?.etag == etag)
    }
}
