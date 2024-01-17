//
//  MediaViewModelTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 10/4/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
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

        mediaViewModel?.metadataSearch(offsetDate: offsetDate!, offsetName: nil, limit: 10, refresh: false)
        
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
