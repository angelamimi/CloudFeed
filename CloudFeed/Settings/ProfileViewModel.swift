//
//  ProfileViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/23/25.
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
protocol ProfileDelegate: AnyObject {
    func beginSwitchingAccounts()
    func noAccountsFound()
    func profileResultReceived(profile: Profile?)
}

@MainActor
protocol AccountDelegate: AnyObject {
    func userChanged()
    func userChangeError()
}

@MainActor
class ProfileViewModel {

    let dataService: DataService

    weak var delegate: ProfileDelegate!
    weak var accountDelegate: AccountDelegate!
    let coordinator: SettingsCoordinator
    let resetDelegate: ResetApplicationDelegate

    init(delegate: ProfileDelegate, accountDelegate: AccountDelegate, resetDelegate: ResetApplicationDelegate, dataService: DataService, coordinator: SettingsCoordinator) {
        self.delegate = delegate
        self.accountDelegate = accountDelegate
        self.resetDelegate = resetDelegate
        self.dataService = dataService
        self.coordinator = coordinator
    }

    func requestProfile() {

        guard let currentUser = Environment.current.currentUser else {
            delegate.profileResultReceived(profile: Profile(name: "", email: "", quotaUsed: nil, quotaTotal: nil))
            return
        }

        Task.detached { [weak self] in

            guard let account = await self?.dataService.getActiveAccount() else {
                await MainActor.run { [weak self] in
                    self?.delegate.profileResultReceived(profile: Profile(name: "", email: "", quotaUsed: nil, quotaTotal: nil))
                }
                return
            }

            if let profileResult = await self?.dataService.getUserProfile(account: currentUser.account) {

                await self?.downloadAvatar(account: account, user: currentUser.user)
                let image = await self?.loadAvatar(account: account)

                let profile = Profile(name: profileResult.name, email: profileResult.email, image: image, mediaPath: account.mediaPath, quotaUsed: profileResult.quotaUsed, quotaTotal: profileResult.quotaTotal)

                await MainActor.run { [weak self] in
                    self?.delegate?.profileResultReceived(profile: profile)
                }
            } else {
                await MainActor.run { [weak self] in
                    self?.delegate.profileResultReceived(profile: Profile(name: "", email: "", quotaUsed: nil, quotaTotal: nil))
                }
            }
        }
    }

    func downloadAvatar(account: Account, user: String) async {

        let userBaseUrl = buildUserBaseUrl(account)
        let fileName = userBaseUrl + "-" + user + ".png"

        await dataService.downloadAvatar(fileName: fileName, account: account, screenScale: UIScreen.main.scale)
    }

    private func buildUserBaseUrl(_ account: Account) -> String {
        return account.user + "-" + (URL(string: account.urlBase)?.host ?? "")
    }

    func loadAvatar(account: Account) async -> UIImage? {

        let userBaseUrl = buildUserBaseUrl(account)
        let image = loadUserImage(for: account.userId, userBaseUrl: userBaseUrl)

        return image
    }

    private func loadUserImage(for user: String, userBaseUrl: String) -> UIImage? {

        let fileName = userBaseUrl + "-" + user + ".png"
        let localFilePath = dataService.store.getUserDirectory() + "/" + fileName

        if let localImage = UIImage(contentsOfFile: localFilePath) {
            return localImage
        } else {
            return nil
        }
    }

    func showPicker() {
        coordinator.showPicker()
    }

    func checkRemoveAccount() {
        coordinator.checkRemoveAccount { [weak self] in
            self?.removeAccount()
        }
    }

    func lockCheck() {
        if let account = Environment.current.currentUser?.account,
           (dataService.store.getPasscode(account)) != nil {
            coordinator.showPasscode(modal: true)
        }
    }

    func removeAccount() {

        guard let account = Environment.current.currentUser?.account else { return }

        delegate?.beginSwitchingAccounts()

        Task.detached { [weak self] in

            await self?.dataService.removeAccount(account)

            if let accounts = await self?.dataService.getAccountsOrdered() {

                if accounts.isEmpty {
                    await MainActor.run { [weak self] in
                        Environment.current.clear()
                        self?.delegate.noAccountsFound()
                    }
                } else {
                    await MainActor.run { [weak self] in
                        self?.changeAccount(account: accounts.first!.account)
                    }
                }
            }
        }
    }

    func changeAccount(account: String) {

        Task.detached { [weak self] in

            guard let tableAccount = await self?.dataService.setActiveAccount(account) else {
                await MainActor.run { [weak self] in
                    self?.accountDelegate.userChangeError()
                }
                return
            }

            await Environment.current.setCurrentUser(account: account, user: tableAccount.user, userId: tableAccount.userId)

            if let currentUser = await Environment.current.currentUser {

                await self?.dataService.appendSession(account: currentUser.account, user: currentUser.user, userId: currentUser.userId, urlBase: tableAccount.urlBase)
                await self?.dataService.updateAccount(account: currentUser.account)

                let version = await self?.dataService.getServerVersion(account: currentUser.account)
                await Environment.current.setCurrentServer(urlBase: tableAccount.urlBase, version: version ?? "")

                self?.dataService.clearWidgetData()

                await MainActor.run { [weak self] in
                    self?.accountDelegate.userChanged()
                }
            }
        }
    }

    func showProfileLoadfailedError() {
        coordinator.showProfileLoadfailedError()
    }

    func applicationReset() {

        Task.detached { [weak self] in

            await self?.dataService.reset()

            await MainActor.run { [weak self] in
                Environment.current.clear()
                self?.resetDelegate.reset()
            }
        }
    }
}
