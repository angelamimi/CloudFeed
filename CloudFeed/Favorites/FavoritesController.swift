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
    
    var coordinator: FavoritesCoordinator!

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var emptyView: EmptyView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private let groupSize = 2 //thumbnail fetches executed concurrently
    
    private var isEditMode = false
    
    private var titleView: TitleView?
    private var layout: CollectionLayout?

    private var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesController.self)
    )
    
    override func viewDidLoad() {
        collectionView.isHidden = true
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = false
        
        emptyView.isHidden = false
        
        navigationController?.isNavigationBarHidden = true
        
        initEmptyView()
        initCollectionViewLayout()
        initCollectionViewCell()
        initTitleView()
        
        dataSource = UICollectionViewDiffableDataSource<Int, tableMetadata>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, metadata: tableMetadata) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            Task {
                await self.setImage(metadata: metadata, cell: cell, indexPath: indexPath)
            }
            return cell
        }

        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        Self.logger.debug("viewWillAppear()")
        
        if collectionView.numberOfSections == 0 || collectionView.numberOfItems(inSection: 0) == 0 {
            initialFetch()
        } else {
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
        guard dataSource != nil else { return }
        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.appendSections([0])
        dataSource.applySnapshotUsingReloadData(snapshot)
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
    
    private func startActivityIndicator() {
        activityIndicator.startAnimating()
        self.view.isUserInteractionEnabled = false
    }
    
    private func stopActivityIndicator() {
        activityIndicator.stopAnimating()
        self.view.isUserInteractionEnabled = true
    }
    
    private func setTitle() {

        titleView?.title.text = ""
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }

        let metadata = dataSource.itemIdentifier(for: indexPath)
        guard metadata != nil else { return }
        titleView?.title.text = StoreUtility.getFormattedDate(metadata!.date as Date)
    }

    private func setImage(metadata: tableMetadata, cell: CollectionViewCell, indexPath: IndexPath) async {
        
        Self.logger.debug("setImage() - indexPath: \(indexPath)")
        
        let ocId = metadata.ocId
        let etag = metadata.etag
        
        if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)) {
            cell.imageView.image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag))
            //Self.logger.debug("CELL - image size: \(cell.imageView.image?.size.width ?? -1),\(cell.imageView.image?.size.height ?? -1)")
        }  else {
            Self.logger.debug("setImage() - ocid NOT FOUND indexPath: \(indexPath) ocId: \(ocId)")
            cell.imageView.image = nil
        }
        
        if isEditMode {
            cell.selectMode(true)
            if collectionView.indexPathsForSelectedItems?.firstIndex(of: indexPath) != nil {
                cell.selected(true)
            } else {
                cell.selected(false)
            }
        } else {
            cell.selectMode(false)
        }
    }
    
    private func initialFetch() {
        
        Self.logger.debug("initialFetch()")
        
        startActivityIndicator()
        
        Task {
            let resultMetadatas = await getFavorites()
            stopActivityIndicator()
            await processResult(resultMetadatas: resultMetadatas)
        }
    }
    
    private func metadataFetch() {
        
        startActivityIndicator()
        
        guard let account = Environment.current.currentUser?.account else { return }
        let resultMetadatas = Environment.current.dataService.getFavoriteMetadatas(account: account)
        
        stopActivityIndicator()
        
        guard resultMetadatas != nil && resultMetadatas?.count ?? 0 > 0 else { return }
        
        let metadatas = processMetadata(resultMetadatas: resultMetadatas!)
        
        Task {
            await refreshDatasource(metadatas: metadatas)
        }
    }
    
    private func getFavorites() async -> [tableMetadata]? {

        Self.logger.debug("getFavorites()")
        let resultMetadatas = await Environment.current.dataService.getFavorites()
        
        Self.logger.debug("getFavorites() - resultMetadatas count: \(resultMetadatas == nil ? -1 : resultMetadatas!.count)")
        
        return resultMetadatas
    }
    
    private func processResult(resultMetadatas: [tableMetadata]?) async {
        
        guard let resultMetadatas = resultMetadatas else {
            coordinator.showLoadfailedError()
            titleView?.hideMenu()
            return
        }
        
        let metadatas = processMetadata(resultMetadatas: resultMetadatas)
        await processMetadataPage(pageMetadatas: metadatas)
    }
    
    private func processMetadata(resultMetadatas: [tableMetadata]) -> [tableMetadata] {
        
        var metadatas : [tableMetadata] = []
        
        if resultMetadatas.count > 0 {

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
        
        Self.logger.debug("processMetadata() - new metadata count: \(metadatas.count) result count: \(resultMetadatas.count)")
        
        //let idArray = metadatas.map({ (metadata: tableMetadata) -> String in metadata.ocId })
        //Self.logger.debug("processMetadata() - metadatas: \(idArray)")
        
        return metadatas
    }
    
    /*
     Divides the current page of results into groups of fetch preview tasks to be executed concurrently
     */
    private func processMetadataPage(pageMetadatas: [tableMetadata]) async {
        if pageMetadatas.count == 0 {
            collectionView.isHidden = true
            emptyView.isHidden = false
            setTitle()
            titleView?.hideMenu()
            return
            
            //TODO: Clear the collectionview?
        } else {
            collectionView.isHidden = false
            emptyView.isHidden = true
            titleView?.showMenu()
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
                        await Environment.current.dataService.downloadVideoPreview(metadata: metadata)
                    } else if metadata.contentType == "image/svg+xml" || metadata.fileExtension == "svg" {
                        //TODO: Implement svg fetch. Need a library that works.
                    } else {
                        //Self.logger.debug("executeGroup() - contentType: \(metadata.contentType)")
                        await Environment.current.dataService.downloadPreview(metadata: metadata)
                    }
                }
            }
        })
    }
    
    private func refreshDatasource(metadatas: [tableMetadata]) async {
        var snapshot = dataSource.snapshot()
        var delete: [tableMetadata] = []
        
        for currentMetadata in snapshot.itemIdentifiers(inSection: 0) {
            let metadata = metadatas.first(where: { $0.ocId == currentMetadata.ocId })
            if (metadata == nil) {
                delete.append(currentMetadata)
            }
        }
        
        Self.logger.debug("refreshDatasource() - delete count: \(delete.count)")
        
        if delete.count > 0 {
            snapshot.deleteItems(delete)
        }
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true, completion: {
                Task {
                    await self.applyDatasourceChanges(metadatas: metadatas)
                }
            })
        }
    }
    
    private func applyDatasourceChanges(metadatas: [tableMetadata]) async {
        var ocIdAdd : [tableMetadata] = []
        var ocIdUpdate : [tableMetadata] = []
        var snapshot = dataSource.snapshot()
        
        for metadata in metadatas {
            if snapshot.indexOfItem(metadata) == nil {
                ocIdAdd.append(metadata)
            } else {
                ocIdUpdate.append(metadata)
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
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
            self.setTitle()
        }
    }
    
    private func openViewer(indexPath: IndexPath) {
        
        let metadata = dataSource.itemIdentifier(for: indexPath)
        
        guard metadata != nil && (metadata!.classFile == NKCommon.typeClassFile.image.rawValue
                || metadata!.classFile == NKCommon.typeClassFile.audio.rawValue
                || metadata!.classFile == NKCommon.typeClassFile.video.rawValue) else { return }
        
        let snapshot = dataSource.snapshot()
        coordinator.showViewerPager(currentIndex: indexPath.item, metadatas: snapshot.itemIdentifiers(inSection: 0))
    }
    
    private func bulkEdit() async {
        let indexPaths = collectionView.indexPathsForSelectedItems
        
        Self.logger.debug("bulkEdit() - indexPaths: \(indexPaths ?? [])")
        
        guard indexPaths != nil else { return }
        
        var snapshot = dataSource.snapshot()
        
        for indexPath in indexPaths! {
            let metadata = dataSource.itemIdentifier(for: indexPath)
            
            guard metadata != nil else { continue }
            
            let error = await Environment.current.dataService.favoriteMetadata(metadata!)
            if error == .success {
                snapshot.deleteItems([metadata!])
            } else {
                //TODO: Show the user a single error for all failed
                Self.logger.error("bulkEdit() - ERROR: \(error.errorDescription)")
            }
        }

        isEditMode = false
        collectionView.allowsMultipleSelection = false
        
        snapshot.reloadSections([0])
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
            self.setTitle()
            if self.collectionView.numberOfItems(inSection: 0) == 0 {
                self.collectionView.isHidden = true
                self.emptyView.isHidden = false
            }
        }
    }
    
    private func reloadSection() {
        
        var snapshot = dataSource.snapshot()
        
        guard snapshot.numberOfSections > 0 else { return }
        snapshot.reloadSections([0])
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
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
        
        let snapshot = dataSource.snapshot()
        let count = snapshot.numberOfItems(inSection: 0)
        
        guard self.layout!.numberOfColumns + 1 <= count else { return }

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
        collectionView.allowsMultipleSelection = true
        reloadSection()
    }
    
    func endEdit() {
        
        //Self.logger.debug("endEdit() - selectOcId: \(self.selectOcId)")
            
        Task {
            await bulkEdit()
        }
    }
    
    func cancel() {
        //self.selectOcId = []
        
        collectionView.indexPathsForSelectedItems?.forEach { collectionView.deselectItem(at: $0, animated: false) }

        isEditMode = false
        collectionView.allowsMultipleSelection = false
        reloadSection()
    }
}

extension FavoritesController : CollectionLayoutDelegate {
    
    func collectionView(_ collectionView: UICollectionView, sizeOfPhotoAtIndexPath indexPath: IndexPath) -> CGSize {

        let metadata = dataSource.itemIdentifier(for: indexPath)
        
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

extension FavoritesController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Self.logger.debug("collectionView.didSelectItemAt() - indexPath: \(indexPath)")
        if isEditMode {
            if let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell {
                cell.selected(true)
            }
        } else {
            openViewer(indexPath: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        Self.logger.debug("collectionView.didDeselectItemAt() - indexPath: \(indexPath)")
        if isEditMode {
            if let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell {
                cell.selected(false)
            }
        }
    }
}
