//
//  CollectionViewLayout.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/18/23.
//

import UIKit
import os.log

class CollectionViewLayout: UICollectionViewFlowLayout {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CollectionViewLayout.self)
    )
    
    override init() {
        super.init()
        
        Self.logger.debug("init() - collectionView bounds: \(self.collectionView?.bounds.size.width ?? 0),\(self.collectionView?.bounds.size.height ?? 0)")
        
        let screenWidth = UIScreen.main.bounds.width
        let widthHeightConstant = UIScreen.main.bounds.width / 2.2
        
        self.itemSize = CGSize(width: widthHeightConstant, height: widthHeightConstant)
        
        let numberOfCellsInRow = floor(screenWidth / widthHeightConstant)
        let inset = (screenWidth - (numberOfCellsInRow * widthHeightConstant)) / (numberOfCellsInRow + 1)
        
        self.sectionInset = .init(top: inset, left: inset, bottom: inset, right: inset)
        self.minimumInteritemSpacing = inset
        self.minimumLineSpacing = inset
        self.scrollDirection = .vertical
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    override func prepare() {
        super.prepare()
        
        //Self.logger.debug("prepare() - screen bounds: \(UIScreen.main.bounds.width),\(UIScreen.main.bounds.height) collectionView bounds: \(self.collectionView?.bounds.size.width ?? 0),\(self.collectionView?.bounds.size.height ?? 0)")
    }
    
    override func prepare(forAnimatedBoundsChange oldBounds: CGRect) {
        super.prepare(forAnimatedBoundsChange: oldBounds)
        
        //Self.logger.debug("prepare.forAnimatedBoundsChange() - oldBounds: \(oldBounds.width),\(oldBounds.height) collectionView bounds: \(self.collectionView?.bounds.size.width ?? 0),\(self.collectionView?.bounds.size.height ?? 0)")
    }
    
    override func finalizeAnimatedBoundsChange() {
        super.finalizeAnimatedBoundsChange()
        //Self.logger.debug("prepare.finalizeAnimatedBoundsChange() - collectionView bounds: \(self.collectionView?.bounds.size.width ?? 0),\(self.collectionView?.bounds.size.height ?? 0)")
    }
    
    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        //Self.logger.debug("prepare.forCollectionViewUpdates()")
    }
    
    override func prepareForTransition(to newLayout: UICollectionViewLayout) {
        super.prepareForTransition(to: newLayout)
        //Self.logger.debug("prepare.prepareForTransition()")
    }
}
