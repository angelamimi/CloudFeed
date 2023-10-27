//
//  FavoritesController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
//
import NextcloudKit
import os.log
import UIKit

class FavoritesController: CollectionController {
    
    var coordinator: FavoritesCoordinator!
    var viewModel: FavoritesViewModel!
    
    private var layout: CollectionLayout?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerCell("CollectionViewCell")
        
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = false
        
        viewModel.initDataSource(collectionView: collectionView)

        initCollectionViewLayout(delegate: self)
        initTitleView(mediaView: self, allowEdit: true)
        initEmptyView(imageSystemName: "star.fill", title:"No favorites yet", description: "Files you mark as favorite will show up here")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Self.logger.debug("viewDidAppear()")
        
        let visibleDateRange = getVisibleItemData()
        
        if visibleDateRange.toDate == nil || visibleDateRange.name == nil {
            viewModel.fetch()
        } else {
            viewModel.syncFavs()
        }
    }
    
    override func refresh() {
        viewModel.fetch()
    }
    
    override func loadMore() {
        viewModel.loadMore()
    }
    
    override func setTitle() {
        
        setTitle("")
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }
        
        let metadata = viewModel.getItemAtIndexPath(indexPath)
        guard metadata != nil else { return }

        setTitle(StoreUtility.getFormattedDate(metadata!.date as Date))
    }
    
    public func clear() {
        setTitle("")
        viewModel.resetDataSource()
    }
    
    private func openViewer(indexPath: IndexPath) {
        
        let metadata = viewModel.getItemAtIndexPath(indexPath)
        
        guard metadata != nil && (metadata!.classFile == NKCommon.TypeClassFile.image.rawValue
                || metadata!.classFile == NKCommon.TypeClassFile.audio.rawValue
                || metadata!.classFile == NKCommon.TypeClassFile.video.rawValue) else { return }
        
        let metadatas = viewModel.getItems()
        coordinator.showViewerPager(currentIndex: indexPath.item, metadatas: metadatas)
    }
    
    private func bulkEdit() async {
        let indexPaths = collectionView.indexPathsForSelectedItems
        
        Self.logger.debug("bulkEdit() - indexPaths: \(indexPaths ?? [])")
        
        guard indexPaths != nil else { return }
        
        await viewModel.bulkEdit(indexPaths: indexPaths!)
    }
    
    private func reloadSection() {
        viewModel.reload()
    }
    
    private func getVisibleItemData() -> (toDate: Date?, name: String?) {
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        let first = visibleIndexes?.first

        if first == nil {
            Self.logger.debug("getVisibleItemData() - no visible items")
        } else {

            let firstMetadata = viewModel.getItemAtIndexPath(first!)

            if firstMetadata == nil {
                Self.logger.debug("getVisibleItemData() - missing metadata")
            } else {
                Self.logger.debug("getVisibleItemData() - \(firstMetadata!.date) \(firstMetadata!.fileNameView)")
                return (firstMetadata!.date as Date, firstMetadata!.fileNameView)
            }
        }
        
        return (nil, nil)
    }
}

extension FavoritesController: FavoritesDelegate {
    
    func bulkEditFinished() {
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            self.isEditing = false
            self.collectionView.allowsMultipleSelection = false
        
            self.setTitle()
            
            if self.collectionView.numberOfItems(inSection: 0) == 0 {
                self.collectionView.isHidden = true
                self.emptyView.isHidden = false
            }
        }
    }
    
    func fetching() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.startAnimating()
        }
    }
    
    func fetchResultReceived(resultItemCount: Int?) {
        DispatchQueue.main.async { [weak self] in
            if resultItemCount == nil {
                self?.coordinator.showLoadfailedError()
            }
        }
    }
    
    func dataSourceUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.displayResults()
        }
    }
    
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if self.isEditing {
                cell.selectMode(true)
                if self.collectionView.indexPathsForSelectedItems?.firstIndex(of: indexPath) != nil {
                    cell.selected(true)
                } else {
                    cell.selected(false)
                }
            } else {
                cell.selectMode(false)
            }
        }
    }
}

extension FavoritesController: MediaViewController {
    
    func zoomInGrid() {
        zoomIn()
    }
    
    func zoomOutGrid() {
        let count = viewModel.currentItemCount()
        zoomOut(currentItemCount: count)
    }
    
    func titleTouched() {
        if viewModel.currentItemCount() > 0 {
            collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }
    
    func edit() {
        isEditing = true
        collectionView.allowsMultipleSelection = true
        reloadSection()
    }
    
    func endEdit() {
        Task { [weak self] in
            await self?.bulkEdit()
        }
    }
    
    func cancel() {

        collectionView.indexPathsForSelectedItems?.forEach { collectionView.deselectItem(at: $0, animated: false) }

        isEditing = false
        collectionView.allowsMultipleSelection = false
        reloadSection()
    }
}

extension FavoritesController : CollectionLayoutDelegate {
    
    func collectionView(_ collectionView: UICollectionView, sizeOfPhotoAtIndexPath indexPath: IndexPath) -> CGSize {

        let metadata = viewModel.getItemAtIndexPath(indexPath)
        
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

extension FavoritesController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        Self.logger.debug("collectionView.willDisplay() - indexPath: \(indexPath)")
        viewModel.loadPreview(indexPath: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Self.logger.debug("collectionView.didSelectItemAt() - indexPath: \(indexPath)")
        if isEditing {
            if let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell {
                cell.selected(true)
            }
        } else {
            openViewer(indexPath: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        Self.logger.debug("collectionView.didDeselectItemAt() - indexPath: \(indexPath)")
        if isEditing {
            if let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell {
                cell.selected(false)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        
        guard let indexPath = indexPaths.first, let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell else { return nil }
        guard let image = cell.imageView.image else { return nil }
        guard let metadata = viewModel.getItemAtIndexPath(indexPath) else { return nil }
        
        let imageSize = image.size
        let width = self.view.bounds.width
        let height = imageSize.height * (width / imageSize.width)
        
        return .init(identifier: indexPath as NSCopying) {
            let previewController = self.coordinator.getPreviewController(metadata: metadata, image: image)
            previewController.preferredContentSize = CGSize(width: width, height: height)
            return previewController
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        openViewer(indexPath: indexPath)
    }
}
