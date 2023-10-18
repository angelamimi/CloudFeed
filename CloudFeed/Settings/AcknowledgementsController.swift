//
//  AcknowledgementsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/4/23.
//

import UIKit
import os.log

final class AcknowledgementsController : UITableViewController {
    
    private var acknowledgements: [NSDictionary] = []
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: AcknowledgementsController.self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Acknowledgements"
        
        let item = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .done, target: self, action: #selector(didTapCloseButton))
        
        item.tintColor = .label
        navigationItem.leftBarButtonItem = item
        
        tableView.register(UINib(nibName: "AcknowledgementCell", bundle: nil), forCellReuseIdentifier: "AcknowledgementCell")
        
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 120;
        
        guard let plistURL = Bundle.main.url(forResource: "Acknowledgements", withExtension: "plist") else {
            Self.logger.error("Failed to load Acknowledgements.plist")
            return
        }
        
        guard let array = NSArray(contentsOf: plistURL) as? [NSDictionary] else { return }
        acknowledgements = array
    }
    
    @objc public func didTapCloseButton() {
        navigationController?.popViewController(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return acknowledgements.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AcknowledgementCell", for: indexPath) as! AcknowledgementCell
        let acknowledgement = acknowledgements[indexPath.row]
        cell.titleLabel.text = acknowledgement.object(forKey: "title") as? String
        cell.licenseLabel.text = acknowledgement.object(forKey: "license") as? String
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
         return UITableView.automaticDimension
    }
}

