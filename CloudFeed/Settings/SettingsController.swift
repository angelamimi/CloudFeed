//
//  SettingsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/18/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
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

import os.log
import UIKit

class SettingsController: UIViewController {
    
    var viewModel: SettingsViewModel!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    private var profileName: String = ""
    private var profileEmail: String = ""
    private var profileImage: UIImage?
    
    private var cacheSizeDescription: String = ""
    
    var mode: Global.SettingsMode = .all
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SettingsController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = UITableView.automaticDimension
        
        initTitle()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.reloadData()
        
        requestProfile()
        calculateCacheSize()
    }
    
    func setCompactNavigation() {
        mode = .all
        navigationItem.hidesBackButton = true
        navigationItem.title = Strings.SettingsNavTitle
    }

    func clear(notify: Bool, reload: Bool) {
        
        profileName = ""
        profileEmail = ""
        profileImage = nil
        tableView?.reloadData()
        
        if reload {
            requestProfile()
        }
        
        viewModel.clearCache(notify: notify)
    }
    
    func updateMode(_ mode: Global.SettingsMode) {
        
        self.mode = mode
        
        var title = ""
        
        switch mode {
        case .account: title = Strings.ProfileNavTitleView
        case .data: title = Strings.SettingsSectionData
        case .display: title = Strings.SettingsSectionDisplay
        case .information: title = Strings.SettingsSectionInformation
        case .privacy: title = Strings.SettingsSectionPrivacy
        default:
            title = ""
        }
        
        navigationItem.title = title
        
        if mode == .account && navigationItem.rightBarButtonItem == nil {
            let item = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: buildAccountsMenu())
            item.tintColor = .label
            navigationItem.setRightBarButton(item, animated: true)
        } else if mode != .account {
            navigationItem.rightBarButtonItem = nil
        }
        
        tableView.reloadData()
    }
    
    private func initTitle() {
        
        navigationItem.title = Strings.SettingsNavTitle
        
        if #unavailable(iOS 26) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance = appearance
            navigationController?.navigationBar.backgroundColor = .systemGroupedBackground
        }
        
        if mode == .all {
            navigationController?.navigationBar.prefersLargeTitles = true
        }
        
        navigationController?.navigationBar.preservesSuperviewLayoutMargins = true
        
        let item = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: buildAccountsMenu())
        item.tintColor = .label
        navigationItem.setRightBarButton(item, animated: true)
    }
    
    private func startActivityIndicator() {
        activityIndicator.startAnimating()
        view.isUserInteractionEnabled = false
    }
    
    private func stopActivityIndicator() {
        activityIndicator.stopAnimating()
        view.isUserInteractionEnabled = true
    }
    
    private func requestProfile() {
        if Environment.current.currentUser == nil {
            viewModel.addAccount()
        } else {
            startActivityIndicator()
            Task { [weak self] in
                await self?.viewModel.requestProfile()
            }
        }
    }
    
    private func acknowledgements() {
        viewModel.showAcknowledgements()
    }
    
    private func checkReset() {
        viewModel.checkReset()
    }
    
    private func calculateCacheSize() {
        viewModel.calculateCacheSize()
    }
    
    private func showProfileLoadfailedError() {
        viewModel.showProfileLoadfailedError()
    }
    
    private func buildAccountsMenu() -> UIMenu {
        
        let accountActions = UIDeferredMenuElement.uncached ({ [weak self] completion in
            Task {
                let items = await self?.buildAccountMenuItems()
                completion(items == nil ? [] : items!)
            }
        })
        
        var addAccountItems: [UIMenuElement] = []

        let addAccountAction = UIAction(title: Strings.SettingsMenuAddAccount, image: UIImage(systemName: "person.crop.circle.badge.plus"), state: .off) { [weak self] action in
            self?.addAccount()
        }
        
        addAccountItems.append(addAccountAction)
        
        let addAccountSubmenu = UIMenu(title: "", options: [.displayInline], children: addAccountItems)

        return UIMenu(children: [accountActions] + [addAccountSubmenu])
    }
    
    private func buildAccountMenuItems() async -> [UIAction] {
        
        let accounts = await viewModel.getAccounts()
        var accountActions: [UIAction] = []
        
        for account in accounts {
            
            await viewModel.downloadAvatar(account: account, user: account.user)
            
            let image = await roundAvatar(account: account)
            let name = account.displayName
            let host = URL(string: account.urlBase)?.host ?? ""
            
            let action = UIAction(title: name, subtitle: host, image: image, state: account.active ? .on : .off) { [weak self] _ in
                if !account.active {
                    self?.changeAccount(account: account.account)
                }
            }

            accountActions.append(action)
        }
        
        return accountActions
    }
    
    private func roundAvatar(account: Account) async -> UIImage? {
        
        if var image = await viewModel.loadAvatar(account: account) {

            let rect = CGRect(x: 0, y: 0, width: 30, height: 30)
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
            UIBezierPath(roundedRect: rect, cornerRadius: rect.size.height).addClip()
            image.draw(in: rect)
            image = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
             
            return image
        }
        
        return nil
    }
    
    private func addAccount() {
        viewModel.addAccount()
    }
    
    private func changeAccount(account: String) {
        viewModel.changeAccount(account: account)
    }
    
    private func handleProfileLoaded(profileName: String, profileEmail: String, profileImage: UIImage?) {
        
        self.profileImage = profileImage
        self.profileName = profileName
        self.profileEmail = profileEmail
        
        DispatchQueue.main.async { [weak self] in
            
            guard self?.tableView.window != nil else { return }
            
            self?.tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .automatic)
            self?.stopActivityIndicator()
            
            if profileName == "" && profileEmail == "" {
                self?.showProfileLoadfailedError()
            }
        }
    }
}

