//
//  CollectionController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/17/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import NextcloudKit
import os.log
import UIKit

@MainActor
protocol CollectionDelegate: AnyObject {
    func setTitle()
    func loadMore()
    func refresh()
    func enteringForeground()
    func columnCountChanged(columnCount: Int)
    func scrollSpeedChanged(scrolling: Bool)
    func sizeAtIndexPath(indexPath: IndexPath) -> CGSize
}

class CollectionController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadMoreIndicator: UIActivityIndicatorView!
    @IBOutlet weak var emptyView: EmptyView!
    @IBOutlet weak var collectionViewTopConstraint: NSLayoutConstraint!
    
    private var refreshControl = UIRefreshControl()
    private var titleView: TitleView?
    private var titleViewHeightAnchor: NSLayoutConstraint?
    
    var filterFromDate: Date?
    var filterToDate: Date?
    var filterType: Global.FilterType = .all

    var lastOffsetTime: TimeInterval = 0
    var lastOffset = CGPoint.zero
    
    weak var delegate: CollectionDelegate?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CollectionController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.isNavigationBarHidden = true
        
        initObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateTitleConstraints()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func initObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.willEnterForegroundNotification()
            }
        }
    }
    
    private func willEnterForegroundNotification() {
        if isViewLoaded && view.window != nil {
            updateTitleConstraints()
            delegate?.enteringForeground()
        }
    }
    
    func registerCell(_ cellIdentifier: String) {
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: cellIdentifier)
    }
    
    func setTitle(_ title: String) {
        titleView?.title.text = title
    }
    
    func showEditFilter() {
        titleView?.showFilterButton()
    }
    
    func hideEditFilter() {
        titleView?.hideFilterButton()
    }
    
    func hideEmptyView() {
        emptyView.hide()
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
    
    func resetEdit() {
        titleView?.resetEdit()
    }
    
    func hasFilter() -> Bool {
        return filterFromDate != nil && filterToDate != nil
    }
    
    func initConstraints() {

        titleView?.translatesAutoresizingMaskIntoConstraints = false
        
        titleView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        titleView?.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        titleView?.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            titleViewHeightAnchor = titleView?.heightAnchor.constraint(equalToConstant: Global.shared.titleSizeLarge)
            collectionViewTopConstraint?.constant = Global.shared.titleSizeLarge
        } else {
            titleViewHeightAnchor = titleView?.heightAnchor.constraint(equalToConstant: Global.shared.titleSize)
            collectionViewTopConstraint?.constant = Global.shared.titleSize
        }
        
        titleViewHeightAnchor?.isActive = true
    }
    
    func zoomIn() {
        
        guard let layout = collectionView.collectionViewLayout as? CollectionLayout else { return }
        
        let columns = layout.numberOfColumns
        
        if columns - 1 > 0 {
            layout.numberOfColumns -= 1
            delegate?.columnCountChanged(columnCount: layout.numberOfColumns)
        }
    }
    
    func zoomOut() {

        guard let layout = collectionView.collectionViewLayout as? CollectionLayout else { return }
        
        if layout.numberOfColumns < 5 {
            layout.numberOfColumns += 1
            delegate?.columnCountChanged(columnCount: layout.numberOfColumns)
        }
    }
    
    func initCollectionView(layoutType: String, columnCount: Int) {
        
        let layout = CollectionLayout()
        layout.delegate = self
        layout.numberOfColumns = columnCount
        layout.layoutType = layoutType
        collectionView.collectionViewLayout = layout
        
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        collectionView.isPrefetchingEnabled = false
    }
    
    func initTitleView(mediaView: MediaViewController, allowEdit: Bool, layoutType: String) {
        
        titleView = Bundle.main.loadNibNamed("TitleView", owner: self, options: nil)?.first as? TitleView
        self.view.addSubview(titleView!)
        
        titleView?.mediaView = mediaView
        titleView?.initMenu(allowEdit: allowEdit, layoutType: layoutType, filterType: filterType)
    }
    
    func initEmptyView(imageSystemName: String, title: String, description: String) {
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 48)
        let image = UIImage(systemName: imageSystemName, withConfiguration: configuration)
        
        emptyView.display(image: image, title: title, description: description)
    }
    
    func updateLayoutType(_ layoutType: String) {
        guard let layout = collectionView.collectionViewLayout as? CollectionLayout else { return }
        layout.layoutType = layoutType
    }
    
    func reloadMenu(allowEdit: Bool, layoutType: String) {
        titleView?.initMenu(allowEdit: allowEdit, layoutType: layoutType, filterType: filterType)
    }
    
    func titleBeginEdit() {
        titleView?.beginEdit()
    }
    
    func displayResults(refresh: Bool, emptyViewTitle: String, emptyViewDescription: String) {
        
        let collectionCount = collectionView.numberOfItems(inSection: 0)
        
        activityIndicator.stopAnimating()
        loadMoreIndicator.stopAnimating()
        refreshControl.endRefreshing()
        
        if collectionCount == 0 {
            
            if isEditing {
                //was in the middle of editing, but all favorites were removed outside of favorites screen. end edit mode
                isEditing = false
                collectionView.allowsMultipleSelection = false
                resetEdit()
            }
            
            collectionView.isHidden = true
            
            emptyView.updateText(title: emptyViewTitle, description: emptyViewDescription)
            
            emptyView.show()
            setTitle("")
            
        } else {
            
            collectionView.isHidden = false
            emptyView.hide()
            
            if !isEditing {
                delegate?.setTitle()
            }
            
            if refresh && (hasFilter() || (collectionCount > 0 && collectionView.indexPathsForVisibleItems.count == 0)) {
                //Self.logger.debug("displayResults() - visible items count: \(self.collectionView.indexPathsForVisibleItems.count)")

                //When scrolled far in a long list, then filtered, the user ends up at a scroll position that
                //doesn't display the newly filtered list. Screen appears blank. Enabling scroll to top may need
                //more conditions around it or will scroll to top when the user is interacting with the list.
                self.scrollToTop(animated: true)
            }
        }
    }
    
    func scrollToTop(animated: Bool = false) {

        guard collectionView != nil else { return }
        
        if collectionView.numberOfItems(inSection: 0) > 0 {
            delegate?.scrollSpeedChanged(scrolling: true)
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: animated)
            delegate?.scrollSpeedChanged(scrolling: false)
            delegate?.setTitle()
        }
    }
    
    @objc private func refresh(_ sender: Any) {
        delegate?.refresh()
    }
    
    private func updateTitleConstraints() {
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            titleViewHeightAnchor?.constant = Global.shared.titleSizeLarge
            collectionViewTopConstraint?.constant = Global.shared.titleSizeLarge
        } else {
            titleViewHeightAnchor?.constant = Global.shared.titleSize
            collectionViewTopConstraint?.constant = Global.shared.titleSize
        }

        titleView?.updateTitleSize()
    }
    
    func getFormattedDate(_ date: Date) -> String {
        
        var title: String = ""

        if date == datetimeWithOutTime(Date.distantPast) {
            title = ""
        } else {
            if let style = DateFormatter.Style(rawValue: 0) {
                title = DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: style)
            }
        }
        
        return title
    }
    
    func datetimeWithOutTime(_ date: Date?) -> Date? {
        
        var datDate = date
        if datDate == nil {
            return nil
        }

        var comps: DateComponents? = nil
        if let datDate {
            comps = Calendar.current.dateComponents([.year, .month, .day], from: datDate)
        }
        if let comps {
            datDate = Calendar.current.date(from: comps)
        }

        return datDate
    }
    
    func calculateItemSize(width: Int, height: Int) -> CGSize {
        
        guard height > 0 && width > 0 else { return CGSize.zero }
        
        let ratio = Double(width) / Double(height)
        
        //prevent items from being too tall
        if ratio < 0.25 {
            return CGSize(width: width, height: width * 3)
        }
        
        return CGSize(width: width, height: height)
    }
}

