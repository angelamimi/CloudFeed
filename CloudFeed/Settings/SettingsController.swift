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
    
    var coordinator: SettingsCoordinator!
    var viewModel: SettingsViewModel!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var addAccountButton: UIBarButtonItem!

    private var profileName: String = ""
    private var profileEmail: String = ""
    private var profileImage: UIImage?
    
    private var cacheSizeDescription: String = ""
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SettingsController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Strings.SettingsNavTitle
        
        addAccountButton.menu = buildAccountsMenu()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = UITableView.automaticDimension
        
        let backgroundColorView = UIView()
        backgroundColorView.backgroundColor = UIColor.systemGroupedBackground
        UITableViewCell.appearance().selectedBackgroundView = backgroundColorView
    }
    
    override func viewDidAppear(_ animated: Bool) {
        requestProfile()
        calculateCacheSize()
    }

    func clear() {
        requestProfile()
        viewModel.clearCache()
    }
    
    private func startActivityIndicator() {
        activityIndicator.startAnimating()
        self.view.isUserInteractionEnabled = false
    }
    
    private func stopActivityIndicator() {
        activityIndicator.stopAnimating()
        self.view.isUserInteractionEnabled = true
    }
    
    private func requestProfile() {
        startActivityIndicator()
        viewModel.requestProfile()
    }
    
    private func acknowledgements() {
        coordinator.showAcknowledgements()
    }
    
    private func checkReset() {
        coordinator.checkReset { [weak self] in
            self?.reset()
        }
    }
    
    private func reset() {
        viewModel.reset()
    }
    
    private func calculateCacheSize() {
        viewModel.calculateCacheSize()
    }
    
    private func showProfileLoadfailedError() {
        coordinator.showProfileLoadfailedError()
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
        
        let accounts = viewModel.getAccounts()
        var accountActions: [UIAction] = []
        
        for account in accounts {
            
            await viewModel.downloadAvatar(account: account, user: account.user)
            
            let image = await viewModel.loadAvatar(account: account)
            let name: String
            
            if account.alias.isEmpty {
                name = account.displayName
            } else {
                name = account.alias
            }
            
            let action = UIAction(title: name, image: image, state: account.active ? .on : .off) { [weak self] _ in
                if !account.active {
                    self?.changeAccount(account: account.account)
                }
            }

            accountActions.append(action)
        }
        
        return accountActions
    }
    
    private func addAccount() {
        coordinator.launchAddAccount()
    }
    
    private func changeAccount(account: String) {
        viewModel.changeAccount(account: account)
    }
}

extension SettingsController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 1 && indexPath.item == 0 {
            acknowledgements()
        } else if indexPath.section == 2 && indexPath.item == 0 {
            startActivityIndicator()
            viewModel.clearCache()
        } else if indexPath.section == 2 && indexPath.item == 1 {
            checkReset()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 1 {
            return Strings.SettingsSectionInformation
        } else if section == 2 {
            return Strings.SettingsSectionData
        }
        return ""
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            return 1
        } else {
            return 2
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section == 0 && indexPath.item == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath) as! ProfileCell
            
            cell.updateProfileImage(profileImage)
            cell.updateProfile(profileEmail, fullName: profileName)
            
            return cell
            
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)

            var content = cell.defaultContentConfiguration()
            
            content.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
            content.textProperties.lineBreakMode = .byWordWrapping
            
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24.0, leading: 0, bottom: 24.0, trailing: 0)
            
            if indexPath.section == 1 && indexPath.item == 0 {
                
                content.image = UIImage(systemName: "person.wave.2")
                content.text = Strings.SettingsItemAcknowledgements
                cell.tintColor = UIColor.label
                cell.accessoryType = .disclosureIndicator
                
            } else if indexPath.section == 1 && indexPath.item == 1 {
                
                content.image = UIImage(systemName: "info.circle")
                cell.accessoryType = .none
                cell.tintColor = UIColor.label
                cell.selectionStyle = .none
                
                if let dictionary = Bundle.main.infoDictionary,
                    let version = dictionary["CFBundleShortVersionString"] as? String,
                    let build = dictionary["CFBundleVersion"] as? String {
                    content.text = "\(Strings.SettingsLabelVersion) \(version) (\(build))"
                } else {
                    content.text = "\(Strings.SettingsLabelVersion) (\(Strings.SettingsLabelVersionUnknown)))"
                }
                
            } else if indexPath.section == 2 && indexPath.item == 0 {
                
                content.image = UIImage(systemName: "trash")
                content.text = Strings.SettingsItemClearCache
                content.secondaryText = "\(Strings.SettingsLabelCacheSize): \(cacheSizeDescription)"
                cell.tintColor = UIColor.label
                cell.accessoryType = .none
                
            } else if indexPath.section == 2 && indexPath.item == 1 {
                
                content.image = UIImage(systemName: "xmark.octagon")
                content.text = Strings.SettingsItemResetApplication
                cell.tintColor = UIColor.red
                cell.accessoryType = .none
            }
            
            cell.contentConfiguration = content
            
            return cell
        }
    }
}

extension SettingsController: SettingsDelegate {
    
    func userChangeError() {
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
            self?.coordinator.showProfileLoadfailedError()
        }
    }
    
    func userChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
            self?.clear()
        }
    }
    
    func applicationReset() {
        exit(0)
    }
    
    func cacheCleared() {
        coordinator.cacheCleared()
        calculateCacheSize()
        
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
        }
    }
    
    func cacheCalculated(cacheSize: Int64) {
        
        cacheSizeDescription = ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .binary)
        
        DispatchQueue.main.async { [weak self] in
            if self?.tableView.window != nil {
                self?.tableView.reloadRows(at: [IndexPath(item: 1, section: 0)], with: .automatic)
                self?.tableView.reloadData()
            }
        }
    }
    
    func profileResultReceived(profileName: String, profileEmail: String, profileImage: UIImage?) {
        
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

