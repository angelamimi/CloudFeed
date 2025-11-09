//
//  PasscodeSettingsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/27/25.
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

class PasscodeSettingsController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var viewModel: PasscodeSettingsViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        initTitle()
    }
    
    private func initTitle() {
        navigationItem.title = Strings.SettingsItemSettingsPasscode
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

extension PasscodeSettingsController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.item == 0 {
            viewModel?.editPasscode()
        } else if indexPath.section == 0 && indexPath.item == 1 {
            guard let cell = tableView.cellForRow(at: indexPath) else { return }
            guard let resetSwitch = cell.accessoryView as? UISwitch else { return }
            resetSwitch.isOn.toggle()
            viewModel?.setAppReset(resetSwitch.isOn)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ""
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = .secondarySystemGroupedBackground
        
        var config = cell.defaultContentConfiguration()

        config.prefersSideBySideTextAndSecondaryText = true
        config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
        config.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .body)
        config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Global.shared.tablePadding, leading: 0, bottom: Global.shared.tablePadding, trailing: Global.shared.tablePadding)
        
        if indexPath.section == 0 && indexPath.item == 0 {
            config.text = Strings.SettingsItemEditPasscode
        } else if indexPath.section == 0 && indexPath.item == 1 {
            let resetSwitch = UISwitch()
            resetSwitch.addTarget(self, action: #selector(resetSwitchChanged(_:)), for: .valueChanged)
            resetSwitch.isOn = viewModel?.getAppReset() ?? false

            config.text = Strings.SettingsItemResetAppPasscode
            cell.accessoryView = resetSwitch
        }
        
        cell.contentConfiguration = config
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return Strings.SettingsItemResetAppDescriptionPasscode
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    @objc private func resetSwitchChanged(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell else { return }
        guard let resetSwitch = cell.accessoryView as? UISwitch else { return }
        viewModel?.setAppReset(resetSwitch.isOn)
    }
}
