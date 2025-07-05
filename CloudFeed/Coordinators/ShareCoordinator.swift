//
//  ShareCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 7/3/25.
//  Copyright © 2025 Angela Jarosz. All rights reserved.
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
protocol ShareDelegate: AnyObject {
    func shareComplete()
}

@MainActor
final class ShareCoordinator: NSObject {
    
    weak var navigationController: UINavigationController!
    weak var delegate: ShareDelegate?
    
    private let metadatas: [Metadata]
    private let dataService: DataService
    
    init(navigationController: UINavigationController, dataService: DataService, delegate: ShareDelegate?, metadatas: [Metadata]) {
        self.navigationController = navigationController
        self.dataService = dataService
        self.delegate = delegate
        self.metadatas = metadatas
    }
    
    func start() {
        let controller = UIStoryboard(name: "Share", bundle: nil).instantiateViewController(identifier: "ShareController") as! ShareController
        
        controller.viewModel = ShareViewModel(dataService: dataService, delegate: controller, coordinator: self)
        controller.metadatas = metadatas
        
        controller.isModalInPresentation = true
        controller.modalPresentationStyle = .overFullScreen
        
        navigationController.present(controller, animated: true)
    }
}

extension ShareCoordinator {
    
    func shareComplete() {
        delegate?.shareComplete()
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

        DispatchQueue.main.async{ [weak self] in
            self?.navigationController.dismiss(animated: false, completion: { [weak self] in
                self?.navigationController.present(activity, animated: true)
            })
        }
    }
}
