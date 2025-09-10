//
//  FilterController.swift
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

@MainActor
protocol Filterable: AnyObject {
    func filter(from: Date, to: Date)
    func removeFilter()
}

class FilterController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var dateSectionLabel: UILabel!
    @IBOutlet weak var presetsSectionLabel: UILabel!
    @IBOutlet weak var toLabel: UILabel!
    @IBOutlet weak var fromLabel: UILabel!
    @IBOutlet weak var fromDatePicker: UIDatePicker!
    @IBOutlet weak var toDatePicker: UIDatePicker!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var removeFilterButton: UIButton!
    
    weak var filterable: Filterable?
    
    private var presetsDataSource: UICollectionViewDiffableDataSource<Int, Int>!
    
    private var yearsData: [Int] = []
    
    private var selectedYear: Int = -1
    private var selectedMonths: [Int] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        filterButton.setTitle(Strings.MediaFilter, for: .normal)
        removeFilterButton.setTitle(Strings.MediaRemoveFilter, for: .normal)
        
        dateSectionLabel.text = Strings.MediaFilterSectionDates
        presetsSectionLabel.text = Strings.MediaFilterSectionPresets
        
        toLabel.text = Strings.FilterLabelDateTo
        fromLabel.text = Strings.FilterLabelDateFrom
        
        filterButton.addTarget(self, action: #selector(executeFilter), for: .touchUpInside)
        removeFilterButton.addTarget(self, action: #selector(executeRemoveFilter), for: .touchUpInside)
        
        initDataSource()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        DispatchQueue.main.async { [weak self] in
            if let height = self?.actionStackView.frame.height {
                self?.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height + 16, right: 0)
            }
        }
    }
    
    func setFilterable(filterable: Filterable) {
        self.filterable = filterable
    }
    
    func initDateFilter(from: Date?, to: Date?) {
        if from != nil && to != nil {
            fromDatePicker.date = from!
            toDatePicker.date = to!
        } else {
            fromDatePicker.date = Date()
            toDatePicker.date = Date()
        }
    }
    
    @objc private func executeFilter() {
        
        let calender = Calendar.current
        let fromComponents = calender.dateComponents([.year, .month, .day], from: fromDatePicker.date)
        var toComponents = calender.dateComponents([.year, .month, .day], from: toDatePicker.date)
        
        toComponents.hour = 23
        toComponents.minute = 59
        toComponents.second = 59

        filterable?.filter(from: calender.date(from: fromComponents)!, to: calender.date(from: toComponents)!)
    }
    
    @objc private func executeRemoveFilter() {
        filterable?.removeFilter()
    }

    private func initDataSource() {

        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            return self?.buildHorizontalSection()
        }
        
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        config.interSectionSpacing = 8

        layout.configuration = config

        collectionView.collectionViewLayout = layout
        
        presetsDataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: collectionView) { [weak self] (collectionView: UICollectionView, indexPath: IndexPath, identifier: Int) -> UICollectionViewCell? in
            if indexPath.section == 0 {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterYearCell", for: indexPath) as? FilterYearCell else { fatalError("Cannot create new cell") }
                self?.populateCell(year: identifier, cell: cell)
                return cell
            } else {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterMonthCell", for: indexPath) as? FilterMonthCell else { fatalError("Cannot create new cell") }
                self?.populateCell(month: identifier, cell: cell)
                return cell
            }
        }
        
        var snapshot = presetsDataSource.snapshot()
        snapshot.appendSections([0, 1])
        
        initData()
        
        snapshot.appendItems(yearsData, toSection: 0)
        
        let monthInexes = 0...11
        snapshot.appendItems(monthInexes.sorted(), toSection: 1)
        
        presetsDataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func initData() {
        let years = 1940...Calendar.current.component(.year, from: .now)
        yearsData = years.reversed()
    }
    
    private func buildHorizontalSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(1), heightDimension: .estimated(40))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: itemSize.widthDimension, heightDimension: itemSize.heightDimension)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        
        section.contentInsetsReference = .none
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.interGroupSpacing = 8.0

        return section
    }
    
    private func populateCell(year: Int, cell: FilterYearCell) {
        cell.yearButton.tag = year
        cell.yearButton.addTarget(self, action: #selector(yearButtonTouched(_:)), for: .touchUpInside)
        
        let selected = year == selectedYear
        setButtonSelected(selected, cell.yearButton)
        
        cell.setYear(year)
    }
    
    private func populateCell(month: Int, cell: FilterMonthCell) {
        cell.monthButton.tag = month
        cell.monthButton.addTarget(self, action: #selector(monthButtonTouched(_:)), for: .touchUpInside)
        
        let selected = selectedMonths.contains(month)
        setButtonSelected(selected, cell.monthButton)
        
        if month >= 0 && month <= 11 {
            cell.setMonth(index: month, Calendar.current.monthSymbols[month])
        }
    }
    
    @objc func yearButtonTouched(_ sender: UIButton) {
        
        if sender.isSelected {
            selectedYear = -1
            setButtonSelected(false, sender)
        } else {
            //deselect old year
            let snapshot = presetsDataSource.snapshot()
            if let index = snapshot.indexOfItem(selectedYear) {
                if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? FilterYearCell {
                    setButtonSelected(false, cell.yearButton)
                }
            }
            //select and set new year
            setButtonSelected(true, sender)
            selectedYear = sender.tag
        }
        
        setDateRange()
    }
    
    @objc func monthButtonTouched(_ sender: UIButton) {

        if sender.isSelected {
            
            let month = sender.tag
            let sorted = selectedMonths.sorted()

            if sorted.first == month || sorted.last == month {
                selectedMonths.remove(at: selectedMonths.firstIndex(of: month)!)
                setButtonSelected(false, sender)
            } else {
                
                //deselect anything after the newly deselected month
                for selectedMonth in sorted {
                    if selectedMonth > month {
                        selectedMonths.remove(at: selectedMonths.firstIndex(of: selectedMonth)!)
                    }
                }
                
                //reflect changes
                let refreshItems = collectionView.indexPathsForVisibleItems
                let items = refreshItems.compactMap { presetsDataSource.itemIdentifier(for: $0) }
                var snapshot = presetsDataSource.snapshot()
                
                snapshot.reconfigureItems(items)
                presetsDataSource.apply(snapshot)
            }
            
            setDateRange()
            
        } else {
            setButtonSelected(true, sender)
            selectedMonths.append(sender.tag)
            setMonthRange()
            setDateRange()
        }
    }
    
    private func setDateRange() {
        
        if selectedMonths.count == 0 {
            if selectedYear == -1 {
                //nothing selected. set default of today
                fromDatePicker.date = .now
                toDatePicker.date = .now
            } else {
                
                var fromComponents = DateComponents()
                fromComponents.year = selectedYear
                fromComponents.month = 1
                fromComponents.day = 1

                let calendar = Calendar(identifier: .gregorian)
                if let from = calendar.date(from: fromComponents) {
                    fromDatePicker.date = from
                }
                
                var toComponents = DateComponents()
                toComponents.year = selectedYear
                toComponents.month = 12
                toComponents.day = 31

                if let to = calendar.date(from: toComponents) {
                    toDatePicker.date = to
                }
            }
        } else {
            
            var fromYear: Int
            var toYear: Int
            
            if selectedYear == -1 {
                fromYear = Calendar.current.component(.year, from: fromDatePicker.date)
                toYear = Calendar.current.component(.year, from: fromDatePicker.date)
            } else {
                fromYear = selectedYear
                toYear = selectedYear
            }
            
            let sortedMonths = selectedMonths.sorted()
            let firstMonth = sortedMonths.first == nil ? 1 : sortedMonths.first! + 1
            let lastMonth = sortedMonths.last == nil ? 1 : sortedMonths.last! + 1
            
            var fromComponents = DateComponents()
            fromComponents.year = fromYear
            fromComponents.month = firstMonth
            fromComponents.day = 1

            let calendar = Calendar(identifier: .gregorian)
            if let from = calendar.date(from: fromComponents) {
                fromDatePicker.date = from
            }
            
            //get last day of month
            var startComponents = DateComponents()
            startComponents.year = toYear
            startComponents.month = lastMonth
            startComponents.day = 1
            
            var lastDatComponents = DateComponents()
            lastDatComponents.month = 1
            lastDatComponents.day = -1
            
            if let start = calendar.date(from: startComponents),
               let endOfMonth = calendar.date(byAdding: lastDatComponents, to: start) {
                toDatePicker.date = endOfMonth
            }
        }
    }
    
    private func setMonthRange() {
        
        if selectedMonths.count > 1 {
            
            let sorted = selectedMonths.sorted()
            
            if let first = sorted.first, let last = sorted.last {

                for month in first...last {
                    
                    if let cell = collectionView.cellForItem(at: IndexPath(item: month, section: 1)) as? FilterMonthCell {
                        setButtonSelected(true, cell.monthButton)
                    }
                    
                    if !selectedMonths.contains(month) {
                        selectedMonths.append(month)
                    }
                }
            }
        }
    }
    
    private func setButtonSelected(_ selected: Bool, _ button: UIButton) {
        if selected {
            button.tintColor = .tintColor
            button.isSelected = true
            button.layer.cornerRadius = 8.0
            button.layer.borderWidth = 2.0
            button.layer.borderColor = UIColor.tintColor.cgColor
        } else {
            button.tintColor = .label
            button.isSelected = false
            button.layer.cornerRadius = 8.0
            button.layer.borderWidth = 0
        }
    }
}
