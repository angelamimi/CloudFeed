//
//  FavoritesController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/1/23.
//

import UIKit
import os.log

class FavoritesController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FavoritesController.self)
    )
}
