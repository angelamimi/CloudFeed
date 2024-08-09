//
//  DetailsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 7/26/24.
//

import UIKit
import os.log

class DetailsController: UIViewController {
    
    @IBOutlet weak var detailView: DetailView!
    
    @IBOutlet weak var detailViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailViewHeightConstraint: NSLayoutConstraint!
    
    var metadata: tableMetadata?
    var url: URL?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailsController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Self.logger.debug("viewDidLoad")
        
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeUpRecognizer.direction = .up
        
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeDownRecognizer.direction = .down
        
        view.addGestureRecognizer(swipeUpRecognizer)
        view.addGestureRecognizer(swipeDownRecognizer)
        
        
        bindDetailView()
    }
    
    @objc private func handleSwipe(swipeGesture: UISwipeGestureRecognizer) {

        if swipeGesture.direction == .up {
            Self.logger.debug("handleSwipe() - up")
            self.preferredContentSize = CGSize(width: 400, height: 220)
        } else {
            Self.logger.debug("handleSwipe() - down")
            self.preferredContentSize = CGSize(width: 400, height: 600)
        }
    }
    
    override func viewDidLayoutSubviews() {
        //TODO: Why did this with frame?
       /* if view.frame.size.width > 0 {
            detailViewHeightConstraint.constant = view.frame.size.height
            detailViewWidthConstraint.constant = view.frame.size.width
        }*/
    }
    
    func populateDetails(url: URL) {
        Self.logger.debug("populateDetails() - file: \(self.metadata?.fileNameView ?? "nil metadata?????") calling populateDetails")
        
        //guard let metadata = metadata else { return }
        
        detailView.metadata = metadata
        detailView.url = url
        
        detailView.populateDetails()
    }
    
    private func bindDetailView() {
        
        guard let metadata = metadata else { return }
        
        //Self.logger.debug("bindDetailView() - file: \(metadata.fileNameView)")
 
        detailView.metadata = metadata
        detailView.url = url
        
        detailView.populateDetails()
        
        Self.logger.debug("bindDetailView() - file: \(metadata.fileNameView) size: \(self.view.frame.size.debugDescription) detail size: \(self.detailView.frame.size.debugDescription)")

        //self.preferredContentSize = CGSize(width: 400, height: self.detailView.frame.size.height)
    }
}
