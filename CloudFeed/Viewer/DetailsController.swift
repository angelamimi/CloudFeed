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
    
    private func bindDetailView() {
        
        Self.logger.debug("bindDetailView()")
        
        guard let metadata = metadata else { return }
        
        detailView.metadata = metadata
        
        if metadata.image && store != nil && store!.fileExists(metadata) {
            detailView.path = store!.getCachePath(metadata.ocId, metadata.fileNameView)
        }
        
        detailView.populateDetails()
    }
}
