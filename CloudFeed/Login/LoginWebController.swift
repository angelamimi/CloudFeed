//
//  LoginWebController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/12/23.
//
import KTVHTTPCache
import NextcloudKit
import os.log
import UIKit
import WebKit

class LoginWebController: UIViewController, WKNavigationDelegate {
    
    var coordinator: LoginWebCoordinator!
    
    private let webLoginAutenticationProtocol: String = "nc://"
    private var urlBase: String?// = "https://cloud.angelamimi.com"
    
    private var configServerUrl: String?
    private var configUsername: String?
    private var configPassword: String?
    
    private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: LoginWebController.self)
        )
    
    @IBOutlet weak var mWebKitView: WKWebView!

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.title = "Server Login"
        
        mWebKitView.navigationDelegate = self

        executeLoginFlowRequest()
    }
    
    func setURL(url: String) {
        urlBase = url
    }
    
    private func executeLoginFlowRequest() {
        
        Self.logger.debug("executeLoginFlowRequest()")
        
        guard urlBase != nil else { return }
        
        let serverURL: String = urlBase! + "/index.php/login/flow"
        
        guard let inputURL = URL(string: serverURL) else {
            coordinator.showInvalidURLPrompt()
            return
        }
        
        //let languageCode: String? = Locale.autoupdatingCurrent.language.languageCode?.identifier
        let languageCode: String? = NSLocale.preferredLanguages[0]
        
        var request = URLRequest(url: inputURL)
        
        Self.logger.debug("serverURL: \(serverURL)")
        Self.logger.debug("languageCode: \(languageCode!)")
        
        request.setValue(languageCode, forHTTPHeaderField: "ACCEPT-LANGUAGE")
        request.setValue("true", forHTTPHeaderField: "OCS-APIREQUEST")
        
        mWebKitView.load(request)
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
        guard let url = webView.url else { return }
        guard urlBase != nil else { return }
        
        let urlString: String = url.absoluteString.lowercased()
        
        // prevent http redirection
        if urlBase!.lowercased().hasPrefix("https://") && urlString.lowercased().hasPrefix("http://") {
            Self.logger.error("didReceiveServerRedirectForProvisionalNavigation() - preventing redirect to \(urlString)")
            return
        }
        
        if urlString.hasPrefix(webLoginAutenticationProtocol) == true && urlString.contains("login") == true {
            mWebKitView.stopLoading()
            processResult(url: url)
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        
        let urlString: String = url.absoluteString.lowercased()
        Self.logger.debug("didStartProvisionalNavigation() - urlString: \(urlString)")
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
        Self.logger.debug("didReceive()")
        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        Self.logger.debug("decidePolicyFor()")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Self.logger.debug("didFinish()")
    }
    
    private func processResult(url: URL) {
        //Pulled from NextCloud @ iOSClient/Login/NCLoginWeb.swift
        var server: String = ""
        var user: String = ""
        var password: String = ""

        let keyValue = url.path.components(separatedBy: "&")
        for value in keyValue {
            if value.contains("server:") { server = value }
            if value.contains("user:") { user = value }
            if value.contains("password:") { password = value }
        }
        
        Self.logger.debug("processResult() - server: \(server) user: \(user) password: \(password)")

        if server != "" && user != "" && password != "" {

            let server: String = server.replacingOccurrences(of: "/server:", with: "")
            let username: String = user.replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
            let password: String = password.replacingOccurrences(of: "password:", with: "")

            createAccount(server: server, username: username, password: password)
        } else {
            coordinator.showInitFailedPrompt()
        }
    }
    
    private func createAccount(server: String, username: String, password: String) {
        
        Self.logger.debug("createAccount() - server: \(server) username: \(username) password: \(password)")

        let dataService = Environment.current.dataService
        var urlBase = server

        // Normalized
        if urlBase.last == "/" {
            urlBase = String(urlBase.dropLast())
        }

        let account: String = "\(username) \(urlBase)"

        if dataService.getAccounts() == nil {
            
            initSettings()
            
            Self.logger.debug("createAccount() - removeAllSettings???")
        }

        // Add new account
        dataService.deleteAccount(account)
        dataService.addAccount(account, urlBase: urlBase, user: username, password: password)

        guard let tableAccount = dataService.setActiveAccount(account) else {
            coordinator.showInitFailedPrompt()
            return
        }
        
        Environment.current.initServicesFor(account: account, urlBase: urlBase, user: username, userId: tableAccount.userId, password: password)
        
        coordinator.handleLoginSuccess()
     }
    
    private func initSettings() {
        
        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
        KTVHTTPCache.cacheDeleteAllCaches()

        Environment.current.dataService.clearDatabase(account: nil, removeAccount: true)

        //StoreUtility.removeGroupDirectoryProviderStorage()
        //StoreUtility.removeGroupLibraryDirectory()

        //TODO: Causes database to fail. account isn't found eventhough was added
        //StoreUtility.removeDocumentsDirectory()
        
        
        //StoreUtility.removeTemporaryDirectory()

        StoreUtility.initStorage()

        //StoreUtility.deleteAllChainStore()
    }
}
