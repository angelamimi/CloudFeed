//
//  MediaController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import NextcloudKit
import os.log
import UIKit

class MediaController: UIViewController {
    
    var coordinator: MediaCoordinator!
    var viewModel: MediaViewModel!

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadMoreIndicator: UIActivityIndicatorView!
    @IBOutlet weak var emptyView: EmptyView!
    
    private let loadMoreThreshold = -80.0
    private let groupSize = 2 //thumbnail fetches executed concurrently
    private var greaterDays = -30
    
    private var currentPageItemCount = 0
    private var currentMetadataCount = 0
    
    //private var dataSource: UICollectionViewDiffableDataSource<Int, tableMetadata>!
    //private var page: [tableMetadata] = []
    
    private var titleView: TitleView?
    private var layout: CollectionLayout?

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MediaController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "MainCollectionViewCell")
        collectionView.delegate = self
        
        viewModel.initDataSource(collectionView: collectionView)
        
        navigationController?.isNavigationBarHidden = true
        
        initCollectionViewLayout()
        initTitleView()
        initEmptyView()
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshDatasource), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        loadMoreIndicator.stopAnimating()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Self.logger.debug("viewDidAppear()")
        
        let visibleDateRange = getVisibleDateRange()
        
        if visibleDateRange.lessDate == nil || visibleDateRange.greaterDate == nil {
            viewModel.metadataSearch(offsetDate: Date())
        } else {
            guard let lessDate = Calendar.current.date(byAdding: .second, value: 1, to: visibleDateRange.lessDate!) else { return }
            guard let greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: visibleDateRange.greaterDate!) else { return }
            viewModel.sync(lessDate: lessDate, greaterDate: greaterDate)
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
        viewModel.resetDataSource()
        
        greaterDays = -30
        currentPageItemCount = 0
    }
    
    @objc func refreshDatasource(refreshControl: UIRefreshControl) {
        Self.logger.debug("refreshDatasource()")
        
        refreshControl.endRefreshing()
        
        clear()
        viewModel.metadataSearch(offsetDate: Date())
    }
    
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
    
    private func initEmptyView() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 48)
        let image = UIImage(systemName: "photo", withConfiguration: configuration)
        
        emptyView.display(image: image, title: "No media yet", description: "Your photos and videos will show up here")
    }
    
    private func loadMore() {
        viewModel.loadMore()
    }
    
    private func openViewer(indexPath: IndexPath) {
        
        let metadata = viewModel.getItemAtIndexPath(indexPath)
        
        guard metadata != nil && (metadata!.classFile == NKCommon.typeClassFile.image.rawValue
                || metadata!.classFile == NKCommon.typeClassFile.audio.rawValue
                || metadata!.classFile == NKCommon.typeClassFile.video.rawValue) else { return }
        
        let metadatas = viewModel.getItems()
        coordinator.showViewerPager(currentIndex: indexPath.item, metadatas: metadatas)
    }
    
    private func setTitle() {

        titleView?.title.text = ""
        
        let visibleIndexes = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        guard let indexPath = visibleIndexes?.first else { return }

        let metadata = viewModel.getItemAtIndexPath(indexPath)
        guard metadata != nil else { return }
        titleView?.title.text = StoreUtility.getFormattedDate(metadata!.date as Date)
    }
    
    private func getVisibleDateRange() -> (lessDate: Date?, greaterDate: Date?) {
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
    
    private func startActivityIndicator() {
        activityIndicator.startAnimating()
    }
    
    private func stopActivityIndicator() {
        activityIndicator.stopAnimating()
    }
}

extension MediaController: MediaDelegate {
    
    func dataSourceUpdated() {
        self.setTitle()
    }
    
    func searchResultReceived(resultItemCount: Int?) {
        DispatchQueue.main.async {
            self.processMetadataSearchResult(resultItemCount: resultItemCount)
        }
    }
    
    private func processMetadataSearchResult(resultItemCount: Int?) {
        
        let displayCount = collectionView.numberOfItems(inSection: 0)
        
        guard resultItemCount != nil else {
            
            //TODO: May need to display error even if have currently displayed items. On user reload?
            if displayCount == 0 {
                collectionView.isHidden = true
                emptyView.isHidden = false
                titleView?.hideMenu()
                setTitle()
            }
            
            coordinator.showLoadfailedError()
            return
        }
        
        titleView?.showMenu()
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

extension MediaController : UIScrollViewDelegate {
    
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

extension MediaController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Self.logger.debug("collectionView.didSelectItemAt() - indexPath: \(indexPath)")
        openViewer(indexPath: indexPath)
    }
}

extension MediaController: MediaViewController {
    
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
        
        let count = viewModel.currentItemCount()
        
        guard self.layout!.numberOfColumns + 1 <= count else { return }

        if self.layout!.numberOfColumns + 1 < 6 {
            self.layout!.numberOfColumns += 1
        }
        
        UIView.animate(withDuration: 0.0, animations: {
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    func titleTouched() {
        clear()
        viewModel.metadataSearch(offsetDate: Date())
    }
    
    func edit() {}
    func endEdit() {}
    func cancel() {}
}
