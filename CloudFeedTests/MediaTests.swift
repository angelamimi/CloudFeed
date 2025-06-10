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
    
    init() async throws {
        try await setup()
    }
    
    deinit {
        MainActor.assumeIsolated {
            cleanup()
        }
    }

    @Test("DataService.searchMedia", arguments: [CloudFeed.Global.FilterType.all, .video, .image])
    func searchMediaTest(type: CloudFeed.Global.FilterType) async throws {
        
        let toDate = Date.distantFuture
        let fromDate = Date.distantPast
        
        let result = await dataService?.searchMedia(type: type, toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, limit: 20)
        
        try #require(result != nil)

        #expect(result?.updated.count == 0)
        #expect(result?.deleted.count == 0)
        
        switch type {
        case .all:
            #expect(result?.added.count == 26)
            #expect(result?.metadatas.count == 25)
        case .image:
            #expect(result?.added.count == 24)
            #expect(result?.metadatas.count == 23)
        case .video:
            #expect(result?.added.count == 2)
            #expect(result?.metadatas.count == 2)
        }
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
            
            let coordinator = FavoritesCoordinator(navigationController: UINavigationController(), dataService: dataService!)
            let viewModel = FavoritesViewModel(delegate: delegate, dataService: dataService!, cacheManager: cacheManager, coordinator: coordinator)
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
            
            let coordinator = MediaCoordinator(navigationController: UINavigationController(), dataService: dataService!)
            let mediaViewModel = MediaViewModel(delegate: delegate, dataService: dataService!, cacheManager: cacheManager, coordinator: coordinator)
            mediaViewModel.initDataSource(collectionView: collectionView)

            await mediaViewModel.metadataSearch(type: type, toDate: toDate, fromDate: fromDate, offsetDate: nil, offsetName: nil, refresh: false)
        }
    }
    
    @Test("MediaViewModel.filter", arguments: [CloudFeed.Global.FilterType.all, .video, .image])
    func filterTest(type: CloudFeed.Global.FilterType) async throws {
        
        let toDate = try Date("2024-12-31T00:00:00Z", strategy: .iso8601)
        let fromDate = try Date("2022-01-01T00:00:00Z", strategy: .iso8601)
        
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout())
        
        let cacheManager = CacheManager(dataService: dataService!)
        
        await confirmation() { confirm in
            
            let delegate = MockMediaDelegate(onSearchResultReceived: { resultItemCount in

                switch type {
                case .all:
                    #expect(resultItemCount == 4)
                case .image:
                    #expect(resultItemCount == 2)
                case .video:
                    #expect(resultItemCount == 2)
                }
                confirm()
            })
            
            let coordinator = MediaCoordinator(navigationController: UINavigationController(), dataService: dataService!)
            let mediaViewModel = MediaViewModel(delegate: delegate, dataService: dataService!, cacheManager: cacheManager, coordinator: coordinator)
            mediaViewModel.initDataSource(collectionView: collectionView)
            
            await mediaViewModel.filter(type: type, toDate: toDate, fromDate: fromDate)
        }
    }
    
    private func setup() async throws {
        
        databaseManager = DatabaseManager(modelContainer: DatabaseManager.test)
        #expect(databaseManager != nil)
        
        let store = StoreUtility()
        let fileUrl = store.databaseDirectory?.appending(path: "CloudFeedTest.realm")
        #expect(fileUrl != nil)

        //let setupResult = databaseManager!.setup(fileUrl: fileUrl!)
        //#expect(setupResult == false)
        
        nextCloudService = MockNextcloudKitService()
        #expect(nextCloudService != nil)
        
        dataService = DataService(store: store, nextcloudService: nextCloudService!, databaseManager: databaseManager!)
        #expect(dataService != nil)

        await dataService?.addAccount(account, urlBase: urlBase, user: username, password: password)

        let tableAccount = await dataService?.setActiveAccount(account)
        #expect(tableAccount != nil)
        
        let activeAccount = await dataService?.getActiveAccount()
        #expect(activeAccount != nil)
        
        Environment.current.setCurrentUser(account: activeAccount!.account, urlBase: activeAccount!.urlBase, user: activeAccount!.user, userId: activeAccount!.userId)
    }
    
    private func cleanup() {
        //databaseManager?.removeDatabase()
    }
}

final class MockFavoritesDelegate: FavoritesDelegate {

    let onFetchResultReceived: ((Int) -> Void)
    
    init(onFetchResultReceived: @escaping (Int) -> Void) {
        self.onFetchResultReceived = onFetchResultReceived
    }
    
    func shareComplete() {}
    func progressUpdated(_ progress: Double) {}
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
    func shareComplete() {}
    func progressUpdated(_ progress: Double) {}
    func selectCellUpdated(cell: CloudFeed.CollectionViewCell, indexPath: IndexPath) {}
    
    func searchResultReceived(resultItemCount: Int?) {
        onSearchResultReceived(resultItemCount ?? -1)
    }
}
