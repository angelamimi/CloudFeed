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
    
    var coordinator: LoginWebCoordinator!
    var viewModel: LoginViewModel!
    
    @IBOutlet weak var webView: WKWebView!
    
    private var urlBase: String?
    
    private var configServerUrl: String?
    private var configUsername: String?
    private var configPassword: String?
    
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
    }
    
    func setURL(url: String) {
        urlBase = url
    }
    
    private func executeLoginFlowRequest() {
        
        guard urlBase != nil else { return }
        
        let serverURL: String = urlBase! + Global.shared.loginLocation
        
        guard let inputURL = URL(string: serverURL) else {
            coordinator.showInvalidURLPrompt()
            return
        }
        
        let languageCode: String? = NSLocale.preferredLanguages[0]
        
        var request = URLRequest(url: inputURL)
        
        request.setValue(languageCode, forHTTPHeaderField: "ACCEPT-LANGUAGE")
        request.setValue("true", forHTTPHeaderField: "OCS-APIREQUEST")

        webView.load(request)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
        Self.logger.debug("didReceiveServerRedirectForProvisionalNavigation() - boop")
        
        guard let url = webView.url else { return }
        guard urlBase != nil else { return }
        
        let urlString: String = url.absoluteString.lowercased()
        
        Self.logger.debug("didReceiveServerRedirectForProvisionalNavigation() - urlString: \(urlString)")

        // prevent http redirection
        if urlBase!.lowercased().hasPrefix(Global.shared.http) && urlString.lowercased().hasPrefix(Global.shared.https) {
            //Self.logger.error("didReceiveServerRedirectForProvisionalNavigation() - preventing redirect to \(urlString)")
            return
        }
        
        if urlString.hasPrefix(Global.shared.prefix) == true && urlString.contains(Global.shared.urlValidation) == true {
            webView.stopLoading()
            Self.logger.debug("didReceiveServerRedirectForProvisionalNavigation() - process result")
            processResult(url: url)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {

        var errorMessage = error.localizedDescription

        for (key, value) in (error as NSError).userInfo {
            let message = "\(key) \(value)\n"
            errorMessage += message
        }
        
        Self.logger.error("didFailProvisionalNavigation() - errorMessage: \(errorMessage)")

        coordinator.showInvalidURLPrompt()
    }
    
    private func processResult(url: URL) {
        //  From NextCloud - iOSClient/Login/NCLoginWeb.swift
        //  Created by Marino Faggiana on 21/08/2019.
        //  Copyright © 2019 Marino Faggiana. All rights reserved.
        var server: String = ""
        var user: String = ""
        var password: String = ""

        let keyValue = url.path.components(separatedBy: "&")
        for value in keyValue {
            if value.contains("server:") { server = value }
            if value.contains("user:") { user = value }
            if value.contains("password:") { password = value }
        }

        if server != "" && user != "" && password != "" {

            let server: String = server.replacingOccurrences(of: "/server:", with: "")
            let username: String = user.replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
            let password: String = password.replacingOccurrences(of: "password:", with: "")
            Self.logger.debug("processResult() - show login")
            viewModel.login(server: server, username: username, password: password)
        } else {
            Self.logger.debug("processResult() - parse failed")
            coordinator.showInitFailedPrompt()
        }
    }
}

extension LoginWebController: LoginDelegate {
    
    func loginSuccess(account: String, urlBase: String, user: String, userId: String, password: String) {
        coordinator.handleLoginSuccess(account: account, urlBase: urlBase, user: user, userId: userId, password: password)
    }
    
    func loginError() {
        coordinator.showInitFailedPrompt()
    }
}

extension LoginWebController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        Self.logger.debug("decidePolicyFor() - navigationAction: \(navigationAction.debugDescription)")
        return .allow
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @MainActor (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        //Task { @MainActor in
            if let serverTrust = challenge.protectionSpace.serverTrust {
                Self.logger.debug("didReceive-URLAuthenticationChallenge() - serverTrust")
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                Self.logger.debug("didReceive-URLAuthenticationChallenge() -")
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        //}
    }
    
    /*func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        //DispatchQueue.global().async {
        //TODO: Don't know why this was wrapped in the first place.
        Task { @MainActor in
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        //}
        }
    }*/
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        Self.logger.debug("decidePolicyFor-WKNavigationResponse() - allow")
        decisionHandler(.allow)
    }
    
    /*
     func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
         decisionHandler(.allow)
     }
     */
}

