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
    func showAllMetadataDetails(metadata: Metadata)
}

//DetailsView container used for pad only
class DetailsController: UIViewController {
    
    private weak var detailView: DetailView!
    
    var metadata: Metadata?
    var url: URL?
    
    weak var delegate: DetailsControllerDelegate?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailsController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initDetailView()
        detailView.delegate = self
        
        addGestures()
        bindDetailView()
    }
    
    override func viewDidLayoutSubviews() {
        setPreferredSize()
    }
    
    func populateDetails(metadata: Metadata, url: URL) {
        
        self.metadata = metadata
        self.url = url
        
        detailView.initDetails(metadata: metadata, url: url)
        
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.detailView?.alpha = 0.4
            self?.detailView?.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.detailView.populateDetails()
        })
    }
    
    @objc private func handleSwipe(swipeGesture: UISwipeGestureRecognizer) {
        dismiss(animated: false)
    }
    
    private func initDetailView() {
        
        guard let detailView = Bundle.main.loadNibNamed("DetailView", owner: self, options: nil)?.first as? DetailView else { return }
        
        self.detailView = detailView
        
        view.addSubview(detailView)
        
        detailView.translatesAutoresizingMaskIntoConstraints = false
        
        detailView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        detailView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        detailView.widthAnchor.constraint(equalToConstant: preferredContentSize.width).isActive = true
        
        let heightAnchor = detailView.heightAnchor.constraint(equalToConstant: 0)
        heightAnchor.priority = .defaultLow
        heightAnchor.isActive = true
        
        view.layoutIfNeeded()
    }
    
    private func bindDetailView() {
        
        guard let metadata = metadata else { return }
        
        detailView.metadata = metadata
        detailView.url = url
        
        detailView.fillerView.isHidden = true
        
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
    
    private func setPreferredSize() {
        let targetSize = CGSize(width: 400, height: detailView.height())
        preferredContentSize = detailView.systemLayoutSizeFitting(targetSize)
    }
}

extension DetailsController : DetailViewDelegate {
    
    func detailsLoaded() {
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.detailView.alpha = 1
            self?.detailView.layoutIfNeeded()
        })
    }
    
    func showAllDetails(metadata: Metadata) {
        delegate?.showAllMetadataDetails(metadata: metadata)
    }
}
