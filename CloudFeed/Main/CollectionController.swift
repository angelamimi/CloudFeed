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
    
    private var refreshControl = UIRefreshControl()
    
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
        
        navigationController?.navigationBar.preservesSuperviewLayoutMargins = true
        navigationController?.isNavigationBarHidden = false
        navigationItem.largeTitleDisplayMode = .automatic
        
        collectionView.contentInsetAdjustmentBehavior = .automatic
           
        if #unavailable(iOS 26) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
        }
        
        initObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.isNavigationBarHidden = false
        navigationController?.navigationBar.prefersLargeTitles = true
        
        if collectionView.backgroundColor == .black {
            UIView.animate { [weak self] in
                self?.collectionView.backgroundColor = .systemBackground
            }
        }
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
            delegate?.enteringForeground()
        }
    }
    
    func zoomInGrid() {}
    func zoomOutGrid() {}
    @objc func filter() {}
    func edit() {}
    func resetEdit() {}
    @objc func endEdit() {}
    func select() {}
    func updateLayout(_ layout: String) {}
    func updateMediaType(_ type: Global.FilterType) {}
    func setMediaDirectory() {}
    @objc func cancel() {}
    
    func showInfo() {}
    
    func registerCell(_ cellIdentifier: String) {
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: cellIdentifier)
    }
    
    func setTitle(_ title: String) {
        navigationItem.title = title
        navigationItem.largeTitleDisplayMode = title.isEmpty ? .automatic : .always
        navigationController?.navigationBar.prefersLargeTitles = title.isEmpty ? false : true
    }
    
    func resetFilter() {
        filterFromDate = nil
        filterToDate = nil
        filterType = .all
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
    
    func hasFilter() -> Bool {
        return filterFromDate != nil && filterToDate != nil
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
        
        if #available(iOS 26, *) {
            collectionView.topEdgeEffect.style = .soft
        }
    }
    
    func initTitle(allowEdit: Bool, allowSelect: Bool, layoutType: String) {

        let filterButtonImage: UIImage?
        
        if hasFilter() {
            filterButtonImage = UIImage(systemName: "calendar.badge.checkmark")?.applyingSymbolConfiguration(.init(paletteColors: [.systemGreen, .label]))
        } else {
            filterButtonImage = UIImage(systemName: "calendar")
        }
        
        let menu = initMenu(allowEdit: allowEdit, allowSelect: allowSelect, layoutType: layoutType, filterType: filterType)
        let menuButton = UIBarButtonItem.init(title: nil, image: UIImage(systemName: "ellipsis"), target: self, action: nil, menu: menu)
        let filterButton = UIBarButtonItem.init(title: nil, image: filterButtonImage, target: self, action: #selector(filter))
        
        menuButton.tintColor = .label
        filterButton.tintColor = .label
        
        navigationItem.leftBarButtonItems = []
        navigationItem.rightBarButtonItems = [menuButton, filterButton]
        
        if #unavailable(iOS 26) {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: Strings.BackAction, style: .plain, target: nil, action: nil)
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(scrollToTop))
        tap.numberOfTapsRequired = 1
        navigationController?.navigationBar.isUserInteractionEnabled = true
        navigationController?.navigationBar.addGestureRecognizer(tap)
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
    
    func titleBeginEdit() {
        titleBeginEditMode(editTitle: Strings.TitleApply)
    }
    
    func titleBeginSelect() {
        titleBeginEditMode(editTitle: Strings.ShareAction)
    }
    
    private func titleBeginEditMode(editTitle: String) {
        
        let cancelButton = UIBarButtonItem.init(title: Strings.TitleCancel, image: nil, target: self, action: #selector(cancel))
        let actionButton = UIBarButtonItem.init(title: editTitle, image: nil, target: self, action: #selector(endEdit))
        
        navigationItem.rightBarButtonItems = []
        navigationItem.rightBarButtonItem = actionButton
        navigationItem.leftBarButtonItem = cancelButton
        
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
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
                self.scrollToTop(true)
            }
        }
    }
    
    @objc
    func scrollToTop(_ animated: Bool = false) {

        guard collectionView != nil else { return }
        
        if collectionView.numberOfItems(inSection: 0) > 0 {
            delegate?.scrollSpeedChanged(scrolling: true)
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: animated)
            delegate?.scrollSpeedChanged(scrolling: false)
            delegate?.setTitle()
        }
    }
    
    @objc
    private func refresh(_ sender: Any) {
        delegate?.refresh()
    }
    
    func getFormattedDate(_ date: Date) -> String {
        
        var title: String = ""

        if date == datetimeWithOutTime(Date.distantPast) {
            title = ""
        } else {
            if let style = DateFormatter.Style(rawValue: 0) {
                title = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: style)
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
    
    func calculateItemSize(width: Double, height: Double) -> CGSize {
        
        guard height > 0 && width > 0 else { return CGSize.zero }
        
        let ratio = width / height
        
        //prevent items from being too tall
        if ratio < 0.25 {
            return CGSize(width: width, height: width * 3)
        }
        
        return CGSize(width: width, height: height)
    }
    
    private func initMenu(allowEdit: Bool, allowSelect: Bool, layoutType: String, filterType: Global.FilterType) -> UIMenu {
        
        let zoomIn = UIAction(title: Strings.TitleZoomIn, image: UIImage(systemName: "plus.magnifyingglass")) { [weak self] action in
            self?.zoomInGrid()
        }
        
        let zoomOut = UIAction(title: Strings.TitleZoomOut, image: UIImage(systemName: "minus.magnifyingglass")) { [weak self] action in
            self?.zoomOutGrid()
        }
        
        let zoomMenu = UIMenu(title: "", options: .displayInline, children: [zoomIn, zoomOut])
        
        
        let filter = UIAction(title: Strings.TitleFilter, image: UIImage(systemName: "calendar")) { [weak self] action in
            self?.filter()
        }
        
        let layout: UIAction
        
        if layoutType == Global.shared.layoutTypeSquare {
            layout = UIAction(title: Strings.TitleAspectRatioGrid, image: UIImage(systemName: "rectangle.grid.3x2")) { [weak self] action in
                self?.updateLayout(Global.shared.layoutTypeAspectRatio)
            }
        } else {
            layout = UIAction(title: Strings.TitleSquareGrid, image: UIImage(systemName: "square.grid.3x3")) { [weak self] action in
                self?.updateLayout(Global.shared.layoutTypeSquare)
            }
        }
        
        let path = UIAction(title: Strings.TitleMediaFolder, image: UIImage(systemName: "folder.badge.gear")) { [weak self] action in
            self?.setMediaDirectory()
        }
        
        let allType = UIAction(title: Strings.TitleAllItems, image: UIImage(systemName: "photo.on.rectangle")) { [weak self] action in
            self?.updateMediaType(.all)
        }
        
        let imageType = UIAction(title: Strings.TitleImagesOnly, image: UIImage(systemName: "photo")) { [weak self] action in
            self?.updateMediaType(.image)
        }
        
        let videoType = UIAction(title: Strings.TitleVideosOnly, image: UIImage(systemName: "play.circle")) { [weak self] action in
            self?.updateMediaType(.video)
        }
        
        switch filterType {
        case .all:
            allType.state = .on
            break
        case .image:
            imageType.state = .on
            break
        case .video:
            videoType.state = .on
            break
        }
        
        let typeMenu = UIMenu(title: "", options: [.displayInline, .singleSelection], children: [allType, imageType, videoType])
        
        var editAction: UIAction?
        var selectAction: UIAction?
        
        if allowEdit {
            editAction = UIAction(title: Strings.TitleEdit, image: UIImage(systemName: "pencil")) { [weak self] action in
                self?.edit()
            }
        }
        
        if allowSelect {
            selectAction = UIAction(title: Strings.ShareAction, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] action in
                self?.select()
            }
        }

        if editAction == nil && selectAction != nil {
            return UIMenu(children: [zoomMenu, filter, layout, path, selectAction!, typeMenu])
        } else if editAction != nil && selectAction == nil {
            return UIMenu(children: [zoomMenu, filter, layout, path, editAction!, typeMenu])
        } else if editAction != nil && selectAction != nil {
            return UIMenu(children: [zoomMenu, filter, layout, path, editAction!, selectAction!, typeMenu])
        } else {
            return UIMenu(children: [zoomMenu, filter, layout, path, typeMenu])
        }
    }
}

extension CollectionController : UIScrollViewDelegate {
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if !isEditing {
                delegate?.setTitle()
            }
            delegate?.scrollSpeedChanged(scrolling: false)
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if !isEditing {
            delegate?.setTitle()
        }
        
        delegate?.scrollSpeedChanged(scrolling: false)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        if !isEditing {
            delegate?.setTitle()
        }
        
        delegate?.scrollSpeedChanged(scrolling: false)
        
        guard isEditing == false else { return }
        guard !isLoadingMore() && !isRefreshing() else { return }

        let count = collectionView.numberOfItems(inSection: 0)
        let containsLast = collectionView.indexPathsForVisibleItems.contains(IndexPath(item: count - 1, section: 0))
        
        if containsLast {
            activityIndicator.stopAnimating()
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
