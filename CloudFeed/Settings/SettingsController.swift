//
//  SettingsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/18/23.
//

import os.log
import UIKit

class SettingsController: UIViewController {
    
    var coordinator: SettingsCoordinator!
    var viewModel: SettingsViewModel!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
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
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        
        let backgroundColorView = UIView()
        backgroundColorView.backgroundColor = UIColor.systemGroupedBackground
        UITableViewCell.appearance().selectedBackgroundView = backgroundColorView
    }

    override func viewWillAppear(_ animated: Bool) {
        requestProfile()
        requestAvatar()
        calculateCacheSize()
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
    
    private func requestAvatar() {
        viewModel.requestAvatar()
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
        
        tableView.deselectRow(at: indexPath, animated: true)
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
                
                if let dictionary = Bundle.main.infoDictionary,
                    let version = dictionary["CFBundleShortVersionString"] as? String,
                    let build = dictionary["CFBundleVersion"] as? String {
                    content.text = "\(Strings.SettingsLabelVersion) \(version) (\(build))"
                } else {
                    content.text = "\(Strings.SettingsLabelVersion) (\(Strings.SettingsLabelVersionUnknown)))" //"Version (unknown)"
                }
            } else if indexPath.section == 2 && indexPath.item == 0 {
                content.image = UIImage(systemName: "trash")
                content.text = Strings.SettingsItemClearCache
                content.secondaryText = "\(Strings.SettingsLabelCacheSize): \(cacheSizeDescription)" //"Cache size: " + cacheSizeDescription
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
    
    func avatarLoaded(image: UIImage?) {
        self.profileImage = image
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .none)
        }
    }
    
    func cacheCleared() {
        coordinator.cacheCleared()
        calculateCacheSize()
        
        DispatchQueue.main.async { [weak self] in
            self?.stopActivityIndicator()
        }
    }
    
    func cacheCalculated(cacheSize: Int64) {
        
        cacheSizeDescription = StoreUtility.transformedSize(cacheSize)
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadRows(at: [IndexPath(item: 1, section: 0)], with: .none)
            self?.tableView.reloadData()
        }
    }
    
    func profileResultReceived(profileName: String, profileEmail: String) {
        
        self.profileName = profileName
        self.profileEmail = profileEmail
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .none)
            self?.stopActivityIndicator()
            
            if profileName == "" && profileEmail == "" {
                self?.showProfileLoadfailedError()
            }
        }
    }
}

