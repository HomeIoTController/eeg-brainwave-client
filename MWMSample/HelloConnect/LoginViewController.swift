//
//  LoginViewController.swift
//  HelloMWMiOS
//
//  Created by Daniel Marchena Parreira on 2018-11-26.
//  Copyright © 2018 neurosky. All rights reserved.
//

import UIKit
import Alamofire

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var loginBtn: UIButton!
    @IBOutlet weak var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.emailField.delegate = self
        self.passwordField.delegate = self
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func login(_ sender: UIButton) {
        
        self.errorLabel.text = "";
        
        let parameters: Parameters = [
            "operationName": "LoginMutation",
            "query": "mutation LoginMutation($email: String!, $password: String!) { login(email: $email, password: $password) }",
            "variables": Utils.convertToDictionary(text: "{\"email\":\"" + emailField.text! + "\",\"password\":\"" + passwordField.text! + "\"}")!
        ]
        
        let serverAddrs: String = ProcessInfo.processInfo.environment["server_addrs"] ?? "192.168.2.25:3000";
        
        Alamofire.request("http://"+serverAddrs+"/graphql", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { response in

            print("Result: \(response.result)")                         // response serialization result
            
            if let json = response.result.value {
                print("JSON: \(json)") // serialized json response
            }
            
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                let token = Utils.convertToDictionary(text: utf8Text);
                if ((token?["errors"]) != nil) {
                    self.errorLabel.text = "Invalid email/password!";
                    return;
                }
                let login = token?["data"] as! Dictionary<String, String>
                let jwt: String = login["login"]!;
                
                if let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DataViewController") as? DataViewController {
                    if let navigator = self.navigationController {
                        print(jwt)
                        viewController.jwt = jwt;
                        navigator.pushViewController(viewController, animated: true)
                    }
                }
            }
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
}
