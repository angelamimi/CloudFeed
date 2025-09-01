//
//  CollectionLayout.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/31/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
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
protocol CollectionLayoutDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView, sizeAtIndexPath indexPath: IndexPath) -> CGSize
}

class CollectionLayout: UICollectionViewFlowLayout {
    
    weak var delegate: CollectionLayoutDelegate!
    
    var layoutType: String = "" {
        didSet {
            invalidateLayout()
        }
    }
    
    var numberOfColumns: Int = 3 {
        didSet {
            invalidateLayout()
        }
    }
    
    private var cellPadding: CGFloat = 1
    private var cache = [UICollectionViewLayoutAttributes]()
    private var columnHeights: [[CGFloat]] = []
    private var contentHeight: CGFloat = 0
    
    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else {
            return 0
        }
        return collectionView.bounds.width
    }
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CollectionLayout.self)
    )
    
    override func invalidateLayout() {
        super.invalidateLayout()
        cache.removeAll()
    }
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    override func prepare() {
        
        //Self.logger.debug("prepare() - numberOfColumns: \(self.numberOfColumns) content size: \(self.contentWidth),\(self.contentHeight) collectionView size:\(self.collectionView?.bounds.width ?? 0),\(self.collectionView?.bounds.height ?? 0)")
        
        if !cache.isEmpty {
            cache.removeAll()
        }
        
        guard let collectionView = collectionView else {
            return
        }
        
        columnHeights = (0 ..< 1).map { section in
            let sectionColumnHeights = (0 ..< numberOfColumns).map { CGFloat($0) }
            return sectionColumnHeights
        }
        
        let columnWidth = contentWidth / CGFloat(numberOfColumns)
        var xOffset = [CGFloat]()
        
        for column in 0..<numberOfColumns {
            xOffset.append(CGFloat(column) * columnWidth)
        }
        
        var yOffset = [CGFloat](repeating: 0, count: numberOfColumns)
        
        guard collectionView.numberOfSections > 0 else { return }
        let sectionRowCount = collectionView.numberOfItems(inSection: 0)
        
        columnHeights[0] = [CGFloat](repeating: 0, count: numberOfColumns)
        
        for item in 0..<sectionRowCount {
            
            let indexPath = IndexPath(item: item, section: 0)

            var itemSize: CGSize!
            
            if layoutType == Global.shared.layoutTypeAspectRatio {
                
                itemSize = delegate.collectionView(collectionView, sizeAtIndexPath: indexPath)
                
                if (itemSize.width == 0 || itemSize.height == 0) {
                    itemSize = CGSize(width: 100, height: 100)
                }
                
            } else {
                itemSize = CGSize(width: 100, height: 100)
            }
            
            let cellWidth = columnWidth
            var cellHeight = itemSize.height * cellWidth / itemSize.width
            
            cellHeight = cellPadding * 2 + cellHeight
            
            let column = shortestColumnIndex(inSection: 0)
            let frame = CGRect(x: xOffset[column], y: yOffset[column], width: cellWidth, height: cellHeight)
            
            var edgeInsets: UIEdgeInsets
            
            if column == 0 {
               edgeInsets = UIEdgeInsets(top: 0, left: cellPadding, bottom: cellPadding, right: cellPadding)
            } else {
                if item == 0 {
                    edgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: cellPadding)
                } else {
                    edgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: cellPadding, right: cellPadding)
                }
            }
            
            let insetFrame = frame.inset(by: edgeInsets)
            
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = insetFrame
            cache.append(attributes)
            
            //contentHeight = max(contentHeight, frame.maxY)
            //contentHeight = frame.maxY
            yOffset[column] = yOffset[column] + cellHeight
          
            //section 0
            columnHeights[0][column] = attributes.frame.maxY + cellPadding
            
            let maxFromColumnHeights = columnHeights[0].max()
            contentHeight = maxFromColumnHeights ?? 0
            
            //Self.logger.debug("prepare() - column: \(column) maxFromColumnHeights: \(maxFromColumnHeights ?? 0) contentHeight: \(self.contentHeight) cell height: \(self.columnHeights[0][column]) cellWidth:\(cellWidth)")
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var visibleLayoutAttributes = [UICollectionViewLayoutAttributes]()
        
        for attributes in cache {
            if attributes.frame.intersects(rect) {
                visibleLayoutAttributes.append(attributes)
            }
        }
        
        return visibleLayoutAttributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        //Self.logger.debug("layoutAttributesForItem() - cache count: \(self.cache.count) indexPath: \(indexPath.item)")
        return cache[indexPath.item]
    }
    
    private func shortestColumnIndex(inSection section: Int) -> Int {
        return columnHeights[section].enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return !newBounds.size.equalTo(collectionView.bounds.size)
    }
}


