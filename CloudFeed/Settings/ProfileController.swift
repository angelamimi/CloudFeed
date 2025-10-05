//
//  ProfileController.swift
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

import os.log
import UIKit

final class ProfileController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var viewModel: ProfileViewModel?

    private var mediaPath: String = ""
    private var profileName: String = ""
    private var profileEmail: String = ""
    private var profileImage: UIImage?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ProfileController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        initTitle()
        
        NotificationCenter.default.addObserver(self, selector: #selector(mediaPathChanged), name: Notification.Name("MediaPathChanged"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if Environment.current.currentUser == nil {
            mediaPath = ""
            profileName = ""
            profileEmail = ""
            profileImage = nil
            tableView.reloadData()
            viewModel?.removeAccount()
        } else {
            requestProfile()
        }
    }
    
    @objc func mediaPathChanged() {
        reload()
    }
    
    func reload() {
        requestProfile()
    }
    
    private func requestProfile() {
        startActivityIndicator()
        
        Task { [weak self] in
            await self?.viewModel?.requestProfile()
        }
    }
    
    private func startActivityIndicator() {
        activityIndicator.startAnimating()
    }
    
    private func stopActivityIndicator() {
        activityIndicator.stopAnimating()
    }
    
    private func initTitle() {
        navigationItem.title = Strings.ProfileNavTitleManage
        navigationItem.largeTitleDisplayMode = .never
        
        if #unavailable(iOS 26) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance = appearance
            navigationController?.navigationBar.backgroundColor = .systemGroupedBackground
        }
    }
}

extension ProfileController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 && indexPath.item == 2 {
            viewModel?.showPicker()
        } else if indexPath.section == 2 && indexPath.item == 0 {
            viewModel?.checkRemoveAccount()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ""
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            return 1
        } else if section == 1 {
            return 3
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        if indexPath.section == 0 && indexPath.item == 0 {
            return 200
        } else {
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 && indexPath.item == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "AvatarCell", for: indexPath) as! AvatarCell
            
            cell.updateAvatarImage(profileImage)
            
            return cell
            
        } else {
            
            let cell = UITableViewCell()
            cell.selectionStyle = .none
            cell.backgroundColor = .secondarySystemGroupedBackground
            
            var config = cell.defaultContentConfiguration()

            config.prefersSideBySideTextAndSecondaryText = true
            config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
            config.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .body)
            config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Global.shared.tablePadding, leading: 0, bottom: Global.shared.tablePadding, trailing: Global.shared.tablePadding)
            
            if indexPath.section == 1 && indexPath.item == 0 {
                config.text = Strings.ProfileItemName
                config.secondaryText = profileName
            } else if indexPath.section == 1 && indexPath.item == 1 {
                config.text = Strings.ProfileItemEmail
                config.secondaryText = profileEmail
            } else if indexPath.section == 1 && indexPath.item == 2 {
                config.text = Strings.SettingsLabelMediaPath
                config.secondaryText = mediaPath.isEmpty ? "/" : mediaPath
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .gray
            } else {
                config.text = Strings.ProfileItemRemoveAccount
                config.textProperties.color = .red
                config.imageProperties.tintColor = .red
                config.image = UIImage(systemName: "trash")
                cell.selectionStyle = .gray
            }
            
            cell.contentConfiguration = config
            
            return cell
        }
    }
}

extension ProfileController: AccountDelegate {
    
    func userChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
            self?.navigationController?.popViewController(animated: true)
        }
    }
    
    func userChangeError() {
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
            self?.viewModel?.showProfileLoadfailedError()
        }
    }
}

extension ProfileController: ProfileDelegate {
    
    func beginSwitchingAccounts() {
        DispatchQueue.main.async { [weak self] in
            self?.startActivityIndicator()
        }
    }
    
    func noAccountsFound() {
        viewModel?.applicationReset()
    }
    
    func profileResultReceived(profileName: String, profileEmail: String, profileImage: UIImage?, mediaPath: String) {
        
        self.profileName = profileName
        self.profileEmail = profileEmail
        self.profileImage = profileImage
        self.mediaPath = mediaPath
        
        DispatchQueue.main.async { [weak self] in
            
            guard self?.tableView.window != nil else { return }

            self?.tableView.reloadData()
            self?.stopActivityIndicator()
            
            if profileName == "" && profileEmail == "" {
                self?.viewModel?.showProfileLoadfailedError()
            }
        }
    }
}
