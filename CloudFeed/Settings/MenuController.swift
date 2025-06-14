//
//  MenuController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 5/9/25.
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
protocol MenuDelegate: AnyObject {
    func selectProfile()
    func selectDisplay()
    func selectInformation()
    func selectData()
}

class MenuController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleView: TitleView!
    
    var delegate: MenuDelegate?
    
    override func viewDidLoad() {
        
        tableView.dataSource = self
        tableView.delegate = self

        tableViewTopConstraint.constant = 16 //58
        
        navigationItem.title = Strings.SettingsNavTitle
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.backgroundColor = .systemGroupedBackground
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if tableView.indexPathForSelectedRow == nil {
            selectProfile()
        }
    }
    
    func selectProfile() {
        tableView.selectRow(at: IndexPath(item: 0, section: 0), animated: true, scrollPosition: .top)
        delegate?.selectProfile()
    }
}

extension MenuController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.item == 0 {
            delegate?.selectProfile()
        } else if indexPath.section == 0 && indexPath.item == 1 {
            delegate?.selectDisplay()
        } else if indexPath.section == 0 && indexPath.item == 2 {
            delegate?.selectInformation()
        } else if indexPath.section == 0 && indexPath.item == 3 {
            delegate?.selectData()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell()
        cell.selectionStyle = .default
        cell.backgroundColor = .secondarySystemGroupedBackground
        cell.focusEffect = nil

        var config = cell.defaultContentConfiguration()

        config.textProperties.color = .label
        config.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
        config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Global.shared.tablePadding, leading: 0, bottom: Global.shared.tablePadding, trailing: 0)
        config.imageProperties.tintColor = .label
        
        if indexPath.section == 0 && indexPath.item == 0 {
            config.text = Strings.ProfileNavTitle
            config.image = UIImage(systemName: "person")
        } else if indexPath.section == 0 && indexPath.item == 1 {
            config.text = Strings.SettingsSectionDisplay
            config.image = UIImage(systemName: "sun.max")
        } else if indexPath.section == 0 && indexPath.item == 2 {
            config.text = Strings.SettingsSectionInformation
            config.image = UIImage(systemName: "info.circle")
        } else if indexPath.section == 0 && indexPath.item == 3 {
            config.text = Strings.SettingsSectionData
            config.image = UIImage(systemName: "note.text")
        }
        
        cell.contentConfiguration = config
        
        return cell
    }
}
