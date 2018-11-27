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
    
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    @IBAction func login(_ sender: UIButton) {
        
        let parameters: Parameters = [
            "operationName": "LoginMutation",
            "query": "mutation LoginMutation($email: String!, $password: String!) { login(email: $email, password: $password) }",
            "variables": convertToDictionary(text: "{\"email\":\"da1\",\"password\":\"da1\"}")!
        ]
        
        print(parameters)
        
        Alamofire.request("http://192.168.2.25:3000/graphql", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { response in

            print("Result: \(response.result)")                         // response serialization result
            
            if let json = response.result.value {
                print("JSON: \(json)") // serialized json response
            }
            
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                let token = self.convertToDictionary(text: utf8Text);
                let login = token?["data"] as! Dictionary<String, String>
                let jwt: String = login["login"]!;
                
                if let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HelloConnectViewController") as? HelloConnectViewController {
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
