//
//  DetailController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
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

//Displayes "all" file metadata/exif information in a table
class DetailController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var viewModel: DetailViewModel!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailController.self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        
        tableView.showsHorizontalScrollIndicator = false
        tableView.showsVerticalScrollIndicator = false
        
        viewModel.buildDetailsDatasource()
    }
}

extension DetailController: DetailDelegate {
    
    func detailLoaded() {
        tableView?.reloadData()
    }
}

extension DetailController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sectionId = DetailViewModel.MetadataSectionId(rawValue: section) {
            if let details = viewModel.details[sectionId]?.details {
                return details.count
            }
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if let sectionId = DetailViewModel.MetadataSectionId(rawValue: section) {
            
            if viewModel.details[sectionId]?.details.count == 0 {
                return nil //hides the section
            }
            
            let title = viewModel.details[sectionId]?.title
            return title == nil ? "" : title
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
       
        let cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell") as! DetailCell
        
        if let sectionId = DetailViewModel.MetadataSectionId(rawValue: indexPath.section), let details = viewModel.details[sectionId]?.details {
            let row = details[indexPath.row]
            cell.titleLabel?.text = row.title
            cell.detailLabel?.text = row.detail
        }
        
        return cell
    }
}

extension DetailController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

class MetadataSection {
    var title: String?
    var details: [MetadataDetail]
      
    init(title: String) {
        self.title = title
        self.details = []
    }
    
    func addDetail(_ detail: MetadataDetail) {
        details.append(detail)
    }
    
    func addDetail(title: String? = nil, detail: String? = nil) {
        details.append(MetadataDetail(title: title, detail: detail))
    }
}

class MetadataDetail {
    var title : String?
    var detail : String?
    
    init(title: String? = nil, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }
}
