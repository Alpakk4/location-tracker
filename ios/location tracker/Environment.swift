//
//  Environment.swift
//  location tracker
//
//  Created by Joel on 01/09/2025.
//
import Foundation

public enum Environment {
    enum Keys {
        static let apikey = "API_KEY"
        static let endpoint = "ENDPOINT"
        static let adminPassword = "HOME_LOCK_PASSWORD"

            
    }
    
    private static let infoDictionary: [String: Any]  = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("no plist file")
        }
        return dict
    }()
    
    static let apikey: String = {
        guard let apiKey = infoDictionary[Keys.apikey] as? String else {
            fatalError("no apikey provided")
        }
        return apiKey
    }()
    
    static let endpoint: String = {
        guard let endpoint = infoDictionary[Keys.endpoint] as? String else {
            fatalError("no endpoint provided")
        }
        return endpoint}()
    
    static let adminPassword: String = {
            guard let password = infoDictionary[Keys.adminPassword] as? String else {
                fatalError("AdminPassword not found in Plist")
            }
            return password
    }()
}
