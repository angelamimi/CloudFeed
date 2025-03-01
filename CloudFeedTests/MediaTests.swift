//
//  MediaTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 10/29/24.
//

@testable import CloudFeed
import Testing
import UIKit

@MainActor
class MediaTests {
    
    let account = "testuser1 https://cloud.test1.com"
    let urlBase = "https://cloud.test1.com"
    let username = "testuser1"
    let password = "testpassword1"
    
    var nextCloudService: MockNextcloudKitService?
    var dataService: DataService?
    var databaseManager: DatabaseManager?
    
    var mediaViewModel: MediaViewModel?
    
    init() async throws {
        try setup()
    }

    @Test func searchMediaTest() async throws {
        
        let toDate = Date()
        let fromDate = Date()

        let result = await dataService?.searchMedia(type: .all, toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, limit: 20)
        
        try #require(result != nil)
        
        #expect(result?.added.count == 24)
        #expect(result?.updated.count == 0)
        #expect(result?.deleted.count == 0)
        #expect(result?.metadatas.count == 0)
    }

    /*
     @Test func listingFavoritesTest() async throws {
        
        let error = await dataService?.getFavorites()
        
        #expect(error == false)

        let favMetadatas = dataService?.paginateFavoriteMetadata(type: .all, fromDate: Date.distantPast, toDate: Date.distantFuture, offsetDate: nil, offsetName: nil)
        
        #expect(favMetadatas != nil)
        
        //3 metadata files total. 2 belong to 1 live photo. Live video should be filtered out
        #expect(favMetadatas?.count == 2)
    }*/
    
    /*
     @Test func viewModelTest() async throws {
         
         let cacheManager = CacheManager(dataService: dataService!)
         mediaViewModel = MediaViewModel(delegate: self, dataService: dataService!, cacheManager: cacheManager)
         
         let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout())
         mediaViewModel?.initDataSource(collectionView: collectionView)
         
         let toDate = Date.distantFuture
         let fromDate = Date.distantPast
         mediaViewModel?.metadataSearch(type: .all, toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, refresh: false)
     }
     */
    
    private func setup() throws {
        
        databaseManager = DatabaseManager()
        #expect(databaseManager != nil)
        
        let setupResult = databaseManager!.setup(identifier: "TestDatabase")
        #expect(setupResult == true)
        
        nextCloudService = MockNextcloudKitService()
        
        let store = StoreUtility()
        dataService = DataService(store: store, nextcloudService: nextCloudService!, databaseManager: databaseManager!)
        #expect(dataService != nil)

        dataService?.addAccount(account, urlBase: urlBase, user: username, password: password)

        let tableAccount = dataService?.setActiveAccount(account)
        #expect(tableAccount != nil)
        
        let activeAccount = dataService?.getActiveAccount()
        #expect(activeAccount != nil)
        
        if Environment.current.setCurrentUser(account: activeAccount!.account, urlBase: activeAccount!.urlBase, user: activeAccount!.user, userId: activeAccount!.userId) {
            dataService?.setup(account: activeAccount!.account)
        }
    }
}

/*extension MediaTests: MediaDelegate {
    func dataSourceUpdated(refresh: Bool) {
        print("dataSourceUpdated")
    }
    
    func favoriteUpdated(error: Bool) {
        print("favoriteUpdated")
    }
    
    func searching() {
        print("searching")
    }
    
    func searchResultReceived(resultItemCount: Int?) {
        print("searchResultReceived")
    }
}*/
