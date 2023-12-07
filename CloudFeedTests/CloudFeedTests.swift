//
//  CloudFeedTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 3/11/23.
//

@testable import CloudFeed
import XCTest

final class CloudFeedTests: BaseTest {
    
    func testCurrentUser() throws {
        
        let currentUser = Environment.current.currentUser
        
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.account, account)
    }
}
