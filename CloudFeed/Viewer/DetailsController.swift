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
    func dismissingDetails()
}

//DetailsView container used for pad only
class DetailsController: UIViewController {
    
    @IBOutlet weak var navigationStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    
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
        
        titleLabel.text = Strings.DetailTitle
        
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        
        initDetailView()
        
        addGestures()
        bindDetailView()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if view.frame.width == 0 || view.frame.height == 0 {
            //Bug? Sometimes the view's frame is rendered invalid upon rotation. User sees nothing but system reports a visible presentedViewController
            close()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        setPreferredSize()

        let size = CGSizeMake(view.frame.size.width, detailView.height())
        if !scrollView.contentSize.equalTo(size) {
            scrollView.contentSize = size
        }
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
        close()
    }
    
    @objc func close() {
        delegate?.dismissingDetails()
        dismiss(animated: true)
    }
    
    private func initDetailView() {
        
        guard let detailView = Bundle.main.loadNibNamed("DetailView", owner: self, options: nil)?.first as? DetailView else { return }
        
        detailView.delegate = self
        
        self.detailView = detailView
        
        scrollView.addSubview(detailView)
        
        detailView.translatesAutoresizingMaskIntoConstraints = false
        detailView.widthAnchor.constraint(equalToConstant: preferredContentSize.width).isActive = true
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
        let height = detailView.height() + navigationStackView.frame.height + 16
        preferredContentSize = CGSize(width: 400, height: height)
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
