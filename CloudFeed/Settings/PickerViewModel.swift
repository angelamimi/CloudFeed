//
//  PickerViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 6/11/25.
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
protocol PickerViewModelDelegate: AnyObject {
    func mediaPathUpdated()
    func rootLoaded(metadata: Metadata, folderLocation: String, metadatas: [Metadata]?, mediaFileCount: Int?)
    func folderLoaded(isHome: Bool, metadatas: [Metadata]?, mediaFileCount: Int?)
}

@MainActor
class PickerViewModel {

    private let coordinator: PickerCoordinator
    private nonisolated let dataService: DataService
    private weak var delegate: PickerViewModelDelegate?

    init(coordinator: PickerCoordinator, dataService: DataService, delegate: PickerViewModelDelegate?) {
        self.coordinator = coordinator
        self.dataService = dataService
        self.delegate = delegate
    }

    func open(_ serverUrl: String, _ metadata: Metadata) {
        coordinator.open(serverUrl, metadata)
    }

    func readRoot() {

        guard let user = Environment.current.currentUser, let server = Environment.current.currentServer else {
            return
        }

        Task.detached { [weak self] in

            if let folderLocation = self?.dataService.getHomeServer(urlBase: server.urlBase, userId: user.userId) {

                let results = await self?.readFolder(user.account, folderLocation, "", depth: "0")

                if let metadata = results?.metadatas.first,
                   let folderResults = await self?.readFolder(user.account, folderLocation, metadata.fileId, depth: "1") {

                    await MainActor.run { [weak self] in
                        self?.delegate?.rootLoaded(metadata: metadata, folderLocation: folderLocation, metadatas: folderResults.metadatas, mediaFileCount: folderResults.mediaFileCount)
                    }
                }
            }
        }
    }

    func readFolder(_ folderLocation: String, _ metadata: Metadata?) {

        guard let user = Environment.current.currentUser,
              let server = Environment.current.currentServer,
              let fileId = metadata?.fileId else {
            return
        }

        let homeServer = dataService.getHomeServer(urlBase: server.urlBase, userId: user.userId)

        Task.detached { [weak self] in

            let results = await self?.readFolder(user.account, folderLocation, fileId, depth: "1")

            await MainActor.run { [weak self] in
                self?.delegate?.folderLoaded(isHome: folderLocation == homeServer, metadatas: results?.metadatas, mediaFileCount: results?.mediaFileCount)
            }
        }
    }

    func updateAccountMediaPath(account: String, serverUrl: String) {

        guard let user = Environment.current.currentUser, let server = Environment.current.currentServer else {
            return
        }

        let homeServer = dataService.getHomeServer(urlBase: server.urlBase, userId: user.userId)

        Task.detached { [weak self] in

            let mediaPath = serverUrl.replacingOccurrences(of: homeServer, with: "")

            await self?.dataService.updateAccountMediaPath(account: account, mediaPath: mediaPath)

            await MainActor.run { [weak self] in
                self?.delegate?.mediaPathUpdated()
            }
        }
    }

    @concurrent private func readFolder(_ account: String, _ serverUrl: String, _ currentDirectoryId: String, depth: String) async -> (metadatas: [Metadata], mediaFileCount: Int)? {

        let result = await dataService.readFolder(account: account, serverUrl: serverUrl, depth: depth)
        let folders = result?.metadatas.filter { $0.fileId != currentDirectoryId }

        return (metadatas: folders ?? [], mediaFileCount: result?.mediaFileCount ?? 0)
    }
}
