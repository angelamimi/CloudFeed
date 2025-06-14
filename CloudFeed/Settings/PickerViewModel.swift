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
class PickerViewModel {
    
    private let coordinator: PickerCoordinator
    private let dataService: DataService
    
    init(coordinator: PickerCoordinator, dataService: DataService) {
        self.coordinator = coordinator
        self.dataService = dataService
    }
    
    func getHomeServer() -> String? {
        if let user = Environment.current.currentUser {
            return dataService.getHomeServer(urlBase: user.urlBase, userId: user.userId)
        }
        return nil
    }
    
    func readFolder(_ serverUrl: String, _ currentDirectoryId: String, depth: String) async -> [Metadata]? {
        guard let account = Environment.current.currentUser?.account else { return nil }
        let folders = await dataService.readFolder(account: account, serverUrl: serverUrl, depth: depth)
        return folders?.filter { $0.fileId != currentDirectoryId }
    }
    
    func open(_ serverUrl: String, _ metadata: Metadata) {
        coordinator.open(serverUrl, metadata)
    }
    
    func updateAccountMediaPath(account: String, serverUrl: String) async {
        let homeServer = getHomeServer() ?? ""
        let mediaPath = serverUrl.replacingOccurrences(of: homeServer, with: "")
        await dataService.updateAccountMediaPath(account: account, mediaPath: mediaPath)
    }
}
