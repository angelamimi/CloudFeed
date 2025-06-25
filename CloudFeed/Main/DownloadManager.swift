//
//  DownloadManager.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 5/17/25.
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
import os.log

final class DownloadManager {
    
    private weak var dataService: DataService!
    private let queue: OperationQueue
        
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DownloadManager.self))
    
    init(dataService: DataService) {
        self.dataService = dataService
        
        queue = OperationQueue()
        queue.name = "downloadManagerQueue"
        queue.maxConcurrentOperationCount = 5
        queue.qualityOfService = .background
    }
    
    func cancelAll() {
        queue.cancelAllOperations()
    }
    
    func download(metadata: Metadata, delegate: DownloadOperationDelegate) {
        let operation = DownloadOperation(metadata, dataService: dataService, delegate: delegate)
        queue.addOperation(operation)
    }
}

