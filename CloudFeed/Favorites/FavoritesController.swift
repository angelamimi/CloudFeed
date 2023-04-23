//
//  FavoritesController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
//

import NextcloudKit
import os.log
import UIKit

class FavoritesController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var emptyView: EmptyView!
    
    private let groupSize = 2 //thumbnail fetches executed concurrently
    
    private var isInitialFetch = false
    private var isEditMode = false
    private var selectOcId: [String] = []
    private var viewerOcId: String? //for scrolling back to correct item after viewing
    
    private var titleView: TitleView?
    private var layout: CollectionLayout?
    private var metadatas: [tableMetadata] = []
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesController.self)
    )
    
    override func viewDidLoad() {
        collectionView.isHidden = true
        emptyView.isHidden = false
        
        navigationController?.isNavigationBarHidden = true
        
        collectionView.delegate = self
        
        initEmptyView()
        initCollectionViewLayout()
        initCollectionViewCell()
        initTitleView()
        
        dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, ocId: String) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            Task {
                await self.setImage(ocId: ocId, cell: cell, indexPath: indexPath)
            }
            return cell
        }
        
        /*var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }*/
        
        initialFetch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        Self.logger.debug("viewWillAppear()")
        
        if metadatas.count == 0 {
            initialFetch()
        } else if !isInitialFetch {
            metadataFetch()
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
    }
    
    private func initCollectionViewCell() {
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "CollectionViewCell")
    }
    
    private func initEmptyView() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 48)
        let image = UIImage(systemName: "star.fill", withConfiguration: configuration)
        
        emptyView.display(image: image, title: "No favorites yet", description: "Files you mark as favorite will show up here")
    }
    
    private func initCollectionViewLayout() {
        layout = CollectionLayout()
        layout?.delegate = self
        layout?.numberOfColumns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
        
        collectionView.collectionViewLayout = layout!
    }
    
    private func initTitleView() {
        titleView = Bundle.main.loadNibNamed("TitleView", owner: self, options: nil)?.first as? TitleView
        self.view.addSubview(titleView!)
        
        titleView?.mediaView = self
        titleView?.initMenu(allowEdit: true)
    }
    
    private func setTitle() {

        titleView?.title.text = ""
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }
        guard indexPath.item < metadatas.count else { return }
        
        //let metadata = metadatas[indexPath.item]
        let metadata = findMetadata(indexPath: indexPath)
        guard metadata != nil else { return }
        titleView?.title.text = StoreUtility.getFormattedDate(metadata!.date as Date)
    }

    private func setImage(ocId: String, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        Self.logger.debug("setImage() - indexPath: \(indexPath)")
        
        /*guard self.metadatas.count > 0 && indexPath.item < self.metadatas.count else { return }

        let metadata = self.metadatas[indexPath.item]
        
        Self.logger.debug("setImage() - indexPath: \(indexPath) ocId: \(metadata.ocId)")
        
        //right ocid is coming through but wrong item from index path??
        if metadata.ocId != ocId {
            Self.logger.error("setImage() - WRONG METADATA! \(metadata.ocId) \(ocId)")
        }*/
        
        let metadata = findMetadata(indexPath: indexPath)
        
        guard metadata != nil else { return }
        
        //TODO: IS OCID THE SAME????
        //let ocid = metadata!.ocId
        let etag = metadata!.etag
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)) {
            cell.imageView.image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag))
            //Self.logger.debug("CELL - image size: \(cell.imageView.image?.size.width ?? -1),\(cell.imageView.image?.size.height ?? -1)")
        }  else {
            Self.logger.debug("setImage() - ocid NOT FOUND indexPath: \(indexPath) ocId: \(ocId)")
            cell.imageView.image = nil
        }
        
        if isEditMode {
            cell.selectMode(true)
            if selectOcId.contains(ocId) {
                //Self.logger.debug("setImage() - select indexpath: \(indexPath)")
                cell.selected(true)
            } else {
                //Self.logger.debug("setImage() - deselect indexpath: \(indexPath)")
                cell.selected(false)
            }
        } else {
            cell.selectMode(false)
        }
    }
    
    private func initialFetch() {
        
        Self.logger.debug("initialFetch()")
        
        isInitialFetch = true
        
        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.appendSections([0])
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
        
        Task {
            guard let resultMetadatas = await getFavorites() else { return }
            await processResult(resultMetadatas: resultMetadatas)
        }
    }
    
    private func metadataFetch() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let resultMetadatas = NextcloudService.shared.getFavoriteMetadatas(account: appDelegate.account)
        
        guard resultMetadatas != nil && resultMetadatas?.count ?? 0 > 0 else { return }
        
        processMetadata(resultMetadatas: resultMetadatas!)
        
        //guard metadatas.count > 0 else { return }
        
        Task {
            await refreshDatasource(metadatas: metadatas)
        }
    }
    
    private func restorePosition() {
        guard viewerOcId != nil else { return }
        
        //let snapshot = dataSource.snapshot()
        //let ids = snapshot.itemIdentifiers(inSection: 0)
        
        //Self.logger.debug("restorePosition() - viewerOcId: \(self.viewerOcId!)")
        //Self.logger.debug("restorePosition() - ids: \(ids)")
        
        guard let indexPath = dataSource.indexPath(for: viewerOcId!) else { return }
        
        Self.logger.debug("restorePosition() - indexPath: \(indexPath)")
        
        viewerOcId = nil
        
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        }
    }
    
    private func getFavorites() async -> [tableMetadata]? {

        Self.logger.debug("getFavorites()")
        let resultMetadatas = await NextcloudService.shared.getFavorites()
        
        Self.logger.debug("getFavorites() - resultMetadatas count: \(resultMetadatas == nil ? -1 : resultMetadatas!.count)")
        
        return resultMetadatas
    }
    
    private func processResult(resultMetadatas: [tableMetadata]) async {
        processMetadata(resultMetadatas: resultMetadatas)
        await processMetadataPage(pageMetadatas: metadatas)
    }
    
    private func processMetadata(resultMetadatas: [tableMetadata]) {
        if resultMetadatas.count > 0 {
            metadatas.removeAll()
            
            //TODO: Allow user to sort?
            let sorted = resultMetadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
            
            //Filter out live photo movies. Only show the jpg in favorites.
            for metadata in sorted {
                if metadata.livePhoto && (metadata.fileNameView as NSString).pathExtension.lowercased() == "mov" {
                    continue
                }
                metadatas.append(metadata)
            }
        }
        
        Self.logger.debug("processMetadata() - new metadata count: \(self.metadatas.count) result count: \(resultMetadatas.count)")
        
        let idArray = metadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        Self.logger.debug("processMetadata() - metadatas: \(idArray)")
    }
    
    /*
     Divides the current page of results into groups of fetch preview tasks to be executed concurrently
     */
    private func processMetadataPage(pageMetadatas: [tableMetadata]) async {
        if pageMetadatas.count == 0 {
            collectionView.isHidden = true
            emptyView.isHidden = false
            
            return
            
            //TODO: Clear the collectionview?
        } else {
            collectionView.isHidden = false
            emptyView.isHidden = true
        }
        
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
                await applyDatasourceChanges(metadatas: groupMetadata)
                
                groupMetadata = []
                //Self.logger.debug("processMetadataPage() - appending: \(pageMetadatas[metadataIndex].ocId)")
                groupMetadata.append(pageMetadatas[metadataIndex])
            }
        }
        
        if groupMetadata.count > 0 {
            //Self.logger.debug("processMetadataPage() - groupMetadata: \(groupMetadata)")
            await executeGroup(metadatas: groupMetadata)
            await applyDatasourceChanges(metadatas: groupMetadata)
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
    
    private func refreshDatasource(metadatas: [tableMetadata]) async {
        var snapshot = dataSource.snapshot()
        
        let ids = snapshot.itemIdentifiers(inSection: 0)
        var ocIdDelete: [String] = []
        
        for id in ids {
            let metadata = metadatas.first(where: { $0.ocId == id })
            if (metadata == nil) {
                ocIdDelete.append(id)
            }
        }
        
        if ocIdDelete.count > 0 {
            Self.logger.debug("refreshDatasource() - ocIdDelete: \(ocIdDelete)")
            snapshot.deleteItems(ocIdDelete)
        }
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true, completion: {
                Task {
                    await self.applyDatasourceChanges(metadatas: self.metadatas)
                }
            })
        }
    }
    
    private func applyDatasourceChanges(metadatas: [tableMetadata]) async {
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
        
        if ocIdAdd.count > 0 {
            snapshot.appendItems(ocIdAdd, toSection: 0)
        }
        
        if ocIdUpdate.count > 0 {
            //snapshot.reconfigureItems(ocIdUpdate)
            snapshot.reloadItems(ocIdUpdate)
        }
        
        Self.logger.debug("applyDatasourceChanges() - ocIdAdd: \(ocIdAdd.count) ocIdUpdate: \(ocIdUpdate.count)")
        Self.logger.debug("applyDatasourceChanges() - ocIdAdd: \(ocIdAdd)")
        
        
        Self.logger.debug("applyDatasourceChanges() - snapshot: \(snapshot.itemIdentifiers(inSection: 0))")
        
        let idArray = metadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        Self.logger.debug("applyDatasourceChanges() - metadatas: \(idArray)")
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true, completion: {
                
                Self.logger.debug("applyDatasourceChanges() - snapshot count: \(snapshot.itemIdentifiers(inSection: 0).count)")
                Self.logger.debug("applyDatasourceChanges() - metadatas count: \(self.metadatas.count)")
                /*
                //last batch of applying changes. put the user back to the image they just viewed details of in the collection
                if (snapshot.itemIdentifiers(inSection: 0).count == self.metadatas.count) {
                    self.restorePosition()
                }
                 */
                if (snapshot.itemIdentifiers(inSection: 0).count == self.metadatas.count) {
                    self.isInitialFetch = false
                }
            })
            self.setTitle()
        }
    }
    
    private func openViewer(_ metadata: tableMetadata) {
        
        guard metadata.classFile == NKCommon.typeClassFile.image.rawValue
                || metadata.classFile == NKCommon.typeClassFile.audio.rawValue
                || metadata.classFile == NKCommon.typeClassFile.video.rawValue else { return }
        
        guard let navigationController = self.navigationController else { return }
        
        let viewerPager: PagerController = UIStoryboard(name: "Viewer", bundle: nil).instantiateInitialViewController() as! PagerController
        
        let metadataIndex = metadatas.firstIndex(where: { $0.ocId == metadata.ocId  })
        if (metadataIndex != nil) {
            viewerPager.currentIndex = metadataIndex!//Int()
        }

        viewerPager.delegate = self
        viewerPager.metadatas = metadatas
        navigationController.pushViewController(viewerPager, animated: true)
    }
    
    private func bulkEdit() async {
        var snapshot = dataSource.snapshot()
        
        for ocId in self.selectOcId {
            let indexes = metadatas.indices.filter { metadatas[$0].ocId == ocId }
            
            if !indexes.isEmpty {
                let metadata = metadatas[indexes[0]]
                Self.logger.debug("endEdit() - metadata fileNameView: \(metadata.fileNameView)")
                
                let error = await NextcloudService.shared.favoriteMetadata(metadata)
                if error == .success {
                    snapshot.deleteItems([ocId])
                } else {
                    //TODO: Show the user a single error for all failed
                    Self.logger.error("endEdit() - ERROR: \(error.errorDescription)")
                }
            }
        }
        
        /*snapshot.reloadSections([0])
        DispatchQueue.main.async {
            self.isEditMode = false
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }*/
        self.isEditMode = false
        //reloadSection()
        initialFetch()
    }
    
    private func reloadSection() {
        
        var snapshot = dataSource.snapshot()
        
        guard snapshot.numberOfSections > 0 else { return }
        snapshot.reloadSections([0])
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    private func findMetadata(indexPath: IndexPath) -> tableMetadata? {
        guard let ocId = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return metadatas.first(where: { $0.ocId == ocId })
    }
}

