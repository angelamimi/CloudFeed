//
//  LoginServerController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//

import UIKit

class LoginServerController: UIViewController {
    
    var coordinator: LoginServerCoordinator!
    
    @IBOutlet weak var serverURLLabel: UILabel!
    @IBOutlet weak var serverURLTextField: UITextField!
    @IBOutlet weak var serverURLButton: UIButton!
    
    @IBAction func buttonClicked(_ sender: Any) {
        processURL()
    }
    
    override func viewDidLoad() {
        serverURLLabel.text = Strings.LoginServerLabel
        serverURLButton.setTitle(Strings.LoginServerButton, for: .normal)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func processURL() {
        guard var url = serverURLTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            coordinator.showInvalidURLPrompt()
            return
        }
        
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        if url.count == 0 {
            coordinator.showInvalidURLPrompt()
            return
        }
        
        // Check whether baseUrl contain protocol. If not add https:// by default.
        if url.hasPrefix("https") == false && url.hasPrefix("http") == false {
            url = "https://" + url
        }
        
        coordinator.navigateToWebLogin(url: url)
    }
}
