//
//  LoginWebController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//

import NextcloudKit
import os.log
import UIKit
import WebKit

class LoginWebController: UIViewController, WKNavigationDelegate {
    
    var coordinator: LoginWebCoordinator!
    var viewModel: LoginViewModel!
    
    @IBOutlet weak var mWebKitView: WKWebView!
    
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
        
        mWebKitView.navigationDelegate = self

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
        
        mWebKitView.load(request)
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
        guard let url = webView.url else { return }
        guard urlBase != nil else { return }
        
        let urlString: String = url.absoluteString.lowercased()
        
        // prevent http redirection
        if urlBase!.lowercased().hasPrefix(Global.shared.http) && urlString.lowercased().hasPrefix(Global.shared.https) {
            Self.logger.error("didReceiveServerRedirectForProvisionalNavigation() - preventing redirect to \(urlString)")
            return
        }
        
        if urlString.hasPrefix(Global.shared.prefix) == true && urlString.contains(Global.shared.urlValidation) == true {
            mWebKitView.stopLoading()
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
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
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

            viewModel.login(server: server, username: username, password: password)
        } else {
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

