//
//  FilterView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 1/21/24.
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

protocol Filterable: AnyObject {
    func filter(from: Date, to: Date)
    func removeFilter()
}

class FilterView: UIView {
    
    @IBOutlet weak var toLabel: UILabel!
    @IBOutlet weak var fromLabel: UILabel!
    @IBOutlet weak var toPicker: UIDatePicker!
    @IBOutlet weak var fromPicker: UIDatePicker!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var removeFilterButton: UIButton!
    
    weak var filterable: Filterable?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        
        guard let view = loadViewFromNib() else { return }
        view.frame = self.bounds
        
        initFilters()
        
        self.addSubview(view)
    }
    
    func loadViewFromNib() -> UIView? {
        let nib = UINib(nibName: String(describing: FilterView.self), bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
    
    private func initFilters() {
        
        toLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        fromLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        
        toPicker.contentHorizontalAlignment = .right
        fromPicker.contentHorizontalAlignment = .right
        
        filterButton.setTitle(Strings.MediaFilter, for: .normal)
        removeFilterButton.setTitle(Strings.MediaRemoveFilter, for: .normal)
        
        filterButton.addTarget(self, action: #selector(executeFilter), for: .touchUpInside)
        removeFilterButton.addTarget(self, action: #selector(executeRemoveFilter), for: .touchUpInside)
    }
    
    @objc private func executeFilter() {
        filterable?.filter(from: fromPicker.date, to: toPicker.date)
    }
    
    @objc private func executeRemoveFilter() {
        filterable?.removeFilter()
    }
}
