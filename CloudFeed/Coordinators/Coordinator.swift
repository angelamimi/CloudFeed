//
//  Coordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/29/23.
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
protocol Coordinator: NSObject {
    
    func start()
    func navigate(to coordinator: Coordinator)
}

extension Coordinator {
    
    func navigate(to coordinator: Coordinator) {
        coordinator.start()
    }
    
    func showErrorPrompt(message: String, navigationController: UINavigationController) {
        
        let alertController = UIAlertController(title: Strings.ErrorTitle, message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Strings.OkAction, style: .default, handler: { _ in
            navigationController.popViewController(animated: true)
        }))
        
        navigationController.present(alertController, animated: true)
    }
}
