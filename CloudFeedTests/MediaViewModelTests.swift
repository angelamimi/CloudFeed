//
//  MediaViewModelTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 10/4/23.
//

@testable import CloudFeed
import XCTest

final class MediaViewModelTests: BaseTest {
    
    var mediaViewModel: MediaViewModel?
    var expectation: XCTestExpectation?
    var resultItemCount: Int?

    override func setUpWithError() throws {
        
        try super.setUpWithError()
        
        mediaViewModel = MediaViewModel(delegate: self, dataService: dataService!)
        
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
        mediaViewModel?.initDataSource(collectionView: collectionView)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMetadataSearch() throws {
        
        nextCloudService?.searchMediaAction = .withData
        expectation = expectation(description: "media search")
        
        let offsetDate = Calendar.current.date(from: DateComponents.init(year: 2020, month: 7, day: 4, hour: 3, minute: 31, second: 25))
        mediaViewModel?.metadataSearch(offsetDate: offsetDate!, limit: 10, refresh: false)
        
        waitForExpectations(timeout: 1)
        
        let result = try XCTUnwrap(resultItemCount)
        XCTAssertEqual(result, 23)
    }
}

extension MediaViewModelTests: MediaDelegate {
    func favoriteUpdated(error: Bool) {
        
    }
    
    func searching() {

    }
    
    func dataSourceUpdated() {

    }
    
    func searchResultReceived(resultItemCount: Int?) {
        self.resultItemCount = resultItemCount

        expectation?.fulfill()
        expectation = nil
    }
}
