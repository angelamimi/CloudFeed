//
//  DownloadCoordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 1/19/26.
//  Copyright © 2026 Angela Jarosz. All rights reserved.
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
protocol DownloadCoordinatorDelegate: AnyObject {
    func downloadComplete()
}

@MainActor
final class DownloadCoordinator: NSObject {
    
    weak var navigationController: UINavigationController!
    weak var delegate: DownloadCoordinatorDelegate?
    
    private let metadata: Metadata
    private let dataService: DataService
    
    init(navigationController: UINavigationController, dataService: DataService, delegate: DownloadCoordinatorDelegate?, metadata: Metadata) {
        self.navigationController = navigationController
        self.dataService = dataService
        self.delegate = delegate
        self.metadata = metadata
    }
    
    func start() {
        let controller = UIStoryboard(name: "Download", bundle: nil).instantiateViewController(identifier: "DownloadController") as! DownloadController
        
        controller.viewModel = DownloadViewModel(dataService: dataService, delegate: controller, coordinator: self)
        controller.metadata = metadata
        
        controller.view.accessibilityViewIsModal = true
        controller.isModalInPresentation = true
        controller.modalPresentationStyle = .overFullScreen
        
        navigationController.present(controller, animated: true)
    }
}

extension DownloadCoordinator {
    
    func downloadComplete() {
        delegate?.downloadComplete()
    }
}
