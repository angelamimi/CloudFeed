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
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.willEnterForegroundNotification()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
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
    
    private func willEnterForegroundNotification() {
        if isViewLoaded && view.window != nil {
            var snapshot = presetsDataSource.snapshot()
            snapshot.reloadSections([0, 1])
            presetsDataSource.apply(snapshot, animatingDifferences: false)
        }
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
        let years = 1900...Calendar.current.component(.year, from: .now)
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
        cell.delegate = self
        
        let selected = year == selectedYear
        cell.setSelected(selected: selected)
        
        cell.setYear(year)
    }
    
    private func populateCell(month: Int, cell: FilterMonthCell) {
        
        cell.monthButton.tag = month
        cell.delegate = self
        
        let selected = selectedMonths.contains(month)
        cell.setSelected(selected: selected)

        if month >= 0 && month <= 11  {
            cell.setMonth(index: month, month: Calendar.current.monthSymbols[month])
        }
    }
    
    private func updateItems(_ indexPaths: [IndexPath]) {
        let items = indexPaths.compactMap { presetsDataSource.itemIdentifier(for: $0) }
        var snapshot = presetsDataSource.snapshot()
        
        snapshot.reconfigureItems(items)
        presetsDataSource.apply(snapshot, animatingDifferences: false)
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
    
    private func setMonthRange() -> [IndexPath] {
        
        var newlySelected: [IndexPath] = []
        
        if selectedMonths.count > 1 {
            
            let sorted = selectedMonths.sorted()
            
            if let first = sorted.first, let last = sorted.last {

                for month in first...last {
                    
                    if !selectedMonths.contains(month) {
                        selectedMonths.append(month)
                        newlySelected.append(IndexPath(item: month, section: 1))
                    }
                }
            }
        }
        
        return newlySelected
    }
}

extension FilterController: YearCellDelegate {
    
    func yearSelected(year: Int, selected: Bool) {
        
        var indexPaths: [IndexPath] = []
        
        if selectedYear != -1 {
            let index = yearsData.firstIndex(of: selectedYear)!
            indexPaths.append(IndexPath(item: index, section: 0))
        }
        
        if year != -1 && year != selectedYear {
            let index = yearsData.firstIndex(of: year)!
            indexPaths.append(IndexPath(item: index, section: 0))
        }
        
        selectedYear = selected ? -1 : year
        
        updateItems(indexPaths)
        setDateRange()
    }
}

extension FilterController: MonthCellDelegate {
    
    func monthSelected(month: Int, selected: Bool) {
        
        var indexPaths: [IndexPath] = []
        
        if selected {
            
            let sorted = selectedMonths.sorted()

            if sorted.first == month || sorted.last == month {
                selectedMonths.remove(at: selectedMonths.firstIndex(of: month)!)
                indexPaths.append(IndexPath(item: month, section: 1))
            } else {
                
                //deselect anything after the newly deselected month
                for selectedMonth in sorted {
                    if selectedMonth > month {
                        let index = selectedMonths.firstIndex(of: selectedMonth)
                        selectedMonths.remove(at: index!)
                        indexPaths.append(IndexPath(item: selectedMonth, section: 1))
                    }
                }
            }
            
            updateItems(indexPaths)
            setDateRange()
            
        } else {

            selectedMonths.append(month)
            indexPaths.append(IndexPath(item: month, section: 1))
            indexPaths.append(contentsOf: setMonthRange())
            setDateRange()
            updateItems(indexPaths)
        }
    }
}
