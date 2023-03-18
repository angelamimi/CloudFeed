//
//  ViewController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/11/23.
//

import NextcloudKit
import os.log
import UIKit

class MainViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private var metadatas: [tableMetadata] = []
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: MainViewController.self)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, ocId: String) -> UICollectionViewCell? in
            
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: "CollectionViewCell", for: indexPath) as? CollectionViewCell else { fatalError("Cannot create new cell") }
            
                self.setImage(ocId: ocId, cell: cell, indexPath: indexPath)
            
                return cell
            }
        
        collectionView.dataSource = dataSource
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([1])
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        Task {
            await search()
        }
    }
    
    private func setImage(ocId: String, cell: CollectionViewCell, indexPath: IndexPath) {
        Task {
            
            let metadata = self.metadatas[indexPath.row]
            
            if FileManager().fileExists(atPath: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                cell.imageView.image = UIImage(contentsOfFile: StoreUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                Self.logger.debug("CELL - image size: \(cell.imageView.image?.size.width ?? -1),\(cell.imageView.image?.size.height ?? -1)")
            } else {
                Self.logger.debug("CELL - downloadThumbnail index path: \(indexPath.row),\(indexPath.item)")
                let result = await NextcloudService.shared.downloadPreview(metadata: metadata)
                //TODO: SAVE THE IMAGE
                cell.imageView.image = result.image
            }
        }
    }
    
    private func search() async {
        
        //TODO: SHOW INDICATOR
        
        guard let activeAccount = DatabaseManager.shared.getActiveAccount() else { return }
        guard let lessDate = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        guard let greaterDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        
        let mediaPath = activeAccount.mediaPath
        let startServerUrl = appDelegate.urlBase + "/remote.php/dav/files/" + appDelegate.userId + mediaPath
        
        Self.logger.debug("search() - lessDate: \(lessDate) greaterDate: \(greaterDate)")
        let result = await NextcloudService.shared.searchMedia(account: self.appDelegate.account, mediaPath: mediaPath, startServerUrl: startServerUrl, lessDate: lessDate, greaterDate: greaterDate)
        
        self.metadatas = result.metadatas
        
        Self.logger.debug("search() - added: \(result.ocIdAdd.count) updated: \(result.ocIdUpdate.count) deleted: \(result.ocIdDelete.count)")
        
        if result.ocIdAdd.count > 0 || result.ocIdUpdate.count > 0 || result.ocIdDelete.count > 0 {
            var snapshot = dataSource.snapshot()
            
            if result.ocIdAdd.count > 0 {
                snapshot.appendItems(result.ocIdAdd, toSection: 1)
            }
            
            if result.ocIdUpdate.count > 0 {
                snapshot.reconfigureItems(result.ocIdUpdate)
            }
            
            if result.ocIdDelete.count > 0 {
                snapshot.deleteItems(result.ocIdDelete)
            }
            
            await dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        //TODO: HIDE INDICATOR
        
        
    }
    
   
}

