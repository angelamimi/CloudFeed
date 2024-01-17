//
//  FlowLayout.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 12/14/23.
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
