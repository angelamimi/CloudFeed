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

import UIKit

final class ProfileController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    
    var viewModel: ProfileViewModel?
    
    private var titleView: TitleView?

    private var profileName: String = ""
    private var profileEmail: String = ""
    private var profileImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.isNavigationBarHidden = true
        
        tableView.delegate = self
        tableView.dataSource = self
        
        initTitleView()
        initConstraints()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if Environment.current.currentUser == nil {
            profileName = ""
            profileEmail = ""
            profileImage = nil
            tableView.reloadData()
            viewModel?.removeAccount()
        } else {
            requestProfile()
        }
    }
    
    private func requestProfile() {
        startActivityIndicator()
        viewModel?.requestProfile()
    }
    
    private func startActivityIndicator() {
        activityIndicator.startAnimating()
    }
    
    private func stopActivityIndicator() {
        activityIndicator.stopAnimating()
    }
    
    private func initTitleView() {
        
        titleView = Bundle.main.loadNibNamed("TitleView", owner: self, options: nil)?.first as? TitleView
        titleView?.navigationDelegate = self
        titleView?.initNavigation(withMenu: false)
        titleView?.title.text = Strings.ProfileNavTitle
        titleView?.backgroundColor = .systemGroupedBackground
        
        self.view.addSubview(titleView!)
    }
    
    private func initConstraints() {

        titleView?.translatesAutoresizingMaskIntoConstraints = false
        
        titleView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        titleView?.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        titleView?.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
        
        let titleViewHeightAnchor = titleView?.heightAnchor.constraint(equalToConstant: Global.shared.titleSize)
        titleViewHeightAnchor?.isActive = true
        
        tableViewTopConstraint.constant = Global.shared.titleSize
    }
}

extension ProfileController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2 && indexPath.item == 0 {
            viewModel?.checkRemoveAccount()
            tableView.deselectRow(at: indexPath, animated: true)
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
            return 2
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
            
            //var config = UIListContentConfiguration.cell()
            var config = cell.defaultContentConfiguration()
            config.prefersSideBySideTextAndSecondaryText = true
            config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
            config.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .body)
            config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16.0, leading: 0, bottom: 16.0, trailing: 0)
            
            if indexPath.section == 1 && indexPath.item == 0 {
                config.text = Strings.ProfileItemName
                config.secondaryText = profileName
            } else if indexPath.section == 1 && indexPath.item == 1 {
                config.text = Strings.ProfileItemEmail
                config.secondaryText = profileEmail
            } else {
                cell.selectionStyle = .gray
                config.textProperties.color = .red
                config.imageProperties.tintColor = .red
                config.image = UIImage(systemName: "trash")
                config.text = Strings.ProfileItemRemoveAccount
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
    
    func profileResultReceived(profileName: String, profileEmail: String, profileImage: UIImage?) {
        
        self.profileName = profileName
        self.profileEmail = profileEmail
        self.profileImage = profileImage
        
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

extension ProfileController: NavigationDelegate {
    
    func cancel() {
        navigationController?.popViewController(animated: true)
    }
    
    func titleTouched() {
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }
}
