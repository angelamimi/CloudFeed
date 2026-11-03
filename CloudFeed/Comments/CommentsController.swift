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
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var commentTextField: UITextField!
    @IBOutlet weak var addCommentStackView: UIStackView!
    @IBOutlet weak var noCommentsStackView: UIStackView!
    @IBOutlet weak var noCommentsStackViewCenterYConstraint: NSLayoutConstraint!
    @IBOutlet weak var noCommentsImageView: UIImageView!
    @IBOutlet weak var noCommentsLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityIndicatorCenterYConstraint: NSLayoutConstraint!
    @IBOutlet weak var errorStackView: UIStackView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var bottomStackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomStackView: UIStackView!

    @IBAction func viewTap(_ gestureRecognizer: UITapGestureRecognizer) {
        dismissKeyboard()
    }

    @IBAction func errorViewTap(_ gestureRecognizer: UITapGestureRecognizer) {
        errorStackViewTapped()
    }

    var editCommentId: String?
    var metadata: Metadata?
    var viewModel: CommentsViewModel?

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    private var isTransitioning = false

    override func viewDidLoad() {
        super.viewDidLoad()

        initControls()

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] notification in
            self?.keyboardWillShow(notification: notification)
        }

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] notification in
            self?.keyboardWillChangeFrame(notification: notification)
        }

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] notification in
            self?.keyboardWillHide(notification: notification)
        }

        setNoCommentsViewVisibility()

        viewModel?.initDatasource(tableView)

        viewModel?.loadComments()
        loadAvatar()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        isTransitioning = true

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.noCommentsStackView.isHidden = true
            self?.errorStackView.isHidden = true
        }, completion: { [weak self] _ in
            self?.isTransitioning = false
            self?.handleViewDidTransition()
        })
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func close() {
        dismiss(animated: true)
    }

    func endEdit() {
        editCommentId = nil
        commentTextField.text = ""
        actionStackView.isHidden = true
        errorStackView.isHidden = true
        resignFirstResponder()
    }

    private func initControls() {

        let cancelAction = UIAction { [weak self] _ in self?.endEdit() }
        let closeAction = UIAction { [weak self] _ in self?.close() }
        let submitAction = UIAction { [weak self] _ in self?.submitComment() }

        cancelButton.addAction(cancelAction, for: .touchUpInside)
        closeButton.addAction(closeAction, for: .touchUpInside)
        submitButton.addAction(submitAction, for: .touchUpInside)

        initTextField()

        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.layer.masksToBounds = true

        titleLabel.text = Strings.CommentsTitle
        cancelButton.configuration?.title = Strings.CancelAction

        actionStackView.isHidden = true
        noCommentsLabel.text = Strings.CommentsEmpty
        noCommentsStackView.isHidden = true
        tableView.isHidden = true
        activityIndicator.isHidden = false

        errorStackView.isHidden = true
        errorStackView.isUserInteractionEnabled = true

        submitButton.layer.cornerRadius = submitButton.frame.size.width / 2
        submitButton.layer.masksToBounds = true

        closeButton.configuration?.contentInsets = .zero
    }

    private func limitText() {
        if let text = commentTextField.text, text.count > 1_000 {
            commentTextField.text = String(text.prefix(1_000))
        }
    }

    private func errorStackViewTapped() {
        errorStackView.isHidden = true
    }

    private func addComment(_ commentText: String?) {
        viewModel?.addComment(commentText: commentText)
    }

    private func updateComment(_ commentId: String, _ commentText: String?) {
        viewModel?.updateComment(commentId: commentId, commentText: commentText)
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

        let editAction = UIAction { [weak self] _ in
            self?.limitText()
        }
        commentTextField.addAction(editAction, for: .editingChanged)

        commentTextField.backgroundColor = .systemBackground
        commentTextField.borderStyle = .none
        commentTextField.leftViewMode = .always
        commentTextField.rightViewMode = .always
        commentTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        commentTextField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))

        commentTextField.layer.cornerRadius = 16
        commentTextField.layer.borderColor = UIColor.lightGray.cgColor
        commentTextField.layer.borderWidth = 1
        commentTextField.layer.masksToBounds = true
        commentTextField.layer.cornerCurve = .continuous
    }

    private func handleViewDidTransition() {
        if noCommentsStackView.isHidden == false {
            setNoCommentsViewVisibility()
        }
    }

    private func handleCommenterAvatarLoaded() {
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
            viewModel?.loadComments()
        }
    }

    private func handleCommentUpdateComplete(error: Bool) {

        if error {
            activityIndicator.isHidden = true
            errorLabel.text = Strings.CommentsErrorUpdate
            errorStackView.isHidden = false
        } else {
            errorStackView.isHidden = true
            viewModel?.loadComments()
        }
    }

    private func handleCommentDeleteComplete(error: Bool) {

        if error {
            activityIndicator.isHidden = true
            errorLabel.text = Strings.CommentsErrorDelete
            errorStackView.isHidden = false
        } else {
            errorStackView.isHidden = true
            viewModel?.loadComments()
        }
    }

    private func handleCommentDeleteBegin() {
        startActivityIndicator()
    }

    private func handleCommentEditBegin(commentId: String) {
        commentTextField.text = viewModel?.getCommentById(commentId)
        commentTextField.becomeFirstResponder()
        editCommentId = commentId
        actionStackView.isHidden = false
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
            setNoCommentsViewVisibility()
        } else {
            tableView.isHidden = false
            noCommentsStackView.isHidden = true
            commentTextField.text = ""

            if editCommentId == nil {
                tableView.scrollToRow(at: .init(item: 0, section: 0), at: .top, animated: true)
            } else {
                editCommentId = nil
                errorStackView.isHidden = true
                actionStackView.isHidden = true
            }

            titleLabel.text = "\(Strings.CommentsTitle)(\(count!))"
        }
    }

    private func dismissKeyboard() {
        commentTextField.resignFirstResponder()
    }

    nonisolated private func keyboardWillShow(notification: Notification) {

        if let screen = notification.object as? UIScreen,
           let endKeyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
           let animationDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
           let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {

            Task { @MainActor [weak self] in
                guard self?.isTransitioning == false else { return }
                self?.handleKeyboardWillShow(screen: screen, endKeyboardFrame: endKeyboardFrame, animationDuration: animationDuration, animationCurve: animationCurve)
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

    private func handleKeyboardWillShow(screen: UIScreen, endKeyboardFrame: CGRect, animationDuration: Double, animationCurve: UInt) {

        let convertedEndKeyboardFrame = screen.coordinateSpace.convert(endKeyboardFrame, to: view)
        let overlap = max(0, view.bounds.maxY - convertedEndKeyboardFrame.minY)

        if availableTopSpace() > convertedEndKeyboardFrame.minY {
            return
        }

        if moveConstraints(overlap: overlap) {
            animateLayout(animationDuration: animationDuration, animationCurve: animationCurve)
        } else if tableView.isHidden && noCommentsStackView.isHidden {
            setNoCommentsViewVisibility()
        }
    }

    private func handleKeyboardWillChangeFrame(screen: UIScreen, beginKeyboardFrame: CGRect, endKeyboardFrame: CGRect, animationDuration: Double, animationCurve: UInt) {

        let convertedEndKeyboardFrame = screen.coordinateSpace.convert(endKeyboardFrame, to: view)
        var overlap = max(0, view.bounds.maxY - convertedEndKeyboardFrame.minY)

        if convertedEndKeyboardFrame.height == 0 {
            return
        } else if availableTopSpace() > convertedEndKeyboardFrame.minY {
            if isTransitioning {
                overlap = view.frame.height / 2
            } else {
                return
            }
        }

        if moveConstraints(overlap: overlap) {
            noCommentsStackView.isHidden = true
            animateLayout(animationDuration: animationDuration, animationCurve: animationCurve)
        }
    }

    private func handleKeyboardWillHide(screen: UIScreen, beginKeyboardFrame: CGRect, endKeyboardFrame: CGRect, animationDuration: Double, animationCurve: UInt) {

        let convertedBeginKeyboardFrame = screen.coordinateSpace.convert(beginKeyboardFrame, to: view)
        let convertedEndKeyboardFrame = screen.coordinateSpace.convert(endKeyboardFrame, to: view)

        if convertedEndKeyboardFrame.height != convertedBeginKeyboardFrame.height {
            return //keyboard is still transitioning. sometimes called after rotate. return
        }

        noCommentsStackViewCenterYConstraint.constant = -16
        activityIndicatorCenterYConstraint.constant = -16
        bottomStackViewBottomConstraint.constant = 0

        let options = UIView.AnimationOptions(rawValue: animationCurve << 16)

        UIView.animate(withDuration: TimeInterval(animationDuration == 0 ? 0.2 : animationDuration), delay: .zero, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: options) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }

    private func moveConstraints(overlap: CGFloat) -> Bool {

        let diff = ((getCommentHeight() + 32) - getTitleHeight()) / 2

        if overlap == 0 {
            guard bottomStackViewBottomConstraint.constant != 0 else { return false }
            noCommentsStackViewCenterYConstraint.constant = -16
            activityIndicatorCenterYConstraint.constant = -16
            bottomStackViewBottomConstraint.constant = 0
        } else {
            guard bottomStackViewBottomConstraint.constant != overlap else { return false }
            let offset = -(overlap / 2)
            noCommentsStackViewCenterYConstraint.constant = offset - diff
            activityIndicatorCenterYConstraint.constant = offset - diff
            bottomStackViewBottomConstraint.constant = overlap
        }

        return true
    }

    private func animateLayout(animationDuration: Double, animationCurve: UInt) {

        let options = UIView.AnimationOptions(rawValue: animationCurve << 16)
        let duration = animationDuration == 0 ? 0.2 : animationDuration

        UIView.animate(withDuration: TimeInterval(duration), delay: .zero,
                       usingSpringWithDamping: 1, initialSpringVelocity: 1, options: options,
                       animations: { [weak self] in self?.view.layoutIfNeeded() },
                       completion: { [weak self] _ in self?.setNoCommentsViewVisibility() })
    }

    private func startActivityIndicator() {
        noCommentsStackView.isHidden = true
        activityIndicator.isHidden = false
    }

    private func setNoCommentsViewVisibility(bottomStackViewTop: CGFloat? = nil) {

        guard !isTransitioning else { return }

        let emptyItemsHeight = noCommentsLabel.frame.height + 8 + noCommentsImageView.frame.height
        let noCommentsStackViewIsHidden = tableView.isHidden && errorStackView.isHidden ? false : true
        let availableSpace: CGFloat

        if bottomStackViewTop == nil {
            availableSpace = bottomStackView.frame.minY - titleStackView.frame.maxY
        } else {
            availableSpace = bottomStackViewTop! - titleStackView.frame.maxY
        }

        if availableSpace <= noCommentsLabel.frame.height {
            noCommentsStackView.isHidden = true
        } else if availableSpace <= emptyItemsHeight {
            noCommentsStackView.isHidden = noCommentsStackViewIsHidden
            noCommentsImageView.isHidden = true
        } else {
            noCommentsStackView.isHidden = noCommentsStackViewIsHidden
            noCommentsImageView.isHidden = false
        }
    }

    private func availableTopSpace() -> CGFloat {
        let titleHeight = getTitleHeight()
        let bottomHeight = getCommentHeight()
        let height = titleHeight + bottomHeight
        return height //lose size during transition so can't rely on view heights directly
    }

    private func getTitleHeight() -> CGFloat {
        let lineHeight = titleLabel.font.lineHeight
        let titleHeight = lineHeight + 24 + 16
        return max(titleHeight, titleStackView.frame.height)
    }

    private func getCommentHeight() -> CGFloat {
        if let lineHeight = commentTextField.font?.lineHeight {
            let bottomHeight = max(lineHeight, commentTextField.frame.height)
            return max(bottomHeight, commentTextField.frame.height)
        }
        return commentTextField.frame.height
    }

    private func submitComment() {
        guard let text = commentTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else { return }
        submitComment(text)
    }

    private func submitComment(_ text: String) {

        if let commentId = editCommentId {
            startActivityIndicator()
            updateComment(commentId, text)
        } else {
            startActivityIndicator()
            addComment(text)
        }

        errorStackView.isHidden = true
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

        submitComment(text)

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
        handleCommenterAvatarLoaded()
    }
}
