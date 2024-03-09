//
//  BaseTest.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 9/26/23.
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

class BaseTest: XCTestCase {
    
    let account = "testuser1 https://cloud.test1.com"
    let urlBase = "https://cloud.test1.com"
    let username = "testuser1"
    let password = "testpassword1"
    
    var nextCloudService: MockNextcloudKitService?
    var dataService: DataService?
    
    override func setUpWithError() throws {
        initEnvironment()
    }

    override func tearDownWithError() throws {
        clean()
    }
    
    func initEnvironment() {
        
        let dbman = MockDatabaseManager()
        let _ = dbman.setup()
        
        nextCloudService = MockNextcloudKitService()
        
        dataService = DataService(nextcloudService: nextCloudService!, databaseManager: dbman)
        XCTAssertNotNil(dataService)
        
        dataService?.addAccount(account, urlBase: urlBase, user: username, password: password)

        let tableAccount = dataService?.setActiveAccount(account)
        XCTAssertNotNil(tableAccount)
        
        let activeAccount = dataService?.getActiveAccount()
        XCTAssertNotNil(activeAccount)
        
        if Environment.current.setCurrentUser(account: activeAccount!.account, urlBase: activeAccount!.urlBase, user: activeAccount!.user, userId: activeAccount!.userId) {
            dataService?.setup(account: activeAccount!.account, user: activeAccount!.user, userId: activeAccount!.userId, urlBase: activeAccount!.urlBase)
        }
    }
    
    func clean() {
        dataService = nil
        nextCloudService = nil
    }
}
