//
//  LoginServerController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//

import UIKit

class LoginServerController: UIViewController {
    
    @IBOutlet weak var serverURLTextField: UITextField!
    @IBOutlet weak var serverURLButton: UIButton!
    
    @IBAction func buttonClicked(_ sender: Any) {
        processURL()
    }
    
    let dataService : DataService
    
    @available(*, unavailable, renamed: "init(dataService:coder:)")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not implemented")
    }
    
    init?(dataService: DataService, coder: NSCoder) {
        self.dataService = dataService
        super.init(coder: coder)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func processURL() {
        guard var url = serverURLTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        if url.count == 0 { return }
        
        // Check whether baseUrl contain protocol. If not add https:// by default.
        if url.hasPrefix("https") == false && url.hasPrefix("http") == false {
            url = "https://" + url
        }
        
        let loginController = UIStoryboard(name: "Login", bundle: nil).instantiateViewController(
            identifier: "LoginWebController",
            creator: { coder in
                LoginWebController(dataService: self.dataService, coder: coder)
            }
        )
        loginController.setURL(url: url)
        self.navigationController?.pushViewController(loginController, animated: true)
    }
    
    private func showInvalidURLPrompt() {
        let alertController = UIAlertController(title: "Error", message: "Failed to load URL. Please try again.", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.navigationController?.popViewController(animated: true)
        }))
        
        self.present(alertController, animated: true)
    }
    
}