extension SettingsController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch mode {
        case .account:
            if indexPath.section == 0 && indexPath.item == 0 {
                viewModel.showProfile()
            }
        case .display:
            if indexPath.section == 0 && indexPath.item == 0 {
                viewModel.showDisplay()
            }
        case .privacy:
            if indexPath.section == 0 && indexPath.item == 0 {
                viewModel.showPrivacy()
            } else if indexPath.section == 0 && indexPath.item == 1 {
                viewModel.showRemovePasscode()
            }
        case .information:
            if indexPath.section == 0 && indexPath.item == 0 {
                acknowledgements()
            }
        case .data:
            if indexPath.section == 0 && indexPath.item == 0 {
                viewModel.clearCache(notify: true)
            } else if indexPath.section == 0 && indexPath.item == 1 {
                checkReset()
            }
        case .all:
            if indexPath.section == 0 && indexPath.item == 0 {
                viewModel.showProfile()
            } else if indexPath.section == 1 && indexPath.item == 0 {
                viewModel.showDisplay()
            } else if indexPath.section == 2 && indexPath.item == 0 {
                viewModel.showPrivacy()
            } else if indexPath.section == 2 && indexPath.item == 1 {
                viewModel.showRemovePasscode()
            } else if indexPath.section == 3 && indexPath.item == 0 {
                acknowledgements()
            } else if indexPath.section == 4 && indexPath.item == 0 {
                startActivityIndicator()
                viewModel.clearCache(notify: true)
            } else if indexPath.section == 4 && indexPath.item == 1 {
                checkReset()
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        switch mode {
        case .account:
            return 1
        case .display:
            return 1
        case .privacy:
            return 1
        case .information:
            return 1
        case .data:
            return 1
        case .all:
            return 5
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if mode == .all {
            if section == 1 {
                return Strings.SettingsSectionDisplay
            } else if section == 2 {
                return Strings.SettingsSectionPrivacy
            } else if section == 3 {
                return Strings.SettingsSectionInformation
            } else if section == 4 {
                return Strings.SettingsSectionData
            }
        }
        return ""
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if mode == .all {
            return UITableView.automaticDimension
        } else {
            return 8 
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch mode {
        case .account:
            return 1
        case .display:
            return 1
        case .privacy:
            if viewModel.hasPasscode() {
                return 2
            } else {
                return 1
            }
        case .information:
            return 2
        case .data:
            return 2
        case .all:
            if section == 0 || section == 1 {
                return 1
            } else if section == 2 {
                if viewModel.hasPasscode() {
                    return 2
                } else {
                    return 1
                }
            } else {
                return 2
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch mode {
        case .account:
            return configureProfileCell(indexPath)
        case .display:
            return configureAppearanceCell(indexPath)
        case .privacy:
            if indexPath.section == 0 && indexPath.item == 0 {
                return configurePasscodeCell(indexPath)
            } else if viewModel.hasPasscode() && indexPath.section == 0 && indexPath.item == 1 {
                return configureRemovePasscodeCell(indexPath)
            }
        case .information:
            if indexPath.section == 0 && indexPath.item == 0 {
                return configureAcknowledgementsCell(indexPath)
            } else if indexPath.section == 0 && indexPath.item == 1 {
                return configureVersionCell(indexPath)
            }
        case .data:
            if indexPath.section == 0 && indexPath.item == 0 {
                return configureCacheCell(indexPath)
            } else if indexPath.section == 0 && indexPath.item == 1 {
                return configureResetCell(indexPath)
            }
        case .all:
            if indexPath.section == 0 && indexPath.item == 0 {
                return configureProfileCell(indexPath)
            } else if indexPath.section == 1 && indexPath.item == 0 {
                return configureAppearanceCell(indexPath)
            } else if indexPath.section == 2 && indexPath.item == 0 {
                return configurePasscodeCell(indexPath)
            } else if indexPath.section == 2 && indexPath.item == 1 {
                return configureRemovePasscodeCell(indexPath)
            } else if indexPath.section == 3 && indexPath.item == 0 {
                return configureAcknowledgementsCell(indexPath)
            } else if indexPath.section == 3 && indexPath.item == 1 {
                return configureVersionCell(indexPath)
            } else if indexPath.section == 4 && indexPath.item == 0 {
                return configureCacheCell(indexPath)
            } else if indexPath.section == 4 && indexPath.item == 1 {
                return configureResetCell(indexPath)
            }
        }
        return UITableViewCell()
    }
    
    private func buildSettingsCellContent(indexPath: IndexPath) -> (cell: UITableViewCell, content: UIListContentConfiguration) {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)

        var content = cell.defaultContentConfiguration()
        
        content.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
        content.textProperties.lineBreakMode = .byWordWrapping
        
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Global.shared.tablePadding, leading: 0, bottom: Global.shared.tablePadding, trailing: 0)

        return (cell, content)
    }
    
    private func configureProfileCell(_ indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath) as! ProfileCell
        
        cell.updateProfileImage(profileImage)
        cell.updateProfile(profileEmail, fullName: profileName)
        
        cell.accessoryType = .disclosureIndicator
        
        if mode != .all {
            cell.backgroundColor = .secondarySystemGroupedBackground
        }
        
        return cell
    }
    
    private func configureAppearanceCell(_ indexPath: IndexPath) -> UITableViewCell {
        
        var result = buildSettingsCellContent(indexPath: indexPath)
        
        result.content.image = UIImage(systemName: "sun.max")
        result.content.text = Strings.SettingsItemAppearance
        result.cell.tintColor = .label
        result.cell.accessoryType = .disclosureIndicator
        
        result.cell.contentConfiguration = result.content
        
        return result.cell
    }
    
    private func configurePasscodeCell(_ indexPath: IndexPath) -> UITableViewCell {
        
        var result = buildSettingsCellContent(indexPath: indexPath)
        
        if viewModel.hasPasscode() {
            result.content.image = UIImage(systemName: "lock")
            result.content.text = Strings.SettingsItemSettingsPasscode
        } else {
            result.content.image = UIImage(systemName: "lock.open")
            result.content.text = Strings.SettingsItemAddPasscode
        }
        
        result.cell.tintColor = .label
        result.cell.accessoryType = .disclosureIndicator

        result.cell.contentConfiguration = result.content
        
        return result.cell
    }
    
    private func configureRemovePasscodeCell(_ indexPath: IndexPath) -> UITableViewCell {
        
        var result = buildSettingsCellContent(indexPath: indexPath)
        
        result.content.image = UIImage(systemName: "lock.slash")
        result.content.text = Strings.SettingsItemDeletePasscode
        
        result.cell.tintColor = .red
        result.cell.accessoryType = .disclosureIndicator

        result.cell.contentConfiguration = result.content
        
        return result.cell
    }
    
    private func configureAcknowledgementsCell(_ indexPath: IndexPath) -> UITableViewCell {
        
        var result = buildSettingsCellContent(indexPath: indexPath)
        
        result.content.image = UIImage(systemName: "person.wave.2")
        result.content.text = Strings.SettingsItemAcknowledgements
        result.cell.tintColor = .label
        result.cell.accessoryType = .disclosureIndicator

        result.cell.contentConfiguration = result.content
        
        return result.cell
    }
    
    private func configureVersionCell(_ indexPath: IndexPath) -> UITableViewCell {
        
        var result = buildSettingsCellContent(indexPath: indexPath)
        
        result.content.image = UIImage(systemName: "info.circle")
        result.cell.accessoryType = .none
        result.cell.tintColor = .label
        result.cell.selectionStyle = .none
        
        if let dictionary = Bundle.main.infoDictionary,
            let version = dictionary["CFBundleShortVersionString"] as? String,
            let build = dictionary["CFBundleVersion"] as? String {
            result.content.text = "\(Strings.SettingsLabelVersion) \(version) (\(build))"
        } else {
            result.content.text = "\(Strings.SettingsLabelVersion) (\(Strings.SettingsLabelVersionUnknown)))"
        }
        
        result.cell.contentConfiguration = result.content
        
        return result.cell
    }
    
    private func configureCacheCell(_ indexPath: IndexPath) -> UITableViewCell {
        
        var result = buildSettingsCellContent(indexPath: indexPath)
        
        result.content.image = UIImage(systemName: "trash")
        result.content.text = Strings.SettingsItemClearCache
        result.content.secondaryText = "\(Strings.SettingsLabelCacheSize): \(cacheSizeDescription)"
        result.cell.tintColor = .label
        result.cell.accessoryType = .none
        
        result.cell.contentConfiguration = result.content
        
        return result.cell
    }
    
    private func configureResetCell(_ indexPath: IndexPath) -> UITableViewCell {
        
        var result = buildSettingsCellContent(indexPath: indexPath)
        
        result.content.image = UIImage(systemName: "xmark.octagon")
        result.content.text = Strings.SettingsItemResetApplication
        result.cell.tintColor = .red
        result.cell.accessoryType = .none
        
        result.cell.contentConfiguration = result.content
        
        return result.cell
    }
}

extension SettingsController: ProfileDelegate {
    
    func beginSwitchingAccounts() {}
    func noAccountsFound() {}
    
    func profileResultReceived(profileName: String, profileEmail: String, profileImage: UIImage?, mediaPath: String) {
        handleProfileLoaded(profileName: profileName, profileEmail: profileEmail, profileImage: profileImage)
    }
}

extension SettingsController: SettingsDelegate {
    
    func profileResultReceived(profileName: String, profileEmail: String, profileImage: UIImage?) {
        handleProfileLoaded(profileName: profileName, profileEmail: profileEmail, profileImage: profileImage)
    }
    
    func userChangeError() {
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
            self?.viewModel.showProfileLoadfailedError()
        }
    }
    
    func userChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
            self?.clear(notify: true, reload: true)
            self?.viewModel.userAccountChanged()
            self?.viewModel?.lockCheck()
        }
    }
    
    func cacheCleared() {
        
        calculateCacheSize()
        
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
        }
    }
    
    func cacheCalculated(cacheSize: Int64) {

        cacheSizeDescription = ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
        
        DispatchQueue.main.async { [weak self] in
            if self?.tableView.window != nil {
                self?.tableView.reloadData()
            }
        }
    }
}

