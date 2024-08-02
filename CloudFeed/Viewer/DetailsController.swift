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
    
    weak var store: StoreUtility?
    weak var metadata: tableMetadata?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DetailsController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindDetailView()
    }
    
    override func viewDidLayoutSubviews() {
        if view.frame.size.width > 0 {
            detailViewHeightConstraint.constant = view.frame.size.height
            detailViewWidthConstraint.constant = view.frame.size.width
        }
    }
    
    private func bindDetailView() {
        
        guard let metadata = metadata else { return }
        
        detailView.metadata = metadata
        
        if metadata.image && store != nil && store!.fileExists(metadata) {
            //detailView.path = store!.getCachePath(metadata.ocId, metadata.fileNameView)
            if let path = store!.getCachePath(metadata.ocId, metadata.fileNameView) {
                detailView.url = URL(fileURLWithPath: path)
            }
        }
        
        detailView.populateDetails()
    }
}
