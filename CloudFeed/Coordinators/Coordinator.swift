//
//  Coordinator.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 8/29/23.
//

import UIKit

protocol Coordinator: AnyObject {
    
    func start()
    func navigate(to coordinator: Coordinator)
}

extension Coordinator {
    
    func navigate(to coordinator: Coordinator) {
        coordinator.start()
    }
}
