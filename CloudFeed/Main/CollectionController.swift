//
//  CollectionController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/17/23.
//

import NextcloudKit
import os.log
import UIKit

class CollectionController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadMoreIndicator: UIActivityIndicatorView!
    @IBOutlet weak var emptyView: EmptyView!
    @IBOutlet weak var collectionViewTopConstraint: NSLayoutConstraint!
    
    private var refreshControl = UIRefreshControl()
    private var titleView: TitleView?
    private var layout: CollectionLayout?
    
    private let scrollThreshold = -80.0
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.isNavigationBarHidden = true
    }
    
    func setTitle() {}
    func loadMore() {}
    func refresh() {}
    
    func registerCell(_ cellIdentifier: String) {
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: cellIdentifier)
    }
    
    func setTitle(_ title: String) {
        titleView?.title.text = title
    }
    
    func showMenu() {
        titleView?.showMenu()
    }
    
    func hideMenu() {
        titleView?.hideMenu()
    }
    
    func isRefreshing() -> Bool {
        return refreshControl.isRefreshing
    }
    
    func isLoadingMore() -> Bool {
        return loadMoreIndicator.isAnimating
    }
    
    func startActivityIndicator() {
        activityIndicator.startAnimating()
    }
    
    func stopActivityIndicator() {
        activityIndicator.stopAnimating()
    }
    
    func initConstraints() {

        titleView?.translatesAutoresizingMaskIntoConstraints = false
        titleView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        titleView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        titleView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            titleView?.heightAnchor.constraint(equalToConstant: 70).isActive = true
            collectionViewTopConstraint?.constant = 70
        } else {
            titleView?.heightAnchor.constraint(equalToConstant: 50).isActive = true
            collectionViewTopConstraint?.constant = 50
        }
    }
    
    func zoomIn() {
        
        guard layout != nil else { return }
        let columns = self.layout?.numberOfColumns ?? 0
        
        if columns - 1 > 0 {
            self.layout?.numberOfColumns -= 1
        }
        
        UIView.animate(withDuration: 0.0, animations: {
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    func zoomOut(currentItemCount: Int) {
        
        guard layout != nil else { return }
        
        guard self.layout!.numberOfColumns + 1 <= currentItemCount else { return }
        
        if self.layout!.numberOfColumns + 1 < 5 {
            self.layout!.numberOfColumns += 1
        }
        
        UIView.animate(withDuration: 0.0, animations: {
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    func initCollectionView(delegate: CollectionLayoutDelegate) {
        
        layout = CollectionLayout()
        layout?.delegate = delegate
        layout?.numberOfColumns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
        
        collectionView.collectionViewLayout = layout!
        
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    func initTitleView(mediaView: MediaViewController, allowEdit: Bool) {
        
        titleView = Bundle.main.loadNibNamed("TitleView", owner: self, options: nil)?.first as? TitleView
        self.view.addSubview(titleView!)
        
        titleView?.mediaView = mediaView
        titleView?.initMenu(allowEdit: allowEdit)
    }
    
    func initEmptyView(imageSystemName: String, title: String, description: String) {
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 48)
        let image = UIImage(systemName: imageSystemName, withConfiguration: configuration)
        
        emptyView.display(image: image, title: title, description: description)
    }
    
    func displayResults() {
        
        let displayCount = collectionView.numberOfItems(inSection: 0)
        
        activityIndicator.stopAnimating()
        loadMoreIndicator.stopAnimating()
        refreshControl.endRefreshing()
        
        if displayCount == 0 {
            collectionView.isHidden = true
            emptyView.isHidden = false
            hideMenu()
            setTitle("")
        } else {
            collectionView.isHidden = false
            emptyView.isHidden = true
            showMenu()
            setTitle()
        }
    }
    
    func scrollToTop() {
        
        guard collectionView != nil else { return }
        
        if collectionView.numberOfItems(inSection: 0) > 0 {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
        }
    }
    
    @objc private func refresh(_ sender: Any) {
        refresh()
    }
}

extension CollectionController : UIScrollViewDelegate {
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        setTitle()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        setTitle()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {

        guard isEditing == false else { return }
        
        if scrollView.contentOffset.y <= scrollThreshold {
            //refresh()
        } else {
            let currentOffset = scrollView.contentOffset.y
            let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height
            let difference = maximumOffset - currentOffset
            
            if difference <= scrollThreshold {
                loadMoreIndicator.startAnimating()
                loadMore()
            }
        }
    }
}