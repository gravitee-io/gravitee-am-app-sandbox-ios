//
//  ViewController.swift
//  gravitee-am-app-sandbox-ios
//
//  Created by Jean-Baptiste Dujardin on 08/11/2021.
//

import UIKit
import AppAuth

class ViewController: UIViewController {
    
    var authState: OIDAuthState?
    
    // Environment configuration
    let issuer = URL(string:"https://am-nightly-gateway.cloud.gravitee.io/demo/oidc")!
    let clientID = "679fbae9-0a1a-4885-9fba-e90a1a188580"
    let redirectURI = "io.gravitee.oauth.test:/oauthredirect"
    
    // UI
    @IBOutlet weak var configLogsTextView: UITextView!
    @IBOutlet weak var authorizationLogsTextView: UITextView!
    @IBOutlet weak var userInfosLogsTextView: UITextView!
    @IBOutlet weak var authorizeButton: UIButton!
    @IBOutlet weak var userInfosButton: UIButton!
    
    var configuration: OIDServiceConfiguration?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func getConfig() {
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { configuration, error in
          guard let config = configuration else {
              DispatchQueue.main.async {
                  self.configLogsTextView.text = "Error retrieving discovery document: \(error?.localizedDescription ?? "Unknown error")"
              }
            return
          }
            
            self.configuration = config
            self.authorizeButton.isEnabled = true
            self.configLogsTextView.text = "Got configuration:  \(config)"
        }
    }
    
    @IBAction func getAuthorization() {
        if let configuration = configuration {
            let request = OIDAuthorizationRequest(configuration: configuration,
                                                  clientId: clientID,
                                                  scopes: [OIDScopeOpenID, OIDScopeProfile],
                                                  redirectURL: URL(string: redirectURI)!,
                                                  responseType: OIDResponseTypeCode,
                                                  additionalParameters: nil)
            authorizationLogsTextView.text = "Initiating authorization request with scope: \(request.scope ?? "nil")"
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.currentAuthorizationFlow =
                OIDAuthState.authState(byPresenting: request, presenting: self) { authState, error in
              if let authState = authState {
                self.authState = authState
                  DispatchQueue.main.async {
                      self.authorizationLogsTextView.text = "Got authorization tokens. Access token: " +
                      "\(authState.lastTokenResponse?.accessToken ?? "nil")"
                  }
                  self.userInfosButton.isEnabled = true
              } else {
                  DispatchQueue.main.async {
                      self.authorizationLogsTextView.text = "Authorization error: \(error?.localizedDescription ?? "Unknown error")"
                  }
                self.authState = nil
              }
            }
        }
    }
    
    @IBAction func getUserInfos() {
        if let userInfosEndpoint = configuration?.discoveryDocument?.userinfoEndpoint {
            
            self.authState?.performAction() { (accessToken, idToken, error) in

              if error != nil  {
                  DispatchQueue.main.async {
                      self.userInfosLogsTextView.text = "Error fetching fresh tokens: \(error?.localizedDescription ?? "Unknown error")"
                  }
                return
              }
              guard let accessToken = accessToken else {
                return
              }

              // Add Bearer token to request
              var urlRequest = URLRequest(url: userInfosEndpoint)
              urlRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]

                let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                    if error != nil {
                        DispatchQueue.main.async {
                            self.userInfosLogsTextView.text = "Error fetching user infos: \(error?.localizedDescription ?? "Unknown error")"
                        }
                      return
                    }
                    guard let data = data else {
                      return
                    }
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any]
                        DispatchQueue.main.async {
                            self.userInfosLogsTextView.text = "Got User Infos: \(String(describing: json))"
                        }
                        } catch {
                            DispatchQueue.main.async {
                                self.userInfosLogsTextView.text = "Error: \(error)"
                            }
                        }
                }
                
                task.resume()
            }
        }
    }
}

