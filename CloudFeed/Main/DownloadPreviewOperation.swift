//
//  DownloadPreviewOperation.swift
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

@MainActor
protocol DownloadPreviewOperationDelegate: AnyObject {
    func previewDownloaded(metadata: Metadata)
}

nonisolated class DownloadPreviewOperation: AsyncOperation, @unchecked Sendable {

    private var task: Task<Void, Never>?
    private var metadata: Metadata?
    private var account: String?
    private weak var dataService: DataService?
    private weak var delegate: DownloadPreviewOperationDelegate?

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DownloadPreviewOperation.self)
    )

    init(_ account: String, _ metadata: Metadata, dataService: DataService, delegate: DownloadPreviewOperationDelegate) {
        self.metadata = metadata
        self.account = account
        self.delegate = delegate
        self.dataService = dataService
    }

    override func main() {

        task = Task.detached { [weak self] in

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
                await self?.delegate?.previewDownloaded(metadata: metadata)
            }

            self?.finish()
        }
    }

    override func cancel() {
        super.cancel()

        task?.cancel()
        task = nil
    }

    nonisolated private func download() async {

        if metadata?.video ?? false {
            await dataService?.downloadVideoPreview(metadata: metadata)
        } else if metadata?.svg ?? false {
            await dataService?.downloadSVGPreview(account: account!, metadata: metadata)
        } else if metadata != nil && account != nil {
            await dataService?.downloadPreview(account: account!, metadata: metadata)
        }
    }
}
