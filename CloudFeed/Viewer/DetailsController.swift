//
//  DetailsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 7/26/24.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
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

@MainActor
protocol DetailsControllerDelegate: AnyObject {
    func showAllMetadataDetails()
}

//DetailsView container used for pad only
class DetailsController: UIViewController {
    
    @IBOutlet weak var detailView: DetailView!
    
    var metadata: Metadata?
    var url: URL?
    
    weak var delegate: DetailsControllerDelegate?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailsController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()

        detailView.delegate = self
        
        addGestures()
        bindDetailView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
       
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            let detailHeight = detailView.height()
            let width = view.frame.width
            
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                self?.preferredContentSize = CGSize(width: width, height: detailHeight)
            })
        }
    }
    
    func populateDetails(url: URL) {

        guard let metadata = metadata else { return }
        
        detailView.metadata = metadata
        detailView.url = url
        
        detailView.populateDetails()
    }
    
    @objc private func handleSwipe(swipeGesture: UISwipeGestureRecognizer) {
        dismiss(animated: false)
    }
    
    private func bindDetailView() {
        
        guard let metadata = metadata else { return }
 
        detailView.metadata = metadata
        detailView.url = url
        
        detailView.populateDetails()
    }
    
    private func addGestures() {
        
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        
        swipeUpRecognizer.direction = .up
        swipeDownRecognizer.direction = .down
        
        view.addGestureRecognizer(swipeUpRecognizer)
        view.addGestureRecognizer(swipeDownRecognizer)
    }
}

extension DetailsController : DetailViewDelegate {
    
    func showAllDetails() {
        delegate?.showAllMetadataDetails()
    }
}
