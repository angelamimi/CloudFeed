//
//  ViewController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import NextcloudKit
import os.log
import UIKit

class MainViewController: UIViewController, MediaController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var loadMoreIndicator: UIActivityIndicatorView!
    
    private let loadMoreThreshold = -80.0
    private let groupSize = 2 //thumbnail fetches executed concurrently
    private let pageSize = 20
    private var pageIndex = 0
    private var greaterDays = -30
    
    private var pageOffsets: [Int] = []
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private var metadatas: [tableMetadata] = []
    private var page: [tableMetadata] = []
    
    private var titleView: TitleView?
    private var layout: CollectionLayout?

    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MainViewController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "CollectionViewCell")
        collectionView.delegate = self
        
        navigationController?.isNavigationBarHidden = true
        
        initCollectionViewLayout()
        initTitleView()
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshDatasource), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        loadMoreIndicator.stopAnimating()
        
        dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, ocId: String) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            Task {
                await self.setImage(ocId: ocId, cell: cell, indexPath: indexPath)
            }
            return cell
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Self.logger.debug("viewDidAppear()")

        if self.metadatas.count == 0 {
            initialSearch()
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        titleView?.translatesAutoresizingMaskIntoConstraints = false
        titleView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        titleView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        titleView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        titleView?.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    public func clear() {
        metadatas = []
        pageOffsets = []
        
        greaterDays = -30
        pageIndex = 0
    }
    
    func updateMetadata(metadata: tableMetadata) {
        Self.logger.debug("updateMetadata() - favorite? \(metadata.favorite)")
        
        let indexCheck = metadatas.firstIndex(where: { $0.ocId == metadata.ocId })
        if indexCheck != nil {
            let index = Int(indexCheck!)
            var snapshot = dataSource.snapshot()
            
            metadatas[index].favorite = metadata.favorite
            
            let snapshotIndex = snapshot.indexOfItem(metadata.ocId)
            if snapshotIndex != nil {
                snapshot.reconfigureItems([metadata.ocId])
                DispatchQueue.main.async {
                    self.dataSource.apply(snapshot, animatingDifferences: true)
                    self.collectionView.isPagingEnabled = false
                    self.collectionView.scrollToItem(at: IndexPath.init(item: Int(snapshotIndex!), section: 0), at: .centeredVertically, animated: false)
                }
            }
        }
    }
    
    func zoomInGrid() {
        guard layout != nil else { return }
        let columns = self.layout?.numberOfColumns ?? 0
        
        if columns - 1 > 0 {
            self.layout?.numberOfColumns -= 1
        }
        
        UIView.animate(withDuration: 0.0, animations: {
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    func zoomOutGrid() {
        guard layout != nil else { return }
        guard self.layout!.numberOfColumns + 1 <= metadatas.count else { return }

        if self.layout!.numberOfColumns + 1 < 6 {
            self.layout!.numberOfColumns += 1
        }
        
        UIView.animate(withDuration: 0.0, animations: {
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    func titleTouched() {
        clear()
        initialSearch()
    }
    
    func edit() {}
    func endEdit() {}
    func cancel() {}
    
    private func initTitleView() {
        titleView = Bundle.main.loadNibNamed("TitleView", owner: self, options: nil)?.first as? TitleView
        self.view.addSubview(titleView!)
        
        titleView?.mediaView = self
        titleView?.initMenu(allowEdit: false)
    }
    
    private func initCollectionViewLayout() {
        layout = CollectionLayout()
        layout?.delegate = self
        layout?.numberOfColumns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2

        collectionView.collectionViewLayout = layout!
    }
    
    private func getMediaPath() -> String? {
        guard let activeAccount = DatabaseManager.shared.getActiveAccount() else { return nil }
        return activeAccount.mediaPath
    }
    
    private func getStartServerUrl() -> String? {
        guard let mediaPath = getMediaPath() else { return nil }
        let startServerUrl = appDelegate.urlBase + "/remote.php/dav/files/" + appDelegate.userId + mediaPath
        
        return startServerUrl
    }
    
    private func initialSearch() {
        
        Self.logger.debug("initialSearch()")

        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.appendSections([0])
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        guard let lessDate = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        guard let greaterDate = Calendar.current.date(byAdding: .day, value: greaterDays, to: lessDate) else { return }
        
        Task {
            guard let resultMetadatas = await search(lessDate: lessDate, greaterDate: greaterDate) else { return }
            await processSearchResult(resultMetadatas: resultMetadatas)
        }
    }
    
    private func loadMore() {
        loadMoreIndicator.startAnimating()
        
        let newPageIndex = pageIndex + 1
        
        if newPageIndex * pageSize < self.metadatas.count {
            Self.logger.debug("loadMore() - going to next page of index: \(newPageIndex)")
            
            pageIndex = newPageIndex
            
            Task {
                Self.logger.debug("loadMore() - call paginateResult pageIndex \(newPageIndex)")
                await paginateResult(pageIndex: newPageIndex)
                DispatchQueue.main.async {
                    self.loadMoreIndicator.stopAnimating()
                }
            }
        } else {
            Self.logger.debug("loadMore() - no more pages??")
            let page = getCurrentPage()
            Self.logger.debug("loadMore() - current page item count: \(page.count)")
            loadMoreIndicator.stopAnimating()
        }
    }
    
    private func processSearchResult(resultMetadatas: [tableMetadata]) async {
        
        if resultMetadatas.count > 0 {
            metadatas = resultMetadatas
        }
        
        Self.logger.debug("processSearchResult() - new metadata count: \(self.metadatas.count) result count: \(resultMetadatas.count)")
        
        //let idArray = metadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("processSearchResult() - all metadata: \(idArray)")
        
        let page = getCurrentPage()
        
        if page.count < pageSize {
            //not enough to fill a page. display what currently have.
            await processMetadataPage(pageMetadatas: metadatas)
            
            //search again with different date range
            let searchDates = calculateSearchDates()
            
            if (searchDates.lessDate != nil && searchDates.greaterDate != nil) {
                guard let resultMetadatas = await search(lessDate: searchDates.lessDate!, greaterDate: searchDates.greaterDate!) else { return }
                await processSearchResult(resultMetadatas: resultMetadatas)
            }

        } else {
            Self.logger.debug("processSearchResult() - call paginateResult pageIndex \(self.pageIndex) metadata count: \(self.metadatas.count)")

            await paginateResult(pageIndex: self.pageIndex)
        }
    }
    
    private func calculateSearchDates() -> (lessDate: Date?, greaterDate: Date?) {
        greaterDays = greaterDays - 30
        
        Self.logger.error("calculateSearchDates() - greaterDays: \(self.greaterDays)")
        
        if greaterDays >= -120 {
            if greaterDays == -120 {
                greaterDays = -999 //go all the way back in time
            } else if greaterDays == -999 {
                return (nil, nil) //gone as far back in time as possible. no more valid date ranges to return
            }
            
            guard let startServerUrl = getStartServerUrl() else { return (nil, nil) }
            let metadataLast = NextcloudService.shared.getMetadata(account: appDelegate.account, startServerUrl: startServerUrl)
            let lessDate = metadataLast != nil ? metadataLast!.date as Date : Date()
            var greaterDate: Date
            
            if (greaterDays == -999) {
                greaterDate = Date.distantPast
            } else {
                greaterDate = Calendar.current.date(byAdding: .day, value: greaterDays, to:lessDate)!
            }
            
            Self.logger.debug("calculateSearchDates() - lessDate: \(lessDate.formatted(date: .abbreviated, time: .omitted)) greaterDate: \(greaterDate.formatted(date: .abbreviated, time: .omitted))")
            return (lessDate, greaterDate)
        }
        
        return (nil, nil)
    }
    
    private func getCurrentPage() -> [tableMetadata] {
        
        var page: [tableMetadata] = []
        
        guard metadatas.count > 0 else { return page }
        
        let pageStartIndex = pageIndex * pageSize
        let pageEndIndex = min(pageStartIndex + (pageSize - 1), metadatas.count - 1)
        
        //grab a slice of 10 based on page index
        page.append(contentsOf: metadatas[pageStartIndex...pageEndIndex])
        
        return page
    }
    
    private func setTitle() {

        titleView?.title.text = ""
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }
        guard indexPath.item < metadatas.count else { return }
        
        let metadata = metadatas[indexPath.item]
        titleView?.title.text = StoreUtility.getFormattedDate(metadata.date as Date)
    }
    
    private func search(lessDate: Date, greaterDate: Date) async -> [tableMetadata]? {
        
        //TODO: SHOW INDICATOR
        
        let mediaPath = getMediaPath()
        let startServerUrl = getStartServerUrl()
        
        guard mediaPath != nil && startServerUrl != nil else { return nil }
        
        Self.logger.debug("search() - lessDate: \(lessDate.formatted(date: .abbreviated, time: .omitted)) greaterDate: \(greaterDate.formatted(date: .abbreviated, time: .omitted))")
        let result = await NextcloudService.shared.searchMedia(account: self.appDelegate.account, mediaPath: mediaPath!, startServerUrl: startServerUrl!, lessDate: lessDate, greaterDate: greaterDate)
        
        Self.logger.debug("search() - result metadatas count: \(result.metadatas.count) error?: \(result.error)")
        
        guard result.error == false else {
            Self.logger.error("search() - error") //TODO: Alert user of error?
            //TODO: HIDE INDICATOR
            return nil
        }
        
        let sorted = result.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
        
        cleanup(result: sorted)
        
        let idArray = sorted.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        Self.logger.debug("search() - sorted: \(idArray)")
        
        return sorted
    }
    
    private func cleanup(result: [tableMetadata]) {
        guard result.count > 0 else { return }
        
        var snapshot = dataSource.snapshot()
        let ids = snapshot.itemIdentifiers(inSection: 0)
        var deleteIds: [String] = []
        
        for id in ids {
            Self.logger.debug("ID: \(id)")
            let metadata = result.first(where: { $0.ocId == id })
            if (metadata == nil) {
                deleteIds.append(id)
            }
        }
        
        if deleteIds.count > 0 {
            Self.logger.debug("cleanup() - deleteIds: \(deleteIds)")
            snapshot.deleteItems(deleteIds)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
        
    }
    
    private func paginateResult(pageIndex: Int) async {
        
        let page = getCurrentPage()
        await processMetadataPage(pageMetadatas: page)
        
        if page.count < pageSize {
            Self.logger.debug("paginateResult() - search again??? page count: \(page.count)")
            
            //TODO: May need to reset search days
            
            //search again with different date range
            let searchDates = calculateSearchDates()
            
            if (searchDates.lessDate != nil && searchDates.greaterDate != nil) {
                guard let resultMetadatas = await search(lessDate: searchDates.lessDate!, greaterDate: searchDates.greaterDate!) else { return }
                await finishPage(currentPage: page, resultMetadatas: resultMetadatas)
                //await processSearchResult(resultMetadatas: resultMetadatas)
            }
        } else {
            Self.logger.debug("paginateResult() - page count: \(page.count)")
        }
    }
    
    private func finishPage(currentPage: [tableMetadata], resultMetadatas: [tableMetadata]) async {
        
        if resultMetadatas.count > 0 {
            metadatas = resultMetadatas
        }
        
        let need = pageSize - currentPage.count
        let page = getCurrentPage()
        
        let idArray = page.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        Self.logger.debug("finishPage() - page: \(idArray)")

        Self.logger.debug("finishPage() - need: \(need) current page count: \(currentPage.count) page count: \(page.count) result count: \(resultMetadatas.count)")
        
        if page.count < pageSize {
            //search again
            Self.logger.debug("finishPage() - search again??")
        } else {
            Self.logger.debug("finishPage() - finish rest of page")
            //have enough to fill the rest of the current page
            //await processMetadataPage(pageMetadatas: Array(resultMetadatas[0...need - 1]))
            await processMetadataPage(pageMetadatas: page)
        }
    }
    
    /*
     Divides the current page of results into groups of fetch preview tasks to be executed concurrently
     */
    private func processMetadataPage(pageMetadatas: [tableMetadata]) async {
        
        guard pageMetadatas.count > 0 else { return }
        
        var groupMetadata: [tableMetadata] = []
        
        //let idArray = pageMetadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("processMetadataPage() - pageMetadatas: \(idArray)")
        
        for metadataIndex in (0...pageMetadatas.count - 1) {
            
            //Self.logger.debug("processMetadataPage() - metadataIndex: \(metadataIndex) pageMetadatas.count \(pageMetadatas.count)")
            
            if groupMetadata.count < groupSize {
                //Self.logger.debug("processMetadataPage() - appending: \(pageMetadatas[metadataIndex].ocId)")
                groupMetadata.append(pageMetadatas[metadataIndex])
            } else {
                await executeGroup(metadatas: groupMetadata)
                applyDatasourceChanges(metadatas: groupMetadata)
                
                groupMetadata = []
                //Self.logger.debug("processMetadataPage() - appending: \(pageMetadatas[metadataIndex].ocId)")
                groupMetadata.append(pageMetadatas[metadataIndex])
            }
        }
        
        if groupMetadata.count > 0 {
            //Self.logger.debug("processMetadataPage() - groupMetadata: \(groupMetadata)")
            await executeGroup(metadatas: groupMetadata)
            applyDatasourceChanges(metadatas: groupMetadata)
        }
    }
    
    private func executeGroup(metadatas: [tableMetadata]) async {
        await withTaskGroup(of: Void.self, returning: Void.self, body: { taskGroup in
            for metadata in metadatas {
                taskGroup.addTask {
                    //Self.logger.debug("executeGroup() - contentType: \(metadata.contentType) fileExtension: \(metadata.fileExtension)")
                    //Self.logger.debug("executeGroup() - ocId: \(metadata.ocId) fileNameView: \(metadata.fileNameView)")
                    if metadata.classFile == NKCommon.typeClassFile.video.rawValue {
                        await NextcloudService.shared.downloadVideoPreview(metadata: metadata)
                    } else if metadata.contentType == "image/svg+xml" || metadata.fileExtension == "svg" {
                        //NextcloudService.shared.downloadSVGPreview(metadata: metadata)
                    } else {
                        //Self.logger.debug("executeGroup() - contentType: \(metadata.contentType)")
                        await NextcloudService.shared.downloadPreview(metadata: metadata)
                    }
                }
            }
        })
    }
    
    private func applyDatasourceChanges(metadatas: [tableMetadata]) {
        var ocIdAdd : [String] = []
        var ocIdUpdate : [String] = []
        var snapshot = dataSource.snapshot()
        
        for metadata in metadatas {
            if snapshot.indexOfItem(metadata.ocId) == nil {
                ocIdAdd.append(metadata.ocId)
            } else {
                ocIdUpdate.append(metadata.ocId)
            }
        }
        
        Self.logger.debug("applyDatasourceChanges() - ocIdAdd: \(ocIdAdd.count) ocIdUpdate: \(ocIdUpdate.count)")
        Self.logger.debug("applyDatasourceChanges() - ocIdAdd: \(ocIdAdd)")
        
        //TODO: Handle removing elements
        
        if ocIdAdd.count > 0 {
            snapshot.appendItems(ocIdAdd, toSection: 0)
        }
        
        if ocIdUpdate.count > 0 {
            snapshot.reconfigureItems(ocIdUpdate)
        }
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
            self.setTitle()
        }
    }
    
    private func setImage(ocId: String, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        guard self.metadatas.count > 0 && indexPath.item < self.metadatas.count else { return }
        
        let metadata = self.metadatas[indexPath.item]
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            cell.imageView.image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            //Self.logger.debug("CELL - image size: \(cell.imageView.image?.size.width ?? -1),\(cell.imageView.image?.size.height ?? -1)")
        }  else {
            Self.logger.debug("CELL - ocid NOT FOUND indexPath: \(indexPath) ocId: \(metadata.ocId)")
        }
    }
    
    @objc func refreshDatasource(refreshControl: UIRefreshControl) {
        Self.logger.debug("refreshDatasource()")
        
        refreshControl.endRefreshing()
        
        clear()
        initialSearch()
    }
    
    func openViewer(_ metadata: tableMetadata) {
        
        guard metadata.classFile == NKCommon.typeClassFile.image.rawValue
                || metadata.classFile == NKCommon.typeClassFile.audio.rawValue
                || metadata.classFile == NKCommon.typeClassFile.video.rawValue else { return }
        
        guard let navigationController = self.navigationController else { return }
        
        let viewerPager: PagerController = UIStoryboard(name: "Viewer", bundle: nil).instantiateInitialViewController() as! PagerController
        
        let metadataIndex = metadatas.firstIndex(where: { $0.ocId == metadata.ocId  })
        if (metadataIndex != nil) {
            viewerPager.currentIndex = metadataIndex!//Int()
        }

        viewerPager.metadatas = metadatas
        navigationController.pushViewController(viewerPager, animated: true)
    }
}

extension MainViewController : CollectionLayoutDelegate {
    
    func collectionView(_ collectionView: UICollectionView, sizeOfPhotoAtIndexPath indexPath: IndexPath) -> CGSize {
        let metadata = self.metadatas[indexPath.item]
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            let image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            if image != nil {
                return image!.size
            }
        }  else {
            Self.logger.debug("sizeOfPhotoAtIndexPath - ocid NOT FOUND indexPath: \(indexPath) ocId: \(metadata.ocId)")
        }
        
        return CGSize(width: 0, height: 0)
    }
}

extension MainViewController : UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        setTitle()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {

        let currentOffset = scrollView.contentOffset.y
        let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height
        let difference = maximumOffset - currentOffset

        if difference <= loadMoreThreshold {
            loadMore()
        }
    }
}

extension MainViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        Self.logger.debug("collectionView.didSelectItemAt() - indexPath: \(indexPath)")
        
        let metadata = metadatas[indexPath.row]
        openViewer(metadata)
    }
}

