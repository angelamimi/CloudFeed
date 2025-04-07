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
    
    deinit {
        MainActor.assumeIsolated {
            cleanup()
        }
    }

    @Test("DataService.searchMedia")
    func searchMediaTest() async throws {
        
        let toDate = Date()
        let fromDate = Date()
        
        let result = await dataService?.searchMedia(type: .all, toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, limit: 20)
        
        try #require(result != nil)
        
        #expect(result?.added.count == 26)
        #expect(result?.updated.count == 0)
        #expect(result?.deleted.count == 0)
        #expect(result?.metadatas.count == 0)
    }
    
    @Test("FavoritesViewModel.fetch", arguments: [CloudFeed.Global.FilterType.all, .video, .image])
    func fetchFavoritesTest(type: CloudFeed.Global.FilterType) async {
        
        let cacheManager = CacheManager(dataService: dataService!)
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout())
        
        await confirmation() { confirm in
            let delegate = MockFavoritesDelegate(onFetchResultReceived: { resultItemCount in
                switch type {
                case .all:
                    #expect(resultItemCount == 5)
                case .image:
                    #expect(resultItemCount == 4)
                case .video:
                    #expect(resultItemCount == 1)
                }
                confirm()
            })
            let viewModel = FavoritesViewModel(delegate: delegate, dataService: dataService!, cacheManager: cacheManager)
            viewModel.initDataSource(collectionView: collectionView)
            await viewModel.fetch(type: type, refresh: false)
        }
    }
    
    @Test("MediaViewModel.metadataSearch", arguments: [CloudFeed.Global.FilterType.all, .video, .image])
    func metadataSearchTest(type: CloudFeed.Global.FilterType) async throws {
        
        let toDate = Date.distantFuture
        let fromDate = Date.distantPast
        
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout())
        
        let cacheManager = CacheManager(dataService: dataService!)
        
        await confirmation() { confirm in
            
            let delegate = MockMediaDelegate(onSearchResultReceived: { resultItemCount in
                switch type {
                case .all:
                    #expect(resultItemCount == 25)
                case .image:
                    #expect(resultItemCount == 23)
                case .video:
                    #expect(resultItemCount == 2)
                }
                confirm()
            })
            
            mediaViewModel = MediaViewModel(delegate: delegate, dataService: dataService!, cacheManager: cacheManager)
            
            mediaViewModel?.initDataSource(collectionView: collectionView)

            await mediaViewModel?.metadataSearch(type: type, toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, refresh: false)
        }
    }
    
    private func setup() throws {
        
        databaseManager = DatabaseManager()
        #expect(databaseManager != nil)
        
        let store = StoreUtility()
        let fileUrl = store.databaseDirectory?.appending(path: "CloudFeedTest.realm")
        #expect(fileUrl != nil)

        let setupResult = databaseManager!.setup(fileUrl: fileUrl!)
        #expect(setupResult == false)
        
        nextCloudService = MockNextcloudKitService()
        #expect(nextCloudService != nil)
        
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
    
    private func cleanup() {
        databaseManager?.removeDatabase()
    }
}

final class MockFavoritesDelegate: FavoritesDelegate {
    
    let onFetchResultReceived: ((Int) -> Void)
    
    init(onFetchResultReceived: @escaping (Int) -> Void) {
        self.onFetchResultReceived = onFetchResultReceived
    }
    
    func fetching() {}
    func dataSourceUpdated(refresh: Bool) {}
    func bulkEditFinished(error: Bool) {}
    func editCellUpdated(cell: CloudFeed.CollectionViewCell, indexPath: IndexPath) {}
    
    func fetchResultReceived(resultItemCount: Int?) {
        onFetchResultReceived(resultItemCount ?? -1)
    }
}

final class MockMediaDelegate: MediaDelegate {
    
    let onSearchResultReceived: ((Int) -> Void)
    
    init(onSearchResultReceived: @escaping ((Int) -> Void)) {
        self.onSearchResultReceived = onSearchResultReceived
    }
    
    func dataSourceUpdated(refresh: Bool) {}
    func favoriteUpdated(error: Bool) {}
    func searching() {}
    
    func searchResultReceived(resultItemCount: Int?) {
        onSearchResultReceived(resultItemCount ?? -1)
    }
}
