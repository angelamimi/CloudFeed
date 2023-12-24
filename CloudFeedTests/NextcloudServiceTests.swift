//
//  NextclouldServiceTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 10/3/23.
//

@testable import CloudFeed
import XCTest

final class NextclouldServiceTests: BaseTest {

    func testFavoritesError() async throws {
        
        nextCloudService?.listingFavoritesAction = .error
        
        let error = await dataService?.getFavorites()
        
        XCTAssertTrue(error == true)
    }
    
    func testFavoritesEmpty() async throws {
        
        nextCloudService?.listingFavoritesAction = .empty
        
        let error = await dataService?.getFavorites()
        
        XCTAssertTrue(error == false)
        
        let favMetadatas = dataService?.paginateFavoriteMetadata(offsetDate: nil, offsetName: nil)
        
        XCTAssertNotNil(favMetadatas)
        XCTAssertEqual(favMetadatas?.count, 0)
    }
    
    func testListingFavorites() async throws {
        
        nextCloudService?.listingFavoritesAction = .withData
        
        let error = await dataService?.getFavorites()
        
        XCTAssertTrue(error == false)

        let favMetadatas = dataService?.paginateFavoriteMetadata(offsetDate: nil, offsetName: nil)
        
        XCTAssertNotNil(favMetadatas)
        
        //3 metadata files total. 2 belong to 1 live photo. Live video should be filtered out
        XCTAssertEqual(favMetadatas?.count, 2)
    }
    
    func testSearchMedia() async throws {
        
        nextCloudService?.searchMediaAction = .withData

        let toDate = Calendar.current.date(from: DateComponents.init(year: 2020, month: 7, day: 4, hour: 3, minute: 31, second: 25))
        let fromDate = Calendar.current.date(byAdding: .day, value: -30, to: toDate!)!
        
        let result = await dataService?.searchMedia(toDate: toDate!, fromDate: fromDate, offsetName: nil, limit: 20)
        
        XCTAssertNotNil(result)
        
        let metadatas = result?.metadatas
        
        XCTAssertNotNil(metadatas)
        XCTAssertEqual(metadatas!.count, 23)
    }
    
    func testSearchMediaError() async throws {
        
        nextCloudService?.searchMediaAction = .error
        
        let toDate = Date()
        let fromDate = Date()
        
        let result = await dataService?.searchMedia(toDate: toDate, fromDate: fromDate, offsetName: "", limit: 20)
        
        XCTAssertNotNil(result)
        
        let metadatas = result?.metadatas
        
        XCTAssertNotNil(metadatas)
        XCTAssertTrue(result!.metadatas.isEmpty)
        
        XCTAssertTrue(result!.error)
    }
    
    func testSearchMediaEmpty() async throws {
        
        nextCloudService?.searchMediaAction = .empty
        
        let toDate = Date()
        let fromDate = Date()
        
        let result = await dataService?.searchMedia(toDate: toDate, fromDate: fromDate, offsetName: "", limit: 20)
        
        XCTAssertNotNil(result)
        
        let metadatas = result?.metadatas
        
        XCTAssertNotNil(metadatas)
        XCTAssertTrue(result!.metadatas.isEmpty)
        
        XCTAssertFalse(result!.error)
    }
}
