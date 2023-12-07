//
//  BaseTest.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 9/26/23.
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
        dbman.setup()
        
        nextCloudService = MockNextcloudKitService()
        
        dataService = DataService(nextcloudService: nextCloudService!, databaseManager: dbman)
        XCTAssertNotNil(dataService)
        
        dataService?.addAccount(account, urlBase: urlBase, user: username, password: password)

        let tableAccount = dataService?.setActiveAccount(account)
        XCTAssertNotNil(tableAccount)
        
        let activeAccount = dataService?.getActiveAccount()
        XCTAssertNotNil(activeAccount)
        
        if Environment.current.setCurrentUser(account: activeAccount!.account, urlBase: activeAccount!.urlBase, user: activeAccount!.user, userId: activeAccount!.userId) {
            let pwd = StoreUtility.getPassword(activeAccount!.account)
            XCTAssertNotNil(pwd)
            dataService?.setup(account: activeAccount!.account, user: activeAccount!.user, userId: activeAccount!.userId, password: pwd!, urlBase: activeAccount!.urlBase)
        }
    }
    
    func clean() {
        dataService = nil
        nextCloudService = nil
    }
}
