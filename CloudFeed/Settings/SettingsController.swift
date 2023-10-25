//
//  SettingsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/18/23.
//
import os.log
import UIKit

class SettingsController: UIViewController {
    
    var coordinator: SettingsCoordinator!
    var viewModel: SettingsViewModel!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var profileName: String = ""
    private var profileEmail: String = ""
    private var profileImage: UIImage?
    
    private let footerView = FooterView(frame: .zero)
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SettingsController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        footerView.updateText(text: " ")
        tableView.tableFooterView = footerView
        
        let backgroundColorView = UIView()
        backgroundColorView.backgroundColor = UIColor.tertiarySystemBackground
        UITableViewCell.appearance().selectedBackgroundView = backgroundColorView
    }

    override func viewWillAppear(_ animated: Bool) {
        requestProfile()
        requestAvatar()
        calculateCacheSize()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        Self.logger.debug("viewWillLayoutSubviews() - updating footer view height")
        updateViewHeight(for: tableView.tableFooterView)
    }

    private func updateViewHeight(for footerView: UIView?) {
        guard let footerView = footerView else { return }
        footerView.frame.size.height = footerView.systemLayoutSizeFitting(CGSize(width: view.bounds.width - 32.0, height: 0)).height
    }

    private func startActivityIndicator() {
        activityIndicator.startAnimating()
        self.view.isUserInteractionEnabled = false
    }
    
    private func stopActivityIndicator() {
        activityIndicator.stopAnimating()
        self.view.isUserInteractionEnabled = true
    }
    
    private func requestProfile() {
        startActivityIndicator()
        viewModel.requestProfile()
    }
    
    private func requestAvatar() {
        viewModel.requestAvatar()
    }
    
    private func acknowledgements() {
        coordinator.showAcknowledgements()
    }
    
    private func checkReset() {
        coordinator.checkReset { [weak self] in
            self?.reset()
        }
    }
    
    private func reset() {
        viewModel.reset()
    }
    
    private func calculateCacheSize() {
        viewModel.calculateCacheSize()
    }
    
    private func showProfileLoadfailedError() {
        coordinator.showProfileLoadfailedError()
    }
}

extension SettingsController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.item == 1 {
            acknowledgements()
        } else if indexPath.item == 2 {
            startActivityIndicator()
            viewModel.clearCache()
        } else if indexPath.item == 3 {
            checkReset()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.item == 0 {
            return 320
        } else {
            return 60
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let verticalPadding: CGFloat = 8
        let maskLayer = CALayer()
        
        maskLayer.cornerRadius = 16
        maskLayer.backgroundColor = UIColor.black.cgColor
        maskLayer.frame = CGRect(x: cell.bounds.origin.x, y: cell.bounds.origin.y, width: cell.bounds.width, height: cell.bounds.height).insetBy(dx: 0, dy: verticalPadding/2)
        
        cell.layer.mask = maskLayer
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.item == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath) as! ProfileCell
            
            cell.updateProfileImage(profileImage)
            cell.updateProfile(profileEmail, fullName: profileName)
            
            return cell
            
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)

            var content = cell.defaultContentConfiguration()
            
            content.textProperties.font = UIFont.systemFont(ofSize: 18)
            
            if indexPath.item == 1 {
                content.image = UIImage(systemName: "person.wave.2")
                content.text = "Acknowledgements"
                cell.tintColor = UIColor.label
                cell.backgroundColor = UIColor.secondarySystemBackground
                cell.accessoryType = .disclosureIndicator
            } else if indexPath.item == 2 {
                content.image = UIImage(systemName: "trash")
                content.text = "Clear Cache"
                cell.tintColor = UIColor.label
                cell.backgroundColor = UIColor.secondarySystemBackground
                cell.accessoryType = .none
            } else if indexPath.item == 3 {
                content.image = UIImage(systemName: "xmark.octagon")
                content.text = "Reset Application"
                cell.tintColor = UIColor.red
                cell.backgroundColor = UIColor.secondarySystemBackground
                cell.accessoryType = .none
            }
            
            cell.contentConfiguration = content
            
            return cell
        }
    }
}

class FooterView: UIView {

    let label = UILabel(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16.0),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 50.0),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .right
    }

    func updateText(text: String) {
        label.text = "Cache size: \(text)"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SettingsController: SettingsDelegate {
    
    func avatarLoaded(image: UIImage?) {
        self.profileImage = image
        
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .none)
        }
    }
    
    func cacheCleared() {
        coordinator.cacheCleared()
        calculateCacheSize()
        
        DispatchQueue.main.async {
            self.stopActivityIndicator()
        }
    }
    
    func cacheCalculated(cacheSize: Int64) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.footerView.updateText(text: StoreUtility.transformedSize(cacheSize))
        }
    }
    
    func profileResultReceived(profileName: String, profileEmail: String) {
        
        self.profileName = profileName
        self.profileEmail = profileEmail
        
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .none)
            self.stopActivityIndicator()
            
            if profileName == "" && profileEmail == "" {
                self.showProfileLoadfailedError()
            }
        }
    }
}
