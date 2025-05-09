//
//  LoginWebController.swift
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

import NextcloudKit
import os.log
import UIKit
import WebKit

class LoginWebController: UIViewController {
    
    @IBOutlet weak var webView: WKWebView!
    
    var viewModel: LoginViewModel!
    
    var token: String!
    var endpoint: String!
    var login: String!

    var timerTask: Task<Void, Error>?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: LoginWebController.self)
    )

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.title = Strings.LoginServerTitle
        
        webView.navigationDelegate = self

        executeLoginFlowRequest()
        beginPolling()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        endPolling()
    }

    private func executeLoginFlowRequest() {
        
        guard let url = URL(string: login) else {
            viewModel.showInvalidURLPrompt()
            return
        }
        
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast, completionHandler: { [weak self] in
            self?.loadRequest(url: url)
        })
    }
    
    private func loadRequest(url: URL) {
        
        let languageCode: String? = NSLocale.preferredLanguages[0]
        
        var request = URLRequest(url: url)
        
        request.setValue(languageCode, forHTTPHeaderField: "ACCEPT-LANGUAGE")
        request.setValue("true", forHTTPHeaderField: "OCS-APIREQUEST")

        webView.load(request)
    }
    
    private func beginPolling() {
        
        endPolling()
        
        guard let token = self.token, let endpoint = self.endpoint else { return }
            
        timerTask = Task.detached { [weak self] in
            
            while !Task.isCancelled {
                
                try await Task.sleep(for: .seconds(2))
                
                if Task.isCancelled { break }

                await self?.viewModel.loginPoll(token: token, endpoint: endpoint)
            }
        }
    }
    
    private func endPolling() {
        timerTask?.cancel()
        timerTask = nil
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
        guard let url = webView.url else { return }
        
        let urlString: String = url.absoluteString.lowercased()

        // prevent http redirection
        if login.lowercased().hasPrefix(Global.shared.http) && urlString.hasPrefix(Global.shared.https) {
            //Self.logger.error("didReceiveServerRedirectForProvisionalNavigation() - preventing redirect to \(urlString)")
            return
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {

        var errorMessage = error.localizedDescription

        for (key, value) in (error as NSError).userInfo {
            let message = "\(key) \(value)\n"
            errorMessage += message
        }
        
        //Self.logger.error("didFailProvisionalNavigation() - errorMessage: \(errorMessage)")

        viewModel.showInvalidURLPrompt()
    }
}

extension LoginWebController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    nonisolated func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        
        if let serverTrust = challenge.protectionSpace.serverTrust {
            return (Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            return (URLSession.AuthChallengeDisposition.useCredential, nil)
        }
    }
}
