//
//  DownloadOperation.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/13/24.
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

@MainActor
protocol DownloadOperationDelegate: AnyObject {
    func imageDownloaded(metadata: Metadata)
}

class DownloadOperation: AsyncOperation, @unchecked Sendable {
    
    private var task: Task<Void, Never>?
    private var metadata: Metadata?
    private weak var dataService: DataService?
    private weak var delegate: DownloadOperationDelegate?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DownloadOperation.self)
    )

    init(_ metadata: Metadata, dataService: DataService, delegate: DownloadOperationDelegate) {
        self.metadata = metadata
        self.delegate = delegate
        self.dataService = dataService
    }
    
    deinit {
        self.delegate = nil
    }
    
    override func main() {
        
        task = Task(priority: .background) { [weak self] in

            if self?.isCancelled ?? true {
                self?.finish()
                return
            }
            
            await self?.download()
            
            if self?.isCancelled ?? true {
                self?.finish()
                return
            }
            
            if let metadata = self?.metadata {
                await self?.delegate?.imageDownloaded(metadata: metadata)
            }
            
            self?.finish()
        }
    }
    
    override func cancel() {
        super.cancel()
        
        task?.cancel()
        task = nil
    }
    
    private func download() async {
        
        if metadata?.video ?? false {
            await dataService?.downloadVideoPreview(metadata: metadata)
        } else if metadata?.svg ?? false {
            await loadSVG(metadata: metadata)
        } else if metadata != nil {
            await dataService?.downloadPreview(metadata: metadata)
        }
    }
    
    private func loadSVG(metadata: Metadata?) async {
        
        guard dataService != nil && metadata != nil else { return }

        if !dataService!.store.fileExists(metadata!) && metadata!.image {
            
            await dataService!.download(metadata: metadata!, selector: "")
            
            let iconPath = dataService!.store.getIconPath(metadata!.ocId, metadata!.etag)
            let imagePath = dataService!.store.getCachePath(metadata!.ocId, metadata!.fileNameView)!
            
            ImageUtility.loadSVGPreview(metadata: metadata!, imagePath: imagePath, previewPath: iconPath)
        }
    }
}