extension CollectionController : UIScrollViewDelegate {
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            delegate?.setTitle()
            delegate?.scrollSpeedChanged(scrolling: false)
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        delegate?.setTitle()
        delegate?.scrollSpeedChanged(scrolling: false)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        delegate?.setTitle()
        delegate?.scrollSpeedChanged(scrolling: false)
        
        guard isEditing == false else { return }
        
        let count = collectionView.numberOfItems(inSection: 0)
        let containsFirst = collectionView.indexPathsForVisibleItems.contains(IndexPath(item: 0, section: 0))
        let containsLast = collectionView.indexPathsForVisibleItems.contains(IndexPath(item: count - 1, section: 0))
        
        if !(containsFirst && containsLast) && (containsLast && !isLoadingMore() && !isRefreshing()) {
            loadMoreIndicator.startAnimating()
            delegate?.loadMore()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let currentOffset = scrollView.contentOffset
        let currentTime = Date.timeIntervalSinceReferenceDate
        let diff = currentTime - lastOffsetTime
        
        if diff > 0.1 {
            
            let distance = Float(currentOffset.y - lastOffset.y)
            let scrollSpeedNotAbs = Float((distance * 10.0) / 1000.0)
            let scrollSpeed = fabsf(scrollSpeedNotAbs)

            delegate?.scrollSpeedChanged(scrolling: scrollSpeed > 1)

            lastOffset = currentOffset
            lastOffsetTime = currentTime
        }
    }
}

extension CollectionController: CollectionLayoutDelegate {
    
    func collectionView(_ collectionView: UICollectionView, sizeAtIndexPath indexPath: IndexPath) -> CGSize {
        return delegate?.sizeAtIndexPath(indexPath: indexPath) ?? CGSize.zero
    }
}
