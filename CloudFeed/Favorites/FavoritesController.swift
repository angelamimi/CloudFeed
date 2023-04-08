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
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Self.logger.debug("viewDidAppear()")

        initialFetch()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        titleView?.translatesAutoresizingMaskIntoConstraints = false
        titleView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        titleView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        titleView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        titleView?.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    private func initCollectionViewCell() {
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "CollectionViewCell")
        //collectionView.delegate = self
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
        titleView?.initMenu(allowEdit: false)
    }
    
    private func setTitle() {

        titleView?.title.text = ""
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }
        guard indexPath.item < metadatas.count else { return }
        
        let metadata = metadatas[indexPath.item]
        titleView?.title.text = StoreUtility.getFormattedDate(metadata.date as Date)
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
    
    private func initialFetch() {
        
        Self.logger.debug("initialFetch()")

        //var snapshot = dataSource.snapshot()
        //snapshot.deleteAllItems()
        //snapshot.appendSections([0])
        
        /*DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }*/
        
        Task {
            guard let resultMetadatas = await getFavorites() else { return }
            await processResult(resultMetadatas: resultMetadatas)
        }
    }
    
    private func getFavorites() async -> [tableMetadata]? {

        Self.logger.debug("getFavorites()")
        let resultMetadatas = await NextcloudService.shared.getFavorites()
        
        Self.logger.debug("getFavorites() - resultMetadatas count: \(resultMetadatas == nil ? -1 : resultMetadatas!.count)")
        
        if resultMetadatas != nil {
            cleanup(result: resultMetadatas!)
        }
        
        return resultMetadatas
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
    
    private func processResult(resultMetadatas: [tableMetadata]) async {
        
        if resultMetadatas.count > 0 {
            metadatas = resultMetadatas
        }
        
        Self.logger.debug("processResult() - new metadata count: \(self.metadatas.count) result count: \(resultMetadatas.count)")
        
        await processMetadataPage(pageMetadatas: metadatas)
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

        viewerPager.metadatas = metadatas
        navigationController.pushViewController(viewerPager, animated: true)
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
    
    func edit() {}
    func endEdit() {}
    func cancel() {}
}

extension FavoritesController : CollectionLayoutDelegate {
    
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

extension FavoritesController : UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        setTitle()
    }
}

extension FavoritesController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        Self.logger.debug("collectionView.didSelectItemAt() - indexPath: \(indexPath)")
        
        let metadata = metadatas[indexPath.row]
        openViewer(metadata)
    }
}
