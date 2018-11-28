//
//  Utils.swift
//  eeg-brainwave-client
//
//  Created by Daniel Marchena Parreira on 2018-11-28.
//  Copyright © 2018 neurosky. All rights reserved.
//

import Foundation

class Utils {
    static func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}
