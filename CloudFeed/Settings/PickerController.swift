//
//  PickerController.swift
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
protocol PickerDelegate: AnyObject {
    func cancel()
    func select()
}

class PickerController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var viewModel: PickerViewModel?
    weak var delegate: PickerDelegate?
    
    private var metadatas: [Metadata]?
    private var mediaFileCount: Int?
    
    var serverUrl: String = ""
    var metadata: Metadata?
    
    override func viewDidLoad() {
        
        tableView.delegate = self
        tableView.dataSource = self
        
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.prefersLargeTitles = true
        
        if navigationItem.rightBarButtonItem == nil {
            let item = UIBarButtonItem(title: Strings.CancelAction, image: nil, target: self, action: #selector(cancel))
            item.tintColor = .label
            navigationItem.setRightBarButton(item, animated: true)
        }
        
        selectButton.setTitle(Strings.SelectAction, for: .normal)
        selectButton.addTarget(self, action: #selector(selected), for: .touchUpInside)
        
        UIAccessibility.post(notification: .screenChanged, argument: navigationItem.rightBarButtonItem)
    }
    
    @objc func selected() {
        if let account = Environment.current.currentUser?.account {
            Task { [weak self] in
                await self?.viewModel?.updateAccountMediaPath(account: account, serverUrl: self?.serverUrl ?? "")
                self?.delegate?.select()
            }
        }
    }
    
    @objc func cancel() {
        delegate?.cancel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        activityIndicator.startAnimating()
        
        showFolderData()
    }
    
    private func getRootMetadata(folderLocation: String) async -> Metadata? {
        if let results = await viewModel?.readFolder(folderLocation, "", depth: "0"),
           let metadata = results.metadatas.first {
            return metadata
        }
        return nil
    }
    
    private func showFolderData() {
        
        Task { [weak self] in
            
            if self != nil && self!.serverUrl.isEmpty {
                
                if let folderLocation = self?.viewModel?.getHomeServer(),
                   let metadata = await self?.getRootMetadata(folderLocation: folderLocation) {
                    
                    let results = await self?.viewModel?.readFolder(folderLocation, metadata.fileId, depth: "1")
                    
                    self?.navigationItem.title = Strings.SettingsLabelNextcloud
                    self?.metadata = metadata
                    self?.serverUrl = folderLocation
                    self?.metadatas = results?.metadatas ?? []
                    self?.mediaFileCount = results?.mediaFileCount ?? 0
                    
                    self?.tableView.reloadData()
                }
            } else {
                if let folderLocation = self?.serverUrl {
                    
                    if folderLocation == self?.viewModel?.getHomeServer() {
                        self?.navigationItem.title = Strings.SettingsLabelNextcloud
                    } else {
                        self?.navigationItem.title = self?.metadata?.fileNameView ?? ""
                    }
                    
                    if let fileId = self?.metadata?.fileId {
                        let results = await self?.viewModel?.readFolder(folderLocation, fileId, depth: "1")
                        self?.metadatas = results?.metadatas ?? []
                        self?.mediaFileCount = results?.mediaFileCount ?? 0
                        self?.tableView.reloadData()
                    }
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.activityIndicator.stopAnimating()
            }
        }
    }
}

extension PickerController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard let metadata = metadatas?[indexPath.item] else { return }
        
        var newServerUrl: String
        
        if serverUrl.last == "/" {
            newServerUrl = serverUrl + metadata.fileNameView
        } else {
            newServerUrl = serverUrl + "/" + metadata.fileNameView
        }
        
        viewModel?.open(newServerUrl, metadata)
    }
}

extension PickerController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        
        var mediaFileCountDescription: String
        var foldersDescription: String
        let fileCount = mediaFileCount ?? 0
        let folderCount = metadatas?.count ?? 0
        
        let formatter = NumberFormatter()
        
        formatter.numberStyle = .decimal
        formatter.locale = .current
        
        if fileCount == 1 {
            mediaFileCountDescription = "\(formatter.string(for: fileCount) ?? "") \(Strings.SettingsLabelFile)"
        } else {
            mediaFileCountDescription = "\(formatter.string(for: fileCount) ?? "") \(Strings.SettingsLabelFiles)"
        }
        
        if folderCount == 1 {
            foldersDescription = "\(formatter.string(for: folderCount) ?? "") \(Strings.SettingsLabelFolder)"
        } else {
            foldersDescription = "\(formatter.string(for: folderCount) ?? "") \(Strings.SettingsLabelFolders)"
        }
        
        return "\(mediaFileCountDescription) \(foldersDescription)"
    }
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let footerView = view as? UITableViewHeaderFooterView {
            footerView.textLabel?.textAlignment = .center
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return metadatas?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell()
        
        guard let metadata = metadatas?[indexPath.item] else { return cell }
        
        var config = UIListContentConfiguration.cell()

        config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
        config.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .footnote)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        config.image = UIImage(systemName: "folder")
        config.text = metadata.fileNameView
        
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        
        config.secondaryText = formatter.string(from: metadata.date)
        
        cell.contentConfiguration = config
        
        return cell
    }
}
