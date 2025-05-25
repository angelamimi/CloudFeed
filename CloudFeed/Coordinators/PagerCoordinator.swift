//
//  PagerCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/5/23.
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

import UIKit

@MainActor
protocol PagerDelegate: AnyObject {
    func pagingEndedWith(metadata: Metadata)
}

@MainActor
final class PagerCoordinator {
    
    private let navigationController: UINavigationController
    private let dataService: DataService
    private let delegate: PagerDelegate
    
    init(navigationController: UINavigationController, dataService: DataService, delegate: PagerDelegate) {
        self.navigationController = navigationController
        self.dataService = dataService
        self.delegate = delegate
    }
    
    func start(currentIndex: Int, metadatas: [Metadata]) {
        
        let viewerCoordinator = ViewerCoordinator(dataService: dataService)
        weak var viewerPager: PagerController? = UIStoryboard(name: "Viewer", bundle: nil).instantiateInitialViewController() as? PagerController
        let viewModel = PagerViewModel(coordinator: viewerCoordinator, pagerCoordinator: self, dataService: dataService, delegate: viewerPager!, viewerDelegate: viewerPager!, currentIndex: currentIndex, metadatas: metadatas)
        
        viewerPager!.viewModel = viewModel
        viewerPager!.coordinator = self
        
        navigationController.pushViewController(viewerPager!, animated: true)
        
        if UIDevice.current.userInterfaceIdiom == .pad,
           #available(iOS 18.0, *),
           let tab = navigationController.parent as? UITabBarController {
            tab.setTabBarHidden(true, animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }
    
    func pagingEndedWith(metadata: Metadata) {
        delegate.pagingEndedWith(metadata: metadata)
        
        if UIDevice.current.userInterfaceIdiom == .pad,
           #available(iOS 18.0, *),
           let tab = navigationController.parent as? UITabBarController {
            tab.setTabBarHidden(false, animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }
    
    func share(_ urls: [URL]) {
        let activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow }),
               let view = window.rootViewController?.view,
               let popover = activity.popoverPresentationController {
                popover.permittedArrowDirections = []
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.frame.midX, y: view.frame.midY, width: 0, height: 0)
            }
        }
        navigationController.present(activity, animated: true)
    }
    
    func showFavoriteUpdateFailedError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.FavUpdateErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default))
        
        navigationController.present(alertController, animated: true)
    }
    
    func showVideoError() {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: Strings.MediaVideoErrorMessage, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default))
        
        navigationController.present(alertController, animated: true)
    }
}
