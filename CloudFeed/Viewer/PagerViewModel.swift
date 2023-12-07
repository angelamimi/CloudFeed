//
//  PagerViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/9/23.
//

import UIKit

protocol PagerViewModelDelegate: AnyObject {
    func finishedPaging(metadata: tableMetadata)
    func finishedUpdatingFavorite(isFavorite: Bool)
}

final class PagerViewModel: NSObject {

    private let coordinator: ViewerCoordinator
    private let dataService: DataService
    
    private var currentIndex: Int
    private var metadatas: [tableMetadata]
    
    internal var nextIndex: Int?
    weak var delegate: PagerViewModelDelegate?
    
    init(coordinator: ViewerCoordinator, dataService: DataService, currentIndex: Int = 0, metadatas: [tableMetadata]) {
        self.coordinator = coordinator
        self.dataService = dataService
        self.currentIndex = currentIndex
        self.metadatas = metadatas
    }
    
    func currentMetadata() -> tableMetadata {
        return metadatas[currentIndex]
    }
    
    func initViewer() -> ViewerController {
        let metadata = currentMetadata()
        let viewerMedia = initViewer(index: currentIndex, metadata: metadata)
        
        return viewerMedia
    }
    
    func toggleFavorite(isFavorite: Bool) {
        let metadata = metadatas[currentIndex]
        
        Task { [weak self] in
            guard let self else { return }
            
            let result = await dataService.toggleFavoriteMetadata(metadata)
            if result != nil {
                metadatas[currentIndex] = result!
                delegate?.finishedUpdatingFavorite(isFavorite: isFavorite)
            } else {
                //TODO: Show the user an error
            }
        }
    }
    
    func getMetadata(account: String, serverUrl: String, fileName: String) -> tableMetadata? {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", account, serverUrl, fileName)
        return dataService.getMetadata(predicate: predicate)
    }
}

extension PagerViewModel {
    
    private func initViewer(index: Int, metadata: tableMetadata) -> ViewerController {
        return coordinator.getViewerController(for: index, metadata: metadata)
    }
}

extension PagerViewModel: UIPageViewControllerDataSource {
    
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
}

extension PagerViewModel: UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let nextViewController = pendingViewControllers.first as? ViewerController else { return }
        nextIndex = nextViewController.index
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed && nextIndex != nil {
            currentIndex = nextIndex!
            
            if currentIndex >= 0 && currentIndex < metadatas.count {
                let metadata = metadatas[currentIndex]
                self.delegate?.finishedPaging(metadata: metadata)
            }
        }
        self.nextIndex = nil
    }
}

