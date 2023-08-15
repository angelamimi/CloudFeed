//
//  SettingsController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/18/23.
//
import os.log
import UIKit

class SettingsController: UIViewController, DataViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var dataService: DataService?
    
    private var profileName: String = ""
    private var profileEmail: String = ""
    private var profileImage: UIImage?
    
    private let footerView = FooterView(frame: .zero)
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SettingsController.self)
    )
    
    func setDataService(service: DataService) {
        dataService = service
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        footerView.updateText(text: " ")
        tableView.tableFooterView = footerView
        
        let backgroundColorView = UIView()
        backgroundColorView.backgroundColor = UIColor.secondarySystemBackground
        UITableViewCell.appearance().selectedBackgroundView = backgroundColorView
    }

    override func viewWillAppear(_ animated: Bool) {
        requestProfile()
        requestAvatar()
        
        Task {
            await calculateCacheSize()
        }
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

        Task {
            let result = await dataService?.getUserProfile()
            self.processProfileResult(profileName:result!.profileDisplayName, profileEmail:result!.profileEmail)
        }
    }
    
    private func processProfileResult(profileName: String, profileEmail: String) {
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
    
    private func requestAvatar() {
        
        guard let account = dataService?.getActiveAccount() else { return }
        
        Task {
            await downloadAvatar(account: account)
            loadAvatar(account: account)
        }
    }
    
    private func loadAvatar(account: tableAccount) {

        let userBaseUrl = NextcloudUtility.shared.getUserBaseUrl(account)
        let image = loadUserImage(for: account.userId, userBaseUrl: userBaseUrl)
        
        Self.logger.debug("loadAvatar() - userBaseUrl: \(userBaseUrl)")
        
        self.profileImage = image
        
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: [IndexPath(item: 0, section: 0)], with: .none)
        }
    }
    
    private func loadUserImage(for user: String, userBaseUrl: String) -> UIImage? {
        
        let fileName = userBaseUrl + "-" + user + ".png"
        let localFilePath = String(StoreUtility.getDirectoryUserData()) + "/" + fileName

        if let localImage = UIImage(contentsOfFile: localFilePath) {
            Self.logger.debug("loadUserImage() - \(localImage.size.width),\(localImage.size.height)")
            return createAvatar(image: localImage, size: 150)
        } else if let loadedAvatar = dataService?.getAvatarImage(fileName: fileName) {
            Self.logger.debug("loadUserImage() - loadedAvatar")
            return loadedAvatar
        } else {
            return nil
        }
    }
    
    private func createAvatar(image: UIImage, size: CGFloat) -> UIImage {
        
        var avatarImage = image
        let rect = CGRect(x: 0, y: 0, width: size, height: size)

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 3.0)
        UIBezierPath(roundedRect: rect, cornerRadius: rect.size.height).addClip()
        avatarImage.draw(in: rect)
        avatarImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return avatarImage
    }
    
    private func downloadAvatar(account: tableAccount) async {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        Self.logger.debug("downloadAvatar() - calling downloadAvatar")
        
        await dataService?.downloadAvatar(user: appDelegate.user, account: account)
    }
    
    private func acknowledgements() {
        Self.logger.debug("acknowledgements()")
        navigationController?.pushViewController(AcknowledgementsController(), animated: true)
    }
    
    private func checkReset() {
        let alert = UIAlertController(title: "Reset Application", message: "Are you sure you want to reset? This cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { (_: UIAlertAction!) in
            self.reset()
        }))
        self.present(alert, animated: true)
    }
    
    private func reset() {
        Self.logger.debug("reset()")
        
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
        
        StoreUtility.removeGroupDirectoryProviderStorage()
        
        StoreUtility.removeDocumentsDirectory()
        StoreUtility.removeTemporaryDirectory()
        
        StoreUtility.deleteAllChainStore()
        
        dataService?.removeDatabase()
        
        exit(0)
    }
    
    private func calculateCacheSize() async {
        guard let directory = StoreUtility.getDirectoryProviderStorage() else { return }
        let totalSize = FileSystemUtility.shared.getDirectorySize(directory: directory)
        
        let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .binary)
        Self.logger.debug("calculateCacheSize() - \(formattedSize)")
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.footerView.updateText(text: StoreUtility.transformedSize(totalSize))
        }
    }
    
    private func clearCache() {
        Self.logger.debug("clearCache()")
        
        //startActivityIndicator()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
        
        dataService?.clearDatabase(account: appDelegate.account, removeAccount: false)
        
        StoreUtility.removeGroupDirectoryProviderStorage()
        StoreUtility.removeDirectoryUserData()

        StoreUtility.removeDocumentsDirectory()
        
        //TODO: THIS CAUSES VIDEOS TO NOT PLAY ON LONG CLICK OF COLLECTION VIEW
        //StoreUtility.removeTemporaryDirectory()
        
        HTTPCache.shared.deleteAllCache()
        
        //TODO: Better to send messages instead??
        var nav = self.tabBarController?.viewControllers?[0] as! UINavigationController
        if nav.viewControllers[0] is MainViewController {
            let controller = nav.viewControllers[0] as! MainViewController
            controller.clear()
        }
        
        nav = self.tabBarController?.viewControllers?[1] as! UINavigationController
        if nav.viewControllers[0] is FavoritesController {
            let controller = nav.viewControllers[0] as! FavoritesController
            controller.clear()
        }
        
        Task {
            await calculateCacheSize()
        }
    }
    
    private func showProfileLoadfailedError() {
        let alertController = UIAlertController(title: "Error", message: "Failed to load Profile.", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.navigationController?.popViewController(animated: true)
        }))
        
        self.present(alertController, animated: true)
    }
}

extension SettingsController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.item == 1 {
            acknowledgements()
        } else if indexPath.item == 2 {
            clearCache()
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.item == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath) as! ProfileCell
            
            cell.updateProfileImage(profileImage)
            cell.updateProfile(profileEmail, fullName: profileName)
            
            return cell
            
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
            
            cell.layer.cornerRadius = 20
            cell.layer.masksToBounds = true

            var content = cell.defaultContentConfiguration()
            
            if indexPath.item == 1 {
                content.image = UIImage(systemName: "person.wave.2")
                content.text = "Acknowledgements"
                cell.tintColor = UIColor.label
            } else if indexPath.item == 2 {
                content.image = UIImage(systemName: "trash")
                content.text = "Clear Cache"
                cell.tintColor = UIColor.label
            } else if indexPath.item == 3 {
                content.image = UIImage(systemName: "xmark.octagon")
                content.text = "Reset Application"
                cell.tintColor = UIColor.red
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
