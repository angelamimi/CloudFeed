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
    
    var viewModel: DisplayViewModel?
    
    override func viewDidLoad() {
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        
        initObservers()
        initTitle()
        
        style = viewModel?.getStyle()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func initObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
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
    
    @objc
    private func systemSwitchChanged(_ sender: UISwitch!) {
        
        if sender.isOn {
            let system = UIScreen.main.traitCollection.userInterfaceStyle
            style = nil
            viewModel?.setStyle(style: nil)
            updateUserInterfaceStyle(system)
            tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .automatic)
        } else {
            viewModel?.setStyle(style: style)
            updateUserInterfaceStyle(style)
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
            let system = UIScreen.main.traitCollection.userInterfaceStyle
            if system == .dark {
                updateUserInterfaceStyle(.dark)
                return .dark
            } else {
                updateUserInterfaceStyle(.light)
                return .light
            }
        }
        
        updateUserInterfaceStyle(style!)
        return style!
    }
}

extension DisplayController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 2
        } else {
            return 0
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return Strings.SettingsSectionDisplayMode
        } else {
            return ""
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section == 0 && indexPath.item == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ModeCell", for: indexPath) as! ModeCell
            cell.delegate = self
            cell.setStyle(style: processCellStyle(style))
            return cell
            
        } else {
            
            let cell = UITableViewCell()
            cell.selectionStyle = .none
            cell.backgroundColor = .secondarySystemGroupedBackground
            
            var config = cell.defaultContentConfiguration()

            config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
            config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Global.shared.tablePadding, leading: 0, bottom: Global.shared.tablePadding, trailing: 0)
            config.textProperties.color = .label
            
            if indexPath.section == 0 && indexPath.item == 1 {
                config.text = Strings.SettingsItemSystemStyle
                
                let switchView = UISwitch(frame: .zero)
                
                switchView.onTintColor = .tintColor
                switchView.setOn(style == nil, animated: true)
                switchView.addTarget(self, action: #selector(systemSwitchChanged(_:)), for: .valueChanged)
                
                cell.isAccessibilityElement = true
                cell.accessibilityLabel = Strings.SettingsItemSystemStyle
                cell.accessibilityValue = style == nil ? Strings.SwitchValueOn : Strings.SwitchValueOff
                cell.accessoryView = switchView
            }
            
            cell.contentConfiguration = config
            
            return cell
        }
    }
}

extension DisplayController: ModeDelegate {
    
    func selectionChangedDark() {
        viewModel?.setStyle(style: .dark)
        updateUserInterfaceStyle(.dark)
        style = .dark
        tableView.reloadData()
    }
    
    func selectionChangedLight() {
        viewModel?.setStyle(style: .light)
        updateUserInterfaceStyle(.light)
        style = .light
        tableView.reloadData()
    }
}
