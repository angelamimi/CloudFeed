//
//  PagerViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/9/23.
//

import UIKit

/*protocol PagerViewModelProtocol: AnyObject {
    var currentIndex: Int { get }
    var metadatas: [tableMetadata] { get }
    
    func currentMetadata() -> tableMetadata
    func toggleFavorite(isFavorite: Bool)
    func initViewer() -> ViewerController
}*/

protocol PagerViewModelDelegate: AnyObject {
    func finishedPaging(metadata: tableMetadata)
    func finishedUpdatingFavorite(isFavorite: Bool)
}

final class PagerViewModel: NSObject {

    var currentIndex: Int
    var metadatas: [tableMetadata]
    
    var coordinator: ViewerCoordinator!
    
    internal var nextIndex: Int?
    weak var delegate: PagerViewModelDelegate?
    
    init(currentIndex: Int = 0, metadatas: [tableMetadata]) {
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
        
        Task {
            let error = await Environment.current.dataService.favoriteMetadata(metadata)
            if error == .success {
                metadatas[currentIndex].favorite = isFavorite
                delegate?.finishedUpdatingFavorite(isFavorite: isFavorite)
                
            } else {
                //TODO: Show the user an error
            }
        }
    }
    
    func getMetadata(account: String, serverUrl: String, fileName: String) -> tableMetadata? {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", account, serverUrl, fileName)
        return Environment.current.dataService.getMetadata(predicate: predicate)
    }
}

extension PagerViewModel {
    
    private func initViewer(index: Int, metadata: tableMetadata) -> ViewerController {
        
        /*let viewerMedia = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(identifier: "ViewerController") as! ViewerController
        
        viewerMedia.index = index
        viewerMedia.metadata = metadata

        return viewerMedia*/
        
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

