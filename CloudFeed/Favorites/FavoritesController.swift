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
    var viewModel: FavoritesViewModel!

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var emptyView: EmptyView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var titleView: TitleView?
    private var layout: CollectionLayout?
    
    private var isEditMode = false
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesController.self)
    )
    
    override func viewDidLoad() {
        
        collectionView.isHidden = true
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = false
        
        viewModel.initDataSource(collectionView: collectionView)
        
        navigationController?.isNavigationBarHidden = true
        
        initEmptyView()
        initCollectionViewLayout()
        initCollectionViewCell()
        initTitleView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Self.logger.debug("viewDidAppear()")
        
        if collectionView.numberOfSections == 0 || collectionView.numberOfItems(inSection: 0) == 0 {
            viewModel.fetch()
        } else {
            viewModel.metadataFetch()
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
        titleView?.title.text = ""
        viewModel.resetDataSource()
    }
    
    private func initCollectionViewCell() {
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "CollectionViewCell")
    }
    
    private func initEmptyView() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 48)
        let image = UIImage(systemName: "star.fill", withConfiguration: configuration)
        
        emptyView.display(image: image, title: "No favorites yet", description: "Files you mark as favorite will show up here")
        emptyView.isHidden = true
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

        let metadata = viewModel.getItemAtIndexPath(indexPath)
        guard metadata != nil else { return }
        titleView?.title.text = StoreUtility.getFormattedDate(metadata!.date as Date)
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
}

extension FavoritesController: FavoritesDelegate {
    
    func bulkEditFinished() {
        
        DispatchQueue.main.async {
            
            self.isEditMode = false
            self.collectionView.allowsMultipleSelection = false
        
            self.setTitle()
            
            if self.collectionView.numberOfItems(inSection: 0) == 0 {
                self.collectionView.isHidden = true
                self.emptyView.isHidden = false
            }
        }
    }
    
    func fetchResultReceived(resultItemCount: Int?) {
        
        DispatchQueue.main.async {
            
            if resultItemCount == nil {
                self.coordinator.showLoadfailedError()
                self.titleView?.hideMenu()
                return
            }
            
            if resultItemCount == 0 {
                self.collectionView.isHidden = true
                self.emptyView.isHidden = false
                self.setTitle()
                self.titleView?.hideMenu()
                return
                
                //TODO: Clear the collectionview?
            } else {
                self.collectionView.isHidden = false
                self.emptyView.isHidden = true
                self.titleView?.showMenu()
            }
        }
    }
    
    func dataSourceUpdated() {
        DispatchQueue.main.async {
            self.setTitle()
        }
    }
    
    func editCellUpdated(cell: CollectionViewCell, indexPath: IndexPath) {
        
        DispatchQueue.main.async {
            
            if self.isEditMode {
                
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
        if viewModel.currentItemCount() > 0 {
            collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
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
