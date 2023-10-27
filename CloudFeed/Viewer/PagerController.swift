//
//  PagerController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/2/23.
//

import UIKit
import NextcloudKit
import MediaPlayer
import os.log

class PagerController: UIViewController, MediaViewController {
    
    var viewModel: PagerViewModel!
    
    private weak var titleView: TitleView?
    
    weak var pageViewController: UIPageViewController? {
        return self.children[0] as? UIPageViewController
    }
    
    weak var currentViewController: ViewerController? {
        return self.pageViewController?.viewControllers![0] as? ViewerController
    }
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PagerController.self)
    )
    
    override func viewSafeAreaInsetsDidChange() {
        titleView?.translatesAutoresizingMaskIntoConstraints = false
        titleView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        titleView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        titleView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        titleView?.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageViewController?.delegate = viewModel
        pageViewController?.dataSource = viewModel
        
        let longtapGestureRecognizer = UILongPressGestureRecognizer()
        longtapGestureRecognizer.delaysTouchesBegan = true
        longtapGestureRecognizer.minimumPressDuration = 0.3
        longtapGestureRecognizer.delegate = self
        longtapGestureRecognizer.addTarget(self, action: #selector(didLongpressGestureEvent(gestureRecognizer:)))
        
        pageViewController?.view.addGestureRecognizer(longtapGestureRecognizer)
        
        let metadata = viewModel.currentMetadata()
        let viewerMedia = viewModel.initViewer()
        
        pageViewController?.setViewControllers([viewerMedia], direction: .forward, animated: true, completion: nil)
        
        titleView = Bundle.main.loadNibNamed("TitleView", owner: self, options: nil)?.first as? TitleView
        self.view.addSubview(titleView!)
        
        titleView?.mediaView = self
        titleView?.title.text = metadata.fileNameView
        titleView?.initNavigation()
        
        setFavoriteMenu(isFavorite: metadata.favorite)
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        Self.logger.debug("viewDidDisappear()")
        self.titleView?.menuButton.menu = nil
    }
    
    func zoomInGrid() {}
    func zoomOutGrid() {}
    func edit() {}
    func endEdit() {}
    func titleTouched() {}
    
    func cancel() {        
        navigationController?.popViewController(animated: true)
    }

    private func setFavoriteMenu(isFavorite: Bool) {

        var action: UIAction
        
        if (isFavorite) {
            action = UIAction(title: "Remove from Favorites", image: UIImage(systemName: "star.fill")) { action in
                self.toggleFavoriteNetwork(isFavorite: false)
            }
        } else {
            action = UIAction(title: "Add to Favorites", image: UIImage(systemName: "star")) { action in
                self.toggleFavoriteNetwork(isFavorite: true)
            }
        }
        
        let menu = UIMenu(children: [action])
        
        DispatchQueue.main.async { [weak self] in
            self?.titleView?.menuButton.menu = menu
        }
    }
    
    private func toggleFavoriteNetwork(isFavorite: Bool) {
        
        viewModel.toggleFavorite(isFavorite: isFavorite)
    }
    
    private func getVideoURL(metadata: tableMetadata) -> URL? {
        if StoreUtility.fileProviderStorageExists(metadata) {
            return URL(fileURLWithPath: StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        }
        return nil
    }
}

extension PagerController: PagerViewModelDelegate {
    
    func finishedPaging(metadata: tableMetadata) {
        titleView?.title.text = metadata.fileNameView
    
        Self.logger.debug("finishedPaging() - favorite: \(metadata.favorite)")
        setFavoriteMenu(isFavorite: metadata.favorite)
    }
    
    func finishedUpdatingFavorite(isFavorite: Bool) {
        setFavoriteMenu(isFavorite: isFavorite)
    }
}

extension PagerController: UIGestureRecognizerDelegate {

    @objc func didLongpressGestureEvent(gestureRecognizer: UITapGestureRecognizer) {
        
        guard let currentViewController = currentViewController else { return }
        
        if !currentViewController.metadata.livePhoto { return }
        
        if gestureRecognizer.state == .began {
            
            currentViewController.updateViewConstraints()
            
            let fileName = (currentViewController.metadata.fileNameView as NSString).deletingPathExtension + ".mov"
            if let metadata = viewModel.getMetadata(account: currentViewController.metadata.account,
                                                    serverUrl: currentViewController.metadata.serverUrl,
                                                    fileName: fileName),
                StoreUtility.fileProviderStorageExists(metadata) {
                
                AudioServicesPlaySystemSound(1519) // peek feedback
                let urlVideo = getVideoURL(metadata: metadata)
                
                Self.logger.debug("didLongpressGestureEvent() - \(urlVideo?.absoluteString ?? "BLERG")")
                if let url = urlVideo {
                    currentViewController.playLivePhoto(url)
                }
            }
            
        } else if gestureRecognizer.state == .ended {
            Self.logger.debug("didLongpressGestureEvent() - ended")
        }
    }
}

