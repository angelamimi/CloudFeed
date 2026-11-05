//
//  DisplayController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 5/6/25.
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

final class DisplayController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var style: UIUserInterfaceStyle?
    private var videoControlsBackground: Bool?

    var viewModel: DisplayViewModel?

    override func viewDidLoad() {

        tableView.delegate = self
        tableView.dataSource = self
        tableView.sectionHeaderHeight = UITableView.automaticDimension

        initObservers()
        initTitle()

        style = viewModel?.getStyle()
        videoControlsBackground = viewModel?.getVideoControlsStyleBackground() ?? true
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func initObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.willEnterForegroundNotification()
            }
        }
    }

    private func willEnterForegroundNotification() {
        if isViewLoaded && view.window != nil {
            style = viewModel?.getStyle()
            tableView.reloadData()
        }
    }

    private func initTitle() {
        navigationItem.title = Strings.SettingsItemAppearance
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

    private func systemSwitchChanged(_ sender: UISwitch) {

        if sender.isOn {
            let system = UIScreen.main.traitCollection.userInterfaceStyle
            style = nil
            viewModel?.setStyle(style: nil)
            updateUserInterfaceStyle(system)
            tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .automatic)
        } else {
            if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? ModeCell {
                style = cell.style
                viewModel?.setStyle(style: style)
            }
        }
    }

    private func videoControlsStyleSwitchChanged(_ sender: UISwitch) {

        if sender.isOn {
            videoControlsBackground = true
            viewModel?.setVideoControlsStyleBackground(hasBackground: true)
        } else {
            videoControlsBackground = false
            viewModel?.setVideoControlsStyleBackground(hasBackground: false)
        }
    }

    private func updateUserInterfaceStyle(_ style: UIUserInterfaceStyle?) {

        if style != nil {
            let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for windowScene in windowScenes {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style!
                }
            }
        }
    }

    private func processCellStyle(_ style: UIUserInterfaceStyle?) -> UIUserInterfaceStyle {
        if style == nil {
            return UIScreen.main.traitCollection.userInterfaceStyle
        } else {
            return style!
        }
    }

    private func setStyle(_ style: UIUserInterfaceStyle) {
        updateUserInterfaceStyle(style)
        self.style = style
        viewModel?.setStyle(style: style)
    }
}

extension DisplayController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: false)

        if indexPath.section == 0 && indexPath.item == 0 {

            if style == .light {
                setStyle(.dark)
            } else if style == .dark {
                setStyle(.light)
            } else {
                let system = UIScreen.main.traitCollection.userInterfaceStyle

                if system == .unspecified || system == .light {
                    setStyle(.dark)
                } else {
                    setStyle(.light)
                }
            }

            tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 2
        } else {
            return 1
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return Strings.SettingsSectionDisplayMode
        } else if section == 1 {
            return Strings.SettingsSectionVideoControls
        } else {
            return ""
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section == 0 && indexPath.item == 0 {

            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ModeCell", for: indexPath) as? ModeCell else { return UITableViewCell() }

            let currentStyle = processCellStyle(style)
            cell.setStyle(style: currentStyle)

            return cell

        } else if indexPath.section == 0 && indexPath.item == 1 {

            let cell = UITableViewCell()
            cell.selectionStyle = .none
            cell.backgroundColor = .secondarySystemGroupedBackground

            var config = cell.defaultContentConfiguration()

            config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
            config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Global.shared.tablePadding, leading: 0, bottom: Global.shared.tablePadding, trailing: 0)
            config.textProperties.color = .label
            config.text = Strings.SettingsItemSystemStyle

            let switchView = UISwitch(frame: .zero)

            switchView.onTintColor = .tintColor
            switchView.setOn(style == nil, animated: true)

            let systemAction = UIAction { [weak self] action in
                if let sender = action.sender as? UISwitch {
                    self?.systemSwitchChanged(sender)
                }
            }

            switchView.addAction(systemAction, for: .valueChanged)

            cell.isAccessibilityElement = true
            cell.accessibilityLabel = Strings.SettingsItemSystemStyle
            cell.accessibilityValue = style == nil ? Strings.SwitchValueOn : Strings.SwitchValueOff
            cell.accessoryView = switchView
            cell.contentConfiguration = config

            return cell

        } else {

            let cell = UITableViewCell()
            cell.selectionStyle = .none
            cell.backgroundColor = .secondarySystemGroupedBackground

            var config = cell.defaultContentConfiguration()

            config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
            config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Global.shared.tablePadding, leading: 0, bottom: Global.shared.tablePadding, trailing: 0)
            config.textProperties.color = .label
            config.text = Strings.SettingsLabelVideoControlsStyle

            let switchView = UISwitch(frame: .zero)

            switchView.onTintColor = .tintColor
            switchView.setOn(videoControlsBackground == true, animated: true)

            let styleAction = UIAction { [weak self] action in
                if let sender = action.sender as? UISwitch {
                    self?.videoControlsStyleSwitchChanged(sender)
                }
            }

            switchView.addAction(styleAction, for: .valueChanged)

            cell.isAccessibilityElement = true
            cell.accessibilityLabel = Strings.SettingsLabelVideoControlsStyle
            cell.accessibilityValue = videoControlsBackground == true ? Strings.SwitchValueOn : Strings.SwitchValueOff
            cell.accessoryView = switchView
            cell.contentConfiguration = config

            return cell
        }
    }
}