extension FavoritesController : MediaController {
    
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
        collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        initialFetch()
    }
    
    func edit() {
        isEditMode = true
        reloadSection()
    }
    
    func endEdit() {
        
        Self.logger.debug("endEdit() - selectOcId: \(self.selectOcId)")
            
        Task {
            await bulkEdit()
        }
    }
    
    func cancel() {
        self.selectOcId = []
        isEditMode = false
        reloadSection()
    }
}

extension FavoritesController : CollectionLayoutDelegate {
    
    func collectionView(_ collectionView: UICollectionView, sizeOfPhotoAtIndexPath indexPath: IndexPath) -> CGSize {
        
        //TODO: SHOULDN'T NEED TO DO THIS CHECK
        //guard indexPath.item < self.metadatas.count else { return CGSize(width: 0, height: 0) }
        
        //let metadata = self.metadatas[indexPath.item]
        
        let metadata = findMetadata(indexPath: indexPath)
        
        guard metadata != nil else { return CGSize(width: 0, height: 0) }
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata!.ocId, etag: metadata!.etag)) {
            let image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata!.ocId, etag: metadata!.etag))
            if image != nil {
                return image!.size
            }
        }  else {
            Self.logger.debug("sizeOfPhotoAtIndexPath - ocid NOT FOUND indexPath: \(indexPath) ocId: \(metadata!.ocId)")
        }
        
        return CGSize(width: 0, height: 0)
    }
}

