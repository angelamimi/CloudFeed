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
    
    @IBOutlet weak var centerConstraint: NSLayoutConstraint!
    
    @IBAction func doneEditing(_ sender: Any) {
        processURL()
    }
    
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    
    @objc
    private func keyboardWillShow(notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            print("keyboardWillShow() - keyboardFrame: \(keyboardFrame)")
            adjust(keyboardTop: keyboardFrame.origin.y)
        }
    }

    @objc 
    private func keyboardWillBeHidden(notification: Notification) {
        resetPosition()
    }
    
    private func adjust(keyboardTop: CGFloat) {
        
        let padding = 10.0
        let buttonBottom = serverURLButton.frame.origin.y + serverURLButton.frame.height
        
        if buttonBottom + padding >= keyboardTop {
            let diff = (buttonBottom + padding) - keyboardTop
            centerConstraint.constant = centerConstraint.constant - diff
        }
    }
    
    private func resetPosition() {
        if centerConstraint.constant != 50 {
            centerConstraint.constant = 50
        }
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
