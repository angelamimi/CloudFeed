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

class PagerController: UIViewController, MediaController {
    
    var currentIndex = 0
    var nextIndex: Int?
    var metadatas: [tableMetadata] = []
    
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
        
        Self.logger.log("viewDidLoad() - currentIndex: \(self.currentIndex) metadata count: \(self.metadatas.count)")
        
        pageViewController?.delegate = self
        pageViewController?.dataSource = self
        
        let longtapGestureRecognizer = UILongPressGestureRecognizer()
        longtapGestureRecognizer.delaysTouchesBegan = true
        longtapGestureRecognizer.minimumPressDuration = 0.3
        longtapGestureRecognizer.delegate = self
        longtapGestureRecognizer.addTarget(self, action: #selector(didLongpressGestureEvent(gestureRecognizer:)))
        
        pageViewController?.view.addGestureRecognizer(longtapGestureRecognizer)
        
        let metadata = metadatas[currentIndex]
        let viewerMedia = initViewer(index: currentIndex, metadata: metadata)
        
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
        //metadatas.removeAll()
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
        self.titleView?.menuButton.menu = menu
    }
    
    private func toggleFavoriteNetwork(isFavorite: Bool) {
        
        let metadata = metadatas[currentIndex]
        
        Task {
            let error = await Environment.current.dataService.favoriteMetadata(metadata)
            if error == .success {
                Self.logger.error("toggleFavoriteNetwork() - isFavorite: \(isFavorite)")
                metadatas[currentIndex].favorite = isFavorite
                self.setFavoriteMenu(isFavorite: isFavorite)
            } else {
                //TODO: Show the user an error
                Self.logger.error("toggleFavoriteNetwork() - ERROR: \(error.errorDescription)")
            }
        }
    }
    
    private func initViewer(index: Int, metadata: tableMetadata) -> ViewerController {
        
        let viewerMedia = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(identifier: "ViewerController") as! ViewerController
        viewerMedia.index = index
        viewerMedia.metadata = metadata
        viewerMedia.pager = self

        return viewerMedia
    }
    
    private func getVideoURL(metadata: tableMetadata) -> URL? {
        if StoreUtility.fileProviderStorageExists(metadata) {
            return URL(fileURLWithPath: StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        }
        return nil
    }
}

extension PagerController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if currentIndex == 0 { return nil }
        let viewerMedia = initViewer(index: currentIndex - 1, metadata: metadatas[currentIndex - 1])
        return viewerMedia
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard currentIndex < metadatas.count - 1 else { return nil }
        let viewerMedia = initViewer(index: currentIndex + 1, metadata: metadatas[currentIndex + 1])
        return viewerMedia
    }

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let nextViewController = pendingViewControllers.first as? ViewerController else { return }
        nextIndex = nextViewController.index
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed && nextIndex != nil {
            currentIndex = nextIndex!
            
            if currentIndex > 0 && currentIndex < metadatas.count {
                let metadata = metadatas[currentIndex]
                
                self.titleView?.title.text = metadata.fileNameView
            
                Self.logger.debug("prepViewer() - favorite: \(metadata.favorite)")
                setFavoriteMenu(isFavorite: metadata.favorite)
            }
        }
        self.nextIndex = nil
    }
}

extension PagerController: UIGestureRecognizerDelegate {

    @objc func didLongpressGestureEvent(gestureRecognizer: UITapGestureRecognizer) {
        
        guard let currentViewController = currentViewController else { return }
        
        if !currentViewController.metadata.livePhoto { return }
        
        if gestureRecognizer.state == .began {
            
            currentViewController.updateViewConstraints()
            
            let fileName = (currentViewController.metadata.fileNameView as NSString).deletingPathExtension + ".mov"
            if let metadata = Environment.current.dataService.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", currentViewController.metadata.account, currentViewController.metadata.serverUrl, fileName)), StoreUtility.fileProviderStorageExists(metadata) {
                
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

