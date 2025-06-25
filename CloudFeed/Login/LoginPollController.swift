//
//  LoginPollController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 1/1/25.
//  Copyright © 2025 Angela Jarosz. All rights reserved.
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
final class LoginPollController: UIViewController {
    
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var pollLabel: UILabel!
    
    var coordinator: LoginWebCoordinator!
    var viewModel: LoginViewModel!
    
    var token: String!
    var endpoint: String!
    var login: String!
    
    override func viewDidLoad() {
        
        pollLabel.text = Strings.LoginPoll
        cancelButton.titleLabel?.text = Strings.CancelAction
        retryButton.titleLabel?.text = Strings.RetryAction
        
        retryButton.addTarget(self, action: #selector(retryLogin), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelLogin), for: .touchUpInside)
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.willEnterForegroundNotification()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {

        if let token = self.token, let endpoint = self.endpoint, let login = self.login, let url = URL(string: login) {
            poll(token: token, endpoint: endpoint)
            UIApplication.shared.open(url)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func retryLogin() {
        if let login = self.login, let url = URL(string: login) {
            UIApplication.shared.open(url)
        }
    }
    
    @objc private func cancelLogin() {
        navigationController?.popViewController(animated: true)
    }
    
    private func willEnterForegroundNotification() {
        if let token = self.token, let endpoint = self.endpoint {
            poll(token: token, endpoint: endpoint)
        }
    }
    
    private func poll(token: String, endpoint: String) {
        Task { [weak self] in
            await self?.viewModel.loginPoll(token: token, endpoint: endpoint)
        }
    }
}
