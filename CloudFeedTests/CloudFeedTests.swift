//
//  CloudFeedTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 3/11/23.
//

@testable import CloudFeed
import XCTest

final class CloudFeedTests: BaseTest {
    
    override func setUp() {
        initEnvironment()
    }
    
    func testCurrentUser() throws {
        
        let currentUser = Environment.current.currentUser
        
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.account, account)
    }
    
    func testGetFavorites() async throws {

        let favMetadatas = await dataService?.getFavorites()
        
        XCTAssertNotNil(favMetadatas)
        
        //4 metadata files total. 2 belong to 1 live photo
        XCTAssertEqual(favMetadatas?.count, 4)
    }
    
    func testSearchMedia() async throws {
        
        //let result = await dataService?.searchMedia(account: account, mediaPath: <#T##String#>, startServerUrl: <#T##String#>, lessDate: <#T##Date#>, greaterDate: <#T##Date#>, limit: 5)
        
        //let result = await Environment.current.dataService.searchMedia(account: <#T##String#>, mediaPath: <#T##String#>, startServerUrl: <#T##String#>, lessDate: <#T##Date#>, greaterDate: <#T##Date#>, limit: <#T##Int#>)
    }
}
