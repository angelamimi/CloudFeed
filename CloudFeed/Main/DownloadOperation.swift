//
//  DownloadOperation.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/13/24.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
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
    func downloaded(metadata: Metadata)
    func progress(metadata: Metadata, progress: Progress)
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
    
    override func main() {

        task = Task { [weak self] in

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
                await self?.delegate?.downloaded(metadata: metadata)
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
        await dataService?.download(metadata: metadata!, progressHandler: { [weak self] metadata, progress in
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.progress(metadata: metadata, progress: progress)
            }
        })
    }
}
