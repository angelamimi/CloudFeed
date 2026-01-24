//
//  DownloadViewModel.swift
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
protocol DownloadDelegate: AnyObject {
    func progressUpdated(_ progress: Double)
}

final class Download {
    var completed: Int64
    var total: Int64
    
    init(completed: Int64, total: Int64) {
        self.completed = completed
        self.total = total
    }
}

@MainActor
class DownloadViewModel: NSObject {
    
    private let dataService: DataService
    private let coordinator: DownloadCoordinator
    
    private let downloadManager: DownloadManager
    
    private var shares: [Metadata] = []
    private let queue = DispatchQueue(label: "downloadQueue")
    private var downloadCount: Int = 0
    private var downloads = [String: Download]()
    
    weak var delegate: DownloadDelegate?
    
    init(dataService: DataService, delegate: DownloadDelegate, coordinator: DownloadCoordinator) {
        self.dataService = dataService
        self.delegate = delegate
        self.coordinator = coordinator
        
        downloadManager = DownloadManager(dataService: dataService)
    }
    
    func download(_ metadata: Metadata) {
        if dataService.store.fileExists(metadata) {
            coordinator.downloadComplete()
        } else {
            downloadManager.download(metadata: metadata, delegate: self)
        }
    }
    
    func cancelDownloads() {
        downloadManager.cancelAll()
        coordinator.downloadComplete()
    }
}

extension DownloadViewModel: DownloadOperationDelegate {
    
    func progress(metadata: Metadata, progress: Progress) {
        delegate?.progressUpdated(progress.fractionCompleted)
    }

    func downloaded(metadata: Metadata) {
        dataService.savePreview(metadata: metadata)
        coordinator.downloadComplete()
    }
}