extension FavoritesController : UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        setTitle()
    }
}

extension FavoritesController: PagerControllerDelegate {
    
    func viewerDidFinish(ocId: String) {
        /*guard let indexPath = dataSource.indexPath(for: ocId) else { return }
        Self.logger.debug("viewerDidFinish() - indexPath: \(indexPath)")
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        }*/
        Self.logger.debug("viewerDidFinish() - ocId: \(ocId)")
        viewerOcId = ocId
    }
}

extension FavoritesController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        Self.logger.debug("collectionView.didSelectItemAt() - indexPath: \(indexPath)")
        
        //let metadata = metadatas[indexPath.item]
        
        guard let ocId = dataSource.itemIdentifier(for: indexPath) else { return }
        
        //Self.logger.debug("collectionView.didSelectItemAt() - ocId: \(ocId) metadata ocId: \(metadata!.ocId)")

        if isEditMode {
            
            //Self.logger.debug("collectionView.didSelectItemAt() - selectOcId: \(self.selectOcId)")

            if let index = selectOcId.firstIndex(of: ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(ocId)
            }
            if indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) {
                Self.logger.debug("collectionView.didSelectItemAt() - reloadItems at indexPath: \(indexPath)")
                Self.logger.debug("collectionView.didSelectItemAt() - selectOcId: \(self.selectOcId)")
                

                
                var snapshot = dataSource.snapshot()
                
                let ids = snapshot.itemIdentifiers(inSection: 0)
                Self.logger.debug("collectionView.didSelectItemAt() - ids1: \(ids)")
                
                
                let idArray = metadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
                Self.logger.debug("collectionView.didSelectItemAt() - ids2: \(idArray)")

                //snapshot.reloadItems([metadata.ocId])
                snapshot.reconfigureItems([ocId])
                
                DispatchQueue.main.async {
                    self.dataSource.apply(snapshot, animatingDifferences: true)
                }
            }
        } else {
            let metadata = findMetadata(indexPath: indexPath)
            if metadata != nil {
                openViewer(metadata!)
            }
        }
    }
}
