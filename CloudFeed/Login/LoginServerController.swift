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
    @IBOutlet weak var underlineView: UIView!
    @IBOutlet weak var serverURLButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var centerConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerStackView: UIStackView!
    @IBOutlet weak var contentStackView: UIStackView!

    @IBAction func doneEditing(_ sender: Any) {
        processURL()
    }

    @IBAction func buttonClicked(_ sender: Any) {
        processURL()
    }

    @IBAction func closeButtonClicked(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func viewTap(_ gestureRecognizer: UITapGestureRecognizer) {
        dismissKeyboard()
    }

    var viewModel: LoginServerViewModel!

    private var logoHidden: Bool!
    private var isTransitioning: Bool = false
    private var allowTransition: Bool = UIDevice.current.userInterfaceIdiom == .pad //allow shifting during rotation if full height of keyboard is known

    override func viewDidLoad() {
        super.viewDidLoad()

        serverURLLabel.text = Strings.LoginServerLabel
        serverURLButton.configuration?.title = Strings.LoginServerButton

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] notification in
            self?.keyboardWillShow(notification: notification)
        }

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] notification in
            self?.keyboardWillHide(notification: notification)
        }

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] notification in
            self?.keyboardWillChangeFrame(notification: notification)
        }

        logoHidden = parent != nil && parent?.isBeingPresented == true

        if logoHidden {
            serverURLLabel.textColor = .label
            logoImageView.isHidden = true
            closeButton.isHidden = false
            view.backgroundColor = .systemBackground
        }

        serverURLTextField.attributedPlaceholder = NSAttributedString(string: Strings.LoginServerPlaceholder, attributes: [.foregroundColor: logoHidden ? UIColor.lightGray.withAlphaComponent(0.5) : UIColor.darkGray])
        serverURLTextField.textColor = logoHidden ? .label : .white
        underlineView.backgroundColor = logoHidden ? .label : .white
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        isTransitioning = true
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.isTransitioning = false
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }

    nonisolated private func keyboardWillShow(notification: Notification) {

        if let screen = notification.object as? UIScreen,
           let beginKeyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue,
           let endKeyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
           let animationDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
           let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {

            Task { @MainActor [weak self] in
                guard self?.isTransitioning == false else { return }
                self?.handleKeyboardWillShow(screen: screen, beginKeyboardFrame: beginKeyboardFrame, endKeyboardFrame: endKeyboardFrame, animationDuration: animationDuration, animationCurve: animationCurve)
            }
        }
    }

    nonisolated private func keyboardWillChangeFrame(notification: Notification) {

        if let screen = notification.object as? UIScreen,
           let beginKeyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue,
           let endKeyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
           let animationDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
           let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {

            Task { @MainActor [weak self] in
                self?.handleKeyboardWillChangeFrame(screen: screen, beginKeyboardFrame: beginKeyboardFrame, endKeyboardFrame: endKeyboardFrame, animationDuration: animationDuration, animationCurve: animationCurve)
            }
        }
    }

    nonisolated private func keyboardWillHide(notification: Notification) {

        if let screen = notification.object as? UIScreen,
           let beginKeyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue,
           let endKeyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
           let animationDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
           let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {

            Task { @MainActor [weak self] in
                guard self?.isTransitioning == false else { return }
                self?.handleKeyboardWillHide(screen: screen, beginKeyboardFrame: beginKeyboardFrame, endKeyboardFrame: endKeyboardFrame, animationDuration: animationDuration, animationCurve: animationCurve)
            }
        }
    }

    private func dismissKeyboard() {
        serverURLTextField.resignFirstResponder()
    }

    private func handleKeyboardWillShow(screen: UIScreen, beginKeyboardFrame: CGRect, endKeyboardFrame: CGRect, animationDuration: Double, animationCurve: UInt) {

        let convertedEndKeyboardFrame = screen.coordinateSpace.convert(endKeyboardFrame, to: view)
        let contentBottom = containerStackView.frame.maxY
        let current = centerConstraint.constant
        let keyboardTop = convertedEndKeyboardFrame.minY

        if contentBottom > keyboardTop {

            let shift = contentBottom - keyboardTop
            let options = UIView.AnimationOptions(rawValue: animationCurve << 16)

            centerConstraint.constant = current - shift

            UIView.animate(withDuration: TimeInterval(animationDuration), delay: .zero, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: options) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        }
    }

    private func handleKeyboardWillChangeFrame(screen: UIScreen, beginKeyboardFrame: CGRect, endKeyboardFrame: CGRect, animationDuration: Double, animationCurve: UInt) {

        let convertedEndKeyboardFrame = screen.coordinateSpace.convert(endKeyboardFrame, to: view)
        let contentBottom = containerStackView.frame.maxY
        let keyboardTop = convertedEndKeyboardFrame.minY
        let current = centerConstraint.constant
        let shift = contentBottom - keyboardTop

        if isTransitioning && !allowTransition {
            return
        } else if current == 0 && shift < 0 {
            return //content not covered and at correct position
        } else if convertedEndKeyboardFrame.height == 0 {
            return
        }

        if allowTransition && isTransitioning {
            let rotatingKeyboardTop = screen.bounds.height - convertedEndKeyboardFrame.height
            let rotatingShift = contentBottom - rotatingKeyboardTop
            let new = current - rotatingShift //predicting where keyboard will be after rotate based on screen height and keyboard height
            centerConstraint.constant = new >= 0 ? 0 : new //prevent shifting past center
        } else if current < 0 && shift < 0 {
            let new = current - shift
            centerConstraint.constant = new >= 0 ? 0 : new //prevent shifting past center
        } else {
            centerConstraint.constant = current - shift
        }

        let options = UIView.AnimationOptions(rawValue: animationCurve << 16)
        let duration = animationDuration == 0 ? 0.2 : animationDuration

        UIView.animate(withDuration: TimeInterval(duration), delay: .zero, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: options) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }

    private func handleKeyboardWillHide(screen: UIScreen, beginKeyboardFrame: CGRect, endKeyboardFrame: CGRect, animationDuration: Double, animationCurve: UInt) {

        let convertedBeginKeyboardFrame = screen.coordinateSpace.convert(beginKeyboardFrame, to: view)
        let convertedEndKeyboardFrame = screen.coordinateSpace.convert(endKeyboardFrame, to: view)

        if convertedEndKeyboardFrame.height != convertedBeginKeyboardFrame.height {
            return //keyboard is still transitioning. sometimes called after rotate. return
        }

        centerConstraint.constant = 0

        let options = UIView.AnimationOptions(rawValue: animationCurve << 16)

        UIView.animate(withDuration: TimeInterval(animationDuration == 0 ? 0.2 : animationDuration), delay: .zero, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: options) { [weak self] in
            self?.view.layoutIfNeeded()
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
                    self?.viewModel.navigateToWebLogin(token: result.token, endpoint: result.endpoint, login: result.login, url: url)
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
