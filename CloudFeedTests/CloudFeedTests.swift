//
//  CloudFeedTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 3/11/23.
//

@testable import CloudFeed
import XCTest

final class CloudFeedTests: XCTestCase {
    
    private static let account = "Test Account 1"
    private static let urlBase = "testurlbase1.com"
    private static let username = "testusername1"
    private static let password = "testpassword1"
    
    override class func setUp() {
        super.setUp()
        
        print("CLASS SETUP")
        
        let dataSource = MockDatabaseManager()
        dataSource.setup()
        
        Environment.current.initServicesFor(nextcloudService: MockNextcloudKitService(), databaseManager: dataSource)
        Environment.current.dataService.addAccount(account, urlBase: urlBase, user: username, password: password)

        let tableAccount = Environment.current.dataService.setActiveAccount(account)
        XCTAssertNotNil(tableAccount)
        
        Environment.current.setupFor(account: account, urlBase: urlBase, user: username, userId: tableAccount!.userId, password: password)

    }

    func testCurrentUser() throws {
        
        let currentUser = Environment.current.currentUser
        
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.account, CloudFeedTests.account)
    }
    
    func testGetFavorites() async throws {

        let favMetadatas = await Environment.current.dataService.getFavorites()
        
        XCTAssertNotNil(favMetadatas)
        
        //4 metadata files total. 2 belong to 1 live photo
        XCTAssertEqual(favMetadatas?.count, 4)
    }
    
    func testSearchMedia() async throws {
        
        //let result = await Environment.current.dataService.searchMedia(account: <#T##String#>, mediaPath: <#T##String#>, startServerUrl: <#T##String#>, lessDate: <#T##Date#>, greaterDate: <#T##Date#>, limit: <#T##Int#>)
    }
}
