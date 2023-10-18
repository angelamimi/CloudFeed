//
//  MediaController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import NextcloudKit
import os.log
import UIKit

class MediaController: CollectionController {
    
    var coordinator: MediaCoordinator!
    var viewModel: MediaViewModel!

    @IBOutlet weak var loadMoreIndicator: UIActivityIndicatorView!

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MediaController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerCell("MainCollectionViewCell")
        collectionView.delegate = self
        
        viewModel.initDataSource(collectionView: collectionView)
        
        initCollectionViewLayout(delegate: self)
        initTitleView(mediaView: self)
        initEmptyView(imageSystemName: "photo", title:"No media yet", description: "Your photos and videos will show up here")
        //initRefreshControl(action: #selector(refreshDatasource))
        
        loadMoreIndicator.stopAnimating()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Self.logger.debug("viewDidAppear()")
        
        let visibleDateRange = getVisibleDateRange()
        
        if visibleDateRange.toDate == nil || visibleDateRange.fromDate == nil {
            hideMenu()
            viewModel.metadataSearch(offsetDate: Date(), limit: Global.shared.metadataPageSize)
        } else {
            guard let toDate = Calendar.current.date(byAdding: .second, value: 1, to: visibleDateRange.toDate!) else { return }
            guard let fromDate = Calendar.current.date(byAdding: .second, value: -1, to: visibleDateRange.fromDate!) else { return }
            viewModel.sync(toDate: toDate, fromDate: fromDate)
        }
    }
    
    override func refresh() {
        clear()
        viewModel.metadataSearch(offsetDate: Date(), limit: Global.shared.metadataPageSize)
    }
    
    override func loadMore() {
        viewModel.loadMore()
    }
    
    public func clear() {
        setTitle("")
        hideMenu()
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
    
    override func setTitle() {

        setTitle("")
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }

        let metadata = viewModel.getItemAtIndexPath(indexPath)
        guard metadata != nil else { return }
        
        setTitle(StoreUtility.getFormattedDate(metadata!.date as Date))
    }
    
    private func getVisibleDateRange() -> (toDate: Date?, fromDate: Date?) {
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        let first = visibleIndexes?.first
        let last = visibleIndexes?.last
        
        if first == nil || last == nil {
            Self.logger.debug("getVisibleDateRange() - no visible items")
        } else {

            let firstMetadata = viewModel.getItemAtIndexPath(first!)
            let lastMetadata = viewModel.getItemAtIndexPath(last!)
            
            if firstMetadata == nil || lastMetadata == nil {
                Self.logger.debug("getVisibleDateRange() - missing metadata")
            } else {
                Self.logger.debug("getVisibleDateRange() - \(firstMetadata!.date) \(lastMetadata!.date)")
                return (firstMetadata!.date as Date, lastMetadata!.date as Date)
            }
        }
        
        return (nil, nil)
    }
}

extension MediaController: MediaDelegate {
    
    func dataSourceUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.setTitle()
            self?.activityIndicator.stopAnimating()
        }
    }
    
    func searching() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.startAnimating()
        }
    }
    
    func searchResultReceived(resultItemCount: Int?) {
        DispatchQueue.main.async { [weak self] in
            self?.processMetadataSearchResult(resultItemCount: resultItemCount)
            self?.activityIndicator.stopAnimating()
        }
    }
    
    private func processMetadataSearchResult(resultItemCount: Int?) {
        
        let displayCount = collectionView.numberOfItems(inSection: 0)
        
        guard resultItemCount != nil else {
            
            //TODO: May need to display error even if have currently displayed items. On user reload?
            if displayCount == 0 {
                collectionView.isHidden = true
                emptyView.isHidden = false
                hideMenu()
                setTitle()
            }
        
            coordinator.showLoadfailedError()
            return
        }
        showMenu()
    }
}

extension MediaController: CollectionLayoutDelegate {
    
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

extension MediaController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Self.logger.debug("collectionView.didSelectItemAt() - indexPath: \(indexPath)")
        openViewer(indexPath: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        Self.logger.debug("collectionView.willDisplay() - indexPath: \(indexPath)")
        viewModel.loadPreview(indexPath: indexPath)
    }
}

extension MediaController: MediaViewController {
    
    func zoomInGrid() {
        zoomIn()
    }
    
    func zoomOutGrid() {
        let count = viewModel.currentItemCount()
        zoomOut(currentItemCount: count)
    }
    
    func titleTouched() {
        if viewModel.currentItemCount() > 0 {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
        }
    }
    
    func edit() {}
    func endEdit() {}
    func cancel() {}
}
