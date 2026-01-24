//
//  ShareViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 5/24/25.
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
class ShareViewModel: NSObject {
    
    private let dataService: DataService
    private let coordinator: ShareCoordinator
    
    private let downloadManager: DownloadManager

    private var shares: [Metadata] = []
    private let queue = DispatchQueue(label: "shareDownloadQueue")
    private var downloadCount: Int = 0
    private var downloads = [String: Download]()
    
    weak var delegate: DownloadDelegate?
    
    init(dataService: DataService, delegate: DownloadDelegate, coordinator: ShareCoordinator) {
        self.dataService = dataService
        self.delegate = delegate
        self.coordinator = coordinator
        
        downloadManager = DownloadManager(dataService: dataService)
    }
    
    func cancelDownloads() {
        downloadManager.cancelAll()
        coordinator.shareComplete()
    }
    
    func share(_ metadatas: [Metadata]) {
        
        shares.removeAll()
        shares.append(contentsOf: metadatas)
        
        var toDownload: [Metadata] = []
        
        queue.sync {
            downloadCount = 0
        }
        
        for metadata in metadatas {
            if dataService.store.fileExists(metadata) {
                downloadComplete() //triggers update to progress view
            } else {
                toDownload.append(metadata)
                downloads[metadata.ocId] = Download(completed: 0, total: 0)
            }
        }
        
        if toDownload.count == 0 {
            downloadsComplete()
        } else {
            queue.sync {
                downloadCount = toDownload.count
            }

            for metadata in toDownload {
                downloadManager.download(metadata: metadata, delegate: self)
            }
        }
    }
    
    private func downloadComplete() {
        let progress = 1.0 / Double(shares.count)
        delegate?.progressUpdated(progress)
    }
    
    private func downloadsComplete() {

        var urls: [URL] = []
        
        for metadata in shares {
            if dataService.store.fileExists(metadata) {
                if let path = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView) {
                    let url = URL(fileURLWithPath: path)
                    urls.append(url)
                }
            }
        }
        
        shares.removeAll()

        coordinator.shareComplete()
        coordinator.share(urls)
    }
}

extension ShareViewModel: DownloadOperationDelegate {
    
    func progress(metadata: Metadata, progress: Progress) {

        if let download = downloads[metadata.ocId] {
            var progressToAdd: Double
            if download.total == 0 {
                download.completed = progress.completedUnitCount
                download.total = progress.totalUnitCount
                progressToAdd = Double(progress.fractionCompleted) / Double(shares.count)
            } else {
                let diff = Double(progress.completedUnitCount - download.completed) / Double(progress.totalUnitCount)
                progressToAdd = Double(diff) / Double(shares.count)
                download.completed = progress.completedUnitCount
            }
            
            delegate?.progressUpdated(progressToAdd)
        }
    }

    func downloaded(metadata: Metadata) {
        queue.sync {
            downloadCount -= 1
            if downloadCount == 0 {
                downloadsComplete()
            }
        }
    }
}

