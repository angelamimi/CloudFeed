//
//  FlowLayout.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 12/14/23.
//

import UIKit

class FlowLayout: UICollectionViewFlowLayout {
    
    var cellsPerRow: Int {
        didSet {
            invalidateLayout()
        }
    }
    
    init(cellsPerRow: Int) {
        self.cellsPerRow = cellsPerRow
        super.init()
        
        minimumLineSpacing = 1
        minimumInteritemSpacing = 1
        
        scrollDirection = .vertical
        sectionInset = UIEdgeInsets.zero
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepare() {
        super.prepare()
        
        guard let collectionView = collectionView else { return }
        
        let itemWidth = (collectionView.bounds.width / CGFloat(cellsPerRow)) - minimumInteritemSpacing
                          
        itemSize = CGSize(width: itemWidth, height: itemWidth)
    }
}
