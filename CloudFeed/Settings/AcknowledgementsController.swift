//
//  AcknowledgementsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/4/23.
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

import UIKit
import os.log

final class AcknowledgementsController : UIViewController { //UITableViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    
    private var acknowledgements: [NSDictionary] = []
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: AcknowledgementsController.self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        initTitle()
        
        tableView.register(UINib(nibName: "AcknowledgementCell", bundle: nil), forCellReuseIdentifier: "AcknowledgementCell")
        
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 120;
        
        tableView.dataSource = self
        tableView.delegate = self
        
        guard let plistURL = Bundle.main.url(forResource: "Acknowledgements", withExtension: "plist") else {
            Self.logger.error("Failed to load Acknowledgements.plist")
            return
        }
        
        guard let array = NSArray(contentsOf: plistURL) as? [NSDictionary] else { return }
        acknowledgements = array
    }
    
    private func initTitle() {
        navigationItem.title = Strings.SettingsItemAcknowledgements
        navigationItem.largeTitleDisplayMode = .never
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.backgroundColor = .systemGroupedBackground
    }
}

extension AcknowledgementsController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return acknowledgements.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AcknowledgementCell", for: indexPath) as! AcknowledgementCell
        let acknowledgement = acknowledgements[indexPath.row]
        cell.titleLabel.text = acknowledgement.object(forKey: "title") as? String
        cell.licenseLabel.text = acknowledgement.object(forKey: "license") as? String
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
         return UITableView.automaticDimension
    }
}

