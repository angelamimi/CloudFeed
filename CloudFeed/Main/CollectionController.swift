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
    func refresh()
    func enteringForeground()
    func columnCountChanged(columnCount: Int)
    func scrollSpeedChanged(scrolling: Bool)
    func sizeAtIndexPath(indexPath: IndexPath) -> CGSize
}

class CollectionController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyView: EmptyView!

    private var refreshControl = UIRefreshControl()

    var filterFromDate: Date?
    var filterToDate: Date?
    var filterType: Global.FilterType = .all

    var tableMode: Bool = true
    var compactMode: Bool = true

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

        tabBarController?.tabBar.isHidden = false

        navigationController?.isNavigationBarHidden = false
        navigationController?.navigationBar.prefersLargeTitles = true

        if collectionView?.backgroundColor == .black {
            UIView.animate { [weak self] in
                self?.collectionView?.backgroundColor = .systemBackground
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
    func setMetadataVisibility(_ visible: Bool) {}
    func showInfo() {}
    func switchToGrid() {}
    func switchToSocial() {}
    @objc func handleTableLongPress(sender: UITapGestureRecognizer) {}
    @objc func menuTapped() {}

    func registerCollectionCell(_ cellIdentifier: String) {
        let nib = UINib(nibName: "CollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: cellIdentifier)
    }

    func registerTableCell() {
        let nib = UINib(nibName: "TableCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "TableCell")
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
        if tableMode {
            return tableView.refreshControl?.isRefreshing == true
        } else {
            return collectionView.refreshControl?.isRefreshing == true
        }
    }

    func endRefreshing() {
        if tableMode {
            if tableView.refreshControl?.isRefreshing == true {
                tableView.refreshControl?.endRefreshing()
            }
        } else {
            if collectionView.refreshControl?.isRefreshing == true {
                collectionView.refreshControl?.endRefreshing()
            }
        }
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

        collectionView.refreshControl = UIRefreshControl()
        collectionView.refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        collectionView.isPrefetchingEnabled = false

        if #available(iOS 26, *) {
            collectionView.topEdgeEffect.style = .soft
        }
    }

    func initTableView() {

        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        let longPress = UILongPressGestureRecognizer()
        longPress.delaysTouchesBegan = true
        longPress.minimumPressDuration = 0.3
        longPress.addTarget(self, action: #selector(handleTableLongPress(sender:)))

        tableView.addGestureRecognizer(longPress)
    }

    func initTitle(allowEdit: Bool, allowSelect: Bool, layoutType: String) {

        navigationItem.title = ""

        let filterButtonImage: UIImage?

        if hasFilter() {
            filterButtonImage = UIImage(systemName: "calendar.badge.checkmark")?.applyingSymbolConfiguration(.init(paletteColors: [.systemGreen, .label]))
        } else {
            filterButtonImage = UIImage(systemName: "calendar")
        }

        let menu = initMenu(allowEdit: allowEdit, allowSelect: allowSelect, layoutType: layoutType, filterType: filterType)
        let menuButton = UIBarButtonItem(title: nil, image: UIImage(systemName: "ellipsis"), target: self, action: nil, menu: menu)
        let filterButton = UIBarButtonItem(title: nil, image: filterButtonImage, target: self, action: #selector(filter))

        menuButton.tintColor = .label
        filterButton.tintColor = .label

        navigationItem.leftBarButtonItems = []
        navigationItem.rightBarButtonItems = [menuButton, filterButton]

        if #unavailable(iOS 26) {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: Strings.BackAction, style: .plain, target: nil, action: nil)
        }
    }

    func showActivityIndicator() {

        var indicator: UIActivityIndicatorView?

        if navigationItem.rightBarButtonItems?.count == 2 {
            let activityIndicatorView = UIActivityIndicatorView(style: .medium)
            activityIndicatorView.hidesWhenStopped = true
            activityIndicatorView.startAnimating()

            let spinner = UIBarButtonItem(customView: activityIndicatorView)
            navigationItem.rightBarButtonItems?.append(spinner)
        }

        if navigationItem.rightBarButtonItems?.count == 3 {
            indicator = navigationItem.rightBarButtonItems?[2].customView as? UIActivityIndicatorView
        }

        indicator?.isHidden = false
        indicator?.startAnimating()
    }

    func hideActivityIndicator() {
        if navigationItem.rightBarButtonItems?.count == 3 {
            navigationItem.rightBarButtonItems?.removeLast()
        }
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

        let cancelButton = UIBarButtonItem(title: Strings.TitleCancel, image: nil, target: self, action: #selector(cancel))
        let actionButton = UIBarButtonItem(title: editTitle, image: nil, target: self, action: #selector(endEdit))

        navigationItem.rightBarButtonItems = []
        navigationItem.rightBarButtonItem = actionButton
        navigationItem.leftBarButtonItem = cancelButton

        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
    }

    func hasResults() -> Bool {

        if tableMode && tableView?.numberOfRows(inSection: 0) ?? 0 > 0 {
            return true
        } else if tableMode == false && collectionView?.numberOfItems(inSection: 0) ?? 0 > 0 {
            return true
        }

        return false
    }

    func displayResults(emptyViewTitle: String, emptyViewDescription: String) {

        let collectionCount = collectionView?.numberOfItems(inSection: 0) ?? 0
        let tableCount = tableView?.numberOfRows(inSection: 0) ?? 0

        if collectionCount == 0 && tableCount == 0 {

            if isEditing {
                //was in the middle of editing, but all favorites were removed outside of favorites screen. end edit mode
                isEditing = false
                collectionView?.allowsMultipleSelection = false
                resetEdit()
            }

            collectionView?.isHidden = true
            tableView?.isHidden = true

            emptyView.updateText(title: emptyViewTitle, description: emptyViewDescription)

            emptyView.show()
            setTitle("")

        } else {

            if tableMode {
                tableView?.isHidden = false
                collectionView?.isHidden = true
            } else {
                collectionView?.isHidden = false
                tableView?.isHidden = true
            }

            emptyView.hide()

            if !isEditing {
                delegate?.setTitle()
            }
        }
    }

    @objc private func refresh() {
        delegate?.refresh()
    }

    func scrollToTop(_ animated: Bool = true) {

        if tableMode == true && tableView != nil {
            if tableView.numberOfRows(inSection: 0) > 0 {
                delegate?.scrollSpeedChanged(scrolling: true)
                tableView.scrollToRow(at: IndexPath(item: 0, section: 0), at: .top, animated: animated)
                delegate?.scrollSpeedChanged(scrolling: false)
            }
        } else if tableMode == false && collectionView != nil {
            if collectionView.numberOfItems(inSection: 0) > 0 {
                delegate?.scrollSpeedChanged(scrolling: true)
                collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: animated)
                delegate?.scrollSpeedChanged(scrolling: false)
                delegate?.setTitle()
            }
        }
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

        var comps: DateComponents?
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

    private func compactTable() {
        compactMode = true
        let menu = initMenu(allowEdit: false, allowSelect: false, layoutType: "", filterType: filterType)
        DispatchQueue.main.async { [weak self] in
            self?.navigationItem.rightBarButtonItems?[0].menu = menu
        }
        setMetadataVisibility(false)
    }

    private func expandTable() {
        compactMode = false
        let menu = initMenu(allowEdit: false, allowSelect: false, layoutType: "", filterType: filterType)
        DispatchQueue.main.async { [weak self] in
            self?.navigationItem.rightBarButtonItems?[0].menu = menu
        }
        setMetadataVisibility(true)
    }

    private func initMenu(allowEdit: Bool, allowSelect: Bool, layoutType: String, filterType: Global.FilterType) -> UIMenu {

        var zoomMenu: UIMenu
        var collectionLayout: UIAction?

        if tableMode {

            let compact = UIAction(title: Strings.TitleSocialModeCompact, image: UIImage(systemName: "rectangle.arrowtriangle.2.inward")) { [weak self] _ in
                self?.compactTable()
            }

            let expand = UIAction(title: Strings.TitleSocialModeExpand, image: UIImage(systemName: "rectangle.arrowtriangle.2.outward")) { [weak self] _ in
                self?.expandTable()
            }

            let grid = UIAction(title: Strings.TitleGridMode, image: UIImage(systemName: "square.grid.3x3")) { [weak self] _ in
                self?.switchToGrid()
            }

            if compactMode {
                zoomMenu = UIMenu(title: "", options: .displayInline, children: [expand, grid])
            } else {
                zoomMenu = UIMenu(title: "", options: .displayInline, children: [compact, grid])
            }

        } else {

            let zoomIn = UIAction(title: Strings.TitleZoomIn, image: UIImage(systemName: "plus.magnifyingglass")) { [weak self] _ in
                self?.zoomInGrid()
            }

            let zoomOut = UIAction(title: Strings.TitleZoomOut, image: UIImage(systemName: "minus.magnifyingglass")) { [weak self] _ in
                self?.zoomOutGrid()
            }

            if allowEdit {
                zoomMenu = UIMenu(title: "", options: .displayInline, children: [zoomIn, zoomOut])
            } else {

                let social = UIAction(title: Strings.TitleSocialMode, image: UIImage(systemName: "rectangle")) { [weak self] _ in
                    self?.switchToSocial()
                }

                zoomMenu = UIMenu(title: "", options: .displayInline, children: [zoomIn, zoomOut, social])
            }
        }

        let filter = UIAction(title: Strings.TitleFilter, image: UIImage(systemName: "calendar")) { [weak self] _ in
            self?.filter()
        }

        if tableMode == false {

            if layoutType == Global.shared.layoutTypeSquare {
                collectionLayout = UIAction(title: Strings.TitleAspectRatioGrid, image: UIImage(systemName: "rectangle.grid.3x2")) { [weak self] _ in
                    self?.updateLayout(Global.shared.layoutTypeAspectRatio)
                }
            } else if layoutType == Global.shared.layoutTypeAspectRatio {
                collectionLayout = UIAction(title: Strings.TitleSquareGrid, image: UIImage(systemName: "square.grid.3x3")) { [weak self] _ in
                    self?.updateLayout(Global.shared.layoutTypeSquare)
                }
            }
        }

        let path = UIAction(title: Strings.TitleMediaFolder, image: UIImage(systemName: "folder.badge.gear")) { [weak self] _ in
            self?.setMediaDirectory()
        }

        let allType = UIAction(title: Strings.TitleAllItems, image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in
            self?.updateMediaType(.all)
        }

        let imageType = UIAction(title: Strings.TitleImagesOnly, image: UIImage(systemName: "photo")) { [weak self] _ in
            self?.updateMediaType(.image)
        }

        let videoType = UIAction(title: Strings.TitleVideosOnly, image: UIImage(systemName: "play.circle")) { [weak self] _ in
            self?.updateMediaType(.video)
        }

        switch filterType {
        case .all:
            allType.state = .on
        case .image:
            imageType.state = .on
        case .video:
            videoType.state = .on
        }

        let typeMenu = UIMenu(title: "", options: [.displayInline, .singleSelection], children: [allType, imageType, videoType])

        var editAction: UIAction?
        var selectAction: UIAction?

        if allowEdit {
            editAction = UIAction(title: Strings.TitleEdit, image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.edit()
            }
        }

        if allowSelect {
            selectAction = UIAction(title: Strings.ShareAction, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.select()
            }
        }

        if let layout = collectionLayout {
            if editAction == nil && selectAction != nil {
                return UIMenu(children: [zoomMenu, filter, layout, path, selectAction!, typeMenu])
            } else if editAction != nil && selectAction == nil {
                return UIMenu(children: [zoomMenu, filter, layout, path, editAction!, typeMenu])
            } else if editAction != nil && selectAction != nil {
                return UIMenu(children: [zoomMenu, filter, layout, path, editAction!, selectAction!, typeMenu])
            } else {
                return UIMenu(children: [zoomMenu, filter, layout, path, typeMenu])
            }
        } else {
            if editAction == nil && selectAction != nil {
                return UIMenu(children: [zoomMenu, filter, path, selectAction!, typeMenu])
            } else if editAction != nil && selectAction == nil {
                return UIMenu(children: [zoomMenu, filter, path, editAction!, typeMenu])
            } else if editAction != nil && selectAction != nil {
                return UIMenu(children: [zoomMenu, filter, path, editAction!, selectAction!, typeMenu])
            } else {
                return UIMenu(children: [zoomMenu, filter, path, typeMenu])
            }
        }
    }
}

extension CollectionController: UIScrollViewDelegate {

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

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        delegate?.setTitle()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {

        if !isEditing {
            delegate?.setTitle()
        }

        delegate?.scrollSpeedChanged(scrolling: false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {

        guard scrollView.isTracking || scrollView.isDragging else { return }

        let currentOffset = scrollView.contentOffset
        let currentTime = Date.timeIntervalSinceReferenceDate
        let diff = currentTime - lastOffsetTime

        if diff > 0.1 {

            let speedCheck = tableMode ? 5 : 1
            let distance = Float(currentOffset.y - lastOffset.y)
            let scrollSpeedNotAbs = Float((distance * 10.0) / 1000.0)
            let scrollSpeed = fabsf(scrollSpeedNotAbs)

            delegate?.scrollSpeedChanged(scrolling: scrollSpeed > Float(speedCheck))

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
