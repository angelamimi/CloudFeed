//
//  LoginServerController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
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

class LoginServerController: UIViewController {
    
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var serverURLLabel: UILabel!
    @IBOutlet weak var serverURLTextField: UITextField!
    @IBOutlet weak var serverURLButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var centerConstraint: NSLayoutConstraint!
    
    @IBAction func doneEditing(_ sender: Any) {
        processURL()
    }
    
    @IBAction func buttonClicked(_ sender: Any) {
        processURL()
    }
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        dismiss(animated: true)
    }

    var viewModel: LoginServerViewModel!
    
    var centerOffset: Double = 0
    
    override func viewDidLoad() {
        
        serverURLLabel.text = Strings.LoginServerLabel
        serverURLButton.setTitle(Strings.LoginServerButton, for: .normal)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        if parent != nil && parent!.isBeingPresented {
            serverURLLabel.textColor = .label
            logoImageView.isHidden = true
            closeButton.isHidden = false
            centerConstraint.constant = -50
            view.backgroundColor = .systemBackground
        }
        
        centerOffset = centerConstraint.constant
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    @objc private func willEnterForeground() {
        serverURLTextField.resignFirstResponder()
    }
    
    @objc private func keyboardWillShow(notification: Notification) {

        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
           let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber {

            let bottom = serverURLButton.frame.maxY + 16
            
            if bottom > keyboardFrame.minY {
                
                let shift = bottom - keyboardFrame.minY
                
                centerConstraint.constant = centerOffset - shift
                
                let options = UIView.AnimationOptions(rawValue: animationCurve.uintValue)
                
                UIView.animate(withDuration: TimeInterval(animationDuration.doubleValue), delay: 0, options: options) { [weak self] in
                    self?.view.layoutIfNeeded()
                }
            }
        }
    }

    @objc private func keyboardWillBeHidden(notification: Notification) {
        
        if let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
           let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber {

            centerConstraint.constant = centerOffset
            
            let options = UIView.AnimationOptions(rawValue: animationCurve.uintValue)
            
            UIView.animate(withDuration: TimeInterval(animationDuration.doubleValue), delay: 0, options: options) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        }
    }
    
    private func processURL() {
        
        guard let url = validateUrl() else { return }
        
        Task { [weak self] in

            if let result = await self?.viewModel.beginLoginFlow(url: url) {
               if !result.supported {
                    self?.viewModel.showUnsupportedVersionErrorPrompt()
                } else if result.errorCode != nil {
                    if result.errorCode == NSURLErrorServerCertificateUntrusted {
                        if let host = URL(string: url)?.host() {
                            self?.viewModel.showUntrustedWarningPrompt(host: host)
                        }
                    } else {
                        self?.viewModel.showServerConnectionErrorPrompt()
                    }
                } else {
                    self?.viewModel.navigateToWebLogin(token: result.token, endpoint: result.endpoint, login: result.login)
                }
            } else {
                self?.viewModel.showServerConnectionErrorPrompt()
            }
        }
    }
    
    private func validateUrl() -> String? {
        
        guard var url = serverURLTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            viewModel.showInvalidURLPrompt()
            return nil
        }
        
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        if url.count == 0 {
            viewModel.showInvalidURLPrompt()
            return nil
        }
        
        // Check whether baseUrl contain protocol. If not add https:// by default.
        if url.hasPrefix("https") == false && url.hasPrefix("http") == false {
            url = "https://" + url
        }
        
        return url
    }
}
