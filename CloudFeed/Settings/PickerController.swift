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

        initActions()

        UIAccessibility.post(notification: .screenChanged, argument: navigationItem.rightBarButtonItem)
    }

    override func viewWillAppear(_ animated: Bool) {

        activityIndicator.startAnimating()

        loadFolderData()
    }

    func selected() {
        if let account = Environment.current.currentUser?.account {
            viewModel?.updateAccountMediaPath(account: account, serverUrl: serverUrl)
        }
    }

    func cancel() {
        delegate?.cancel()
    }

    private func loadFolderData() {

        if serverUrl.isEmpty {
            viewModel?.readRoot()
        } else {
            viewModel?.readFolder(serverUrl, metadata)
        }
    }

    private func initActions() {

        if navigationItem.rightBarButtonItem == nil {
            let cancelAction = UIAction { [weak self] _ in
                self?.cancel()
            }
            let item = UIBarButtonItem(title: nil, image: .init(systemName: "xmark"), primaryAction: cancelAction)
            item.tintColor = .label
            navigationItem.setRightBarButton(item, animated: true)
        }

        selectButton.configuration?.title = Strings.SelectAction

        let selectAction = UIAction { [weak self] _ in
            self?.selected()
        }
        selectButton.addAction(selectAction, for: .touchUpInside)
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

extension PickerController: PickerViewModelDelegate {

    func mediaPathUpdated() {
        delegate?.select()
    }

    func rootLoaded(metadata: Metadata, folderLocation: String, metadatas: [Metadata]?, mediaFileCount: Int?) {

        navigationItem.title = Strings.SettingsLabelNextcloud

        self.metadata = metadata
        self.serverUrl = folderLocation
        self.metadatas = metadatas ?? []
        self.mediaFileCount = mediaFileCount ?? 0

        tableView.reloadData()
        activityIndicator.stopAnimating()
    }

    func folderLoaded(isHome: Bool, metadatas: [Metadata]?, mediaFileCount: Int?) {

        if isHome {
            navigationItem.title = Strings.SettingsLabelNextcloud
        } else {
            navigationItem.title = metadata?.fileNameView ?? ""
        }

        self.metadatas = metadatas ?? []
        self.mediaFileCount = mediaFileCount ?? 0

        tableView.reloadData()
        activityIndicator.stopAnimating()
    }
}
