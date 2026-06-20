//
//  CommentsController.swift
//  Commentz
//
//  Created by Angela Jarosz on 6/7/26.
//  Copyright © 2026 Angela Jarosz. All rights reserved.
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

class CommentsController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var commentTextField: UITextField!
    @IBOutlet weak var addCommentStackView: UIStackView!
    @IBOutlet weak var noCommentsStackView: UIStackView!
    @IBOutlet weak var noCommentsStackViewCenterYConstraint: NSLayoutConstraint!
    @IBOutlet weak var noCommentsLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityIndicatorCenterYConstraint: NSLayoutConstraint!
    @IBOutlet weak var errorStackView: UIStackView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var bottomStackViewBottomConstraint: NSLayoutConstraint!
    
    var editCommentId: String?
    var metadata: Metadata?
    var viewModel: CommentsViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cancelButton.isHidden = true
        cancelButton.configuration?.title = Strings.CancelAction
        cancelButton.addTarget(self, action: #selector(endEdit), for: .touchUpInside)
        
        titleLabel.text = Strings.CommentsTitle
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        
        initTextField()
        
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.layer.masksToBounds = true
        
        noCommentsLabel.text = Strings.CommentsEmpty
        noCommentsStackView.isHidden = true
        tableView.isHidden = true
        activityIndicator.isHidden = false
        
        errorStackView.isHidden = true
        errorStackView.isUserInteractionEnabled = true
        let errorTapGesture = UITapGestureRecognizer(target: self, action: #selector(errorStackViewTapped))
        errorStackView.addGestureRecognizer(errorTapGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        viewModel?.initDatasource(tableView)
        
        loadComments()
        loadAvatar()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func close() {
        dismiss(animated: true)
    }
    
    @objc func endEdit() {
        editCommentId = nil
        commentTextField.text = ""
        cancelButton.isHidden = true
        errorStackView.isHidden = true
        resignFirstResponder()
    }
    
    @objc private func limitText() {
        if let text = commentTextField.text, text.count > 1_000 {
            commentTextField.text = String(text.prefix(1_000))
        }
    }
    
    @objc private func errorStackViewTapped() {
        errorStackView.isHidden = true
    }
    
    private func loadComments() {
        Task { [weak self] in
            await self?.viewModel?.loadComments()
        }
    }
    
    private func addComment(_ commentText: String?) {
        Task { [weak self] in
            await self?.viewModel?.addComment(commentText: commentText)
        }
    }
    
    private func updateComment(_ commentId: String, _ commentText: String?) {
        Task { [weak self] in
            await self?.viewModel?.updateComment(commentId: commentId, commentText: commentText)
        }
    }
    
    private func loadAvatar() {
        if let userAccount = Environment.current.currentUser,
           let server = Environment.current.currentServer,
           let image = viewModel?.loadCommenterAvatar(userId: userAccount.userId, urlBase: server.urlBase, account: userAccount.account, delegate: self) {
            profileImageView.image = image
        }
    }
    
    private func initTextField() {
        commentTextField.placeholder = Strings.CommentsPlaceholder
        commentTextField.delegate = self
        commentTextField.addTarget(self, action: #selector(limitText), for: .editingChanged)
        
        commentTextField.layer.cornerRadius = 16
        commentTextField.layer.borderColor = UIColor.tertiaryLabel.cgColor
        commentTextField.layer.borderWidth = 1
        commentTextField.layer.masksToBounds = true
    }
    
    private func handleCommenterAvaterLoaded() {
        if let userAccount = Environment.current.currentUser,
           let server = Environment.current.currentServer,
           let image = viewModel?.getCommenterAvatar(userId: userAccount.userId, urlBase: server.urlBase) {
            profileImageView.image = image
        }
    }
    
    private func handleCommentAddComplete(error: Bool) {
        
        if error {
            activityIndicator.isHidden = true
            errorLabel.text = Strings.CommentsErrorAdd
            errorStackView.isHidden = false
        } else {
            commentTextField.text = ""
            errorStackView.isHidden = true
        }
    }
    
    private func handleCommentUpdateComplete(error: Bool) {
        
        if error {
            activityIndicator.isHidden = true
            errorLabel.text = Strings.CommentsErrorUpdate
            errorStackView.isHidden = false
        } else {
            errorStackView.isHidden = true
        }
    }
    
    private func handleCommentDeleteComplete(error: Bool) {
        
        if error {
            activityIndicator.isHidden = true
            errorLabel.text = Strings.CommentsErrorDelete
            errorStackView.isHidden = false
        } else {
            errorStackView.isHidden = true
        }
    }
    
    private func handleCommentDeleteBegin() {
        startActivityIndicator()
    }
    
    private func handleCommentEditBegin(commentId: String) {
        commentTextField.text = viewModel?.getCommentById(commentId)
        commentTextField.becomeFirstResponder()
        editCommentId = commentId
        cancelButton.isHidden = false
        errorStackView.isHidden = true
    }
    
    private func handleCommentLoad(_ count: Int?) {
        
        activityIndicator.isHidden = true
        
        if count == nil {
            tableView.isHidden = true
            noCommentsStackView.isHidden = true
            errorStackView.isHidden = false
            errorLabel.text = Strings.CommentsErrorLoad
        } else if count == 0 {
            tableView.isHidden = true
            titleLabel.text = "\(Strings.CommentsTitle)(0)"
            noCommentsStackView.isHidden = false
        } else {
            tableView.isHidden = false
            noCommentsStackView.isHidden = true
            commentTextField.text = ""
            
            if editCommentId == nil {
                tableView.scrollToRow(at: .init(item: 0, section: 0), at: .top, animated: true)
            } else {
                editCommentId = nil
                errorStackView.isHidden = true
                cancelButton.isHidden = true
            }
            
            titleLabel.text = "\(Strings.CommentsTitle)(\(count!))"
        }
    }
    
    @objc private func dismissKeyboard() {
        commentTextField.resignFirstResponder()
    }
    
    @objc private func keyboardWillShow(notification: Notification) {
        
        guard bottomStackViewBottomConstraint.constant == 0 else { return }

        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
           let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber {
            
            let offset = -(keyboardFrame.height / 2)
            
            noCommentsStackViewCenterYConstraint.constant = offset
            activityIndicatorCenterYConstraint.constant = offset
            bottomStackViewBottomConstraint.constant = keyboardFrame.height
                
            let options = UIView.AnimationOptions(rawValue: animationCurve.uintValue)
            
            UIView.animate(withDuration: TimeInterval(animationDuration.doubleValue), delay: 0, options: options,
                           animations: { [weak self] in self?.view.layoutIfNeeded() })
        }
    }

    @objc private func keyboardWillBeHidden(notification: Notification) {
        
        guard bottomStackViewBottomConstraint.constant != 0 else { return }
        
        if let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
           let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber {

            noCommentsStackViewCenterYConstraint.constant = 0
            activityIndicatorCenterYConstraint.constant = 0
            bottomStackViewBottomConstraint.constant = 0
            
            let options = UIView.AnimationOptions(rawValue: animationCurve.uintValue)
            
            UIView.animate(withDuration: TimeInterval(animationDuration.doubleValue), delay: 0, options: options) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        }
    }
    
    private func startActivityIndicator() {
        noCommentsStackView.isHidden = true
        activityIndicator.isHidden = false
    }
}

extension CommentsController: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if errorStackView.isHidden == false {
            errorStackView.isHidden = true
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else { return false }
        
        if let commentId = editCommentId {
            startActivityIndicator()
            updateComment(commentId, textField.text)
        } else {
            startActivityIndicator()
            addComment(textField.text)
        }
        
        errorStackView.isHidden = true
                
        return true
    }
}

extension CommentsController: CommentsDelegate {
    
    func loadComplete(count: Int?) {
        handleCommentLoad(count)
    }
    
    func editComment(commentId: String) {
        handleCommentEditBegin(commentId: commentId)
    }
    
    func addComplete(error: Bool) {
        handleCommentAddComplete(error: error)
    }
    
    func updateComplete(error: Bool) {
        handleCommentUpdateComplete(error: error)
    }
    
    func deleteBegin() {
        handleCommentDeleteBegin()
    }
    
    func deleteComplete(error: Bool) {
        handleCommentDeleteComplete(error: error)
    }
}

extension CommentsController: DownloadAvatarOperationDelegate {
    
    func avatarDownloaded(id: String) {
        handleCommenterAvaterLoaded()
    }
}
