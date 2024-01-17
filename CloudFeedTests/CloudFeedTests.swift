//
//  CloudFeedTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 3/11/23.
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

final class CloudFeedTests: BaseTest {
    
    func testCurrentUser() throws {
        
        let currentUser = Environment.current.currentUser
        
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.account, account)
    }
}
