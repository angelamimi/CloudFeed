//
//  DownloadAvatarOperation.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 5/31/26.
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
import os.log

@MainActor
protocol DownloadAvatarOperationDelegate: AnyObject {
    func avatarDownloaded(id: String)
}

class DownloadAvatarOperation: AsyncOperation, @unchecked Sendable {
    
    private var task: Task<Void, Never>?
    private var objectId: String //associated object. could be a commentId or metadataId
    private var userId: String
    private var urlBase: String
    private var account: String
    private weak var dataService: DataService?
    private weak var delegate: DownloadAvatarOperationDelegate?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DownloadAvatarOperation.self)
    )
    
    init(objectId: String, userId: String, urlBase: String, account: String, dataService: DataService, delegate: DownloadAvatarOperationDelegate) {
        self.objectId = objectId
        self.userId = userId
        self.urlBase = urlBase
        self.account = account
        self.dataService = dataService
        self.delegate = delegate
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
            
            if let objId = self?.objectId {
                await self?.delegate?.avatarDownloaded(id: objId)
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
        await dataService?.downloadAvatar(userId: userId, urlBase: urlBase, account: account, screenScale: 1.0)
    }
}


