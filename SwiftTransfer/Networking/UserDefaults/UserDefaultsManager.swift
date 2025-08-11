//
//  UserDefaultsManager.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 12/08/2025.
//

import Foundation

actor UserDefaultsManager: UserDefaultsManaging {
    
    static let shared = UserDefaultsManager()
    private let userDefaults = UserDefaults.standard
    private init() {}
    
    func readObject<T>(forKey: PersistentStorageKeys, for type: T.Type) -> T? {
        if let value = userDefaults.object(forKey: forKey.rawValue) as? T {
            return value
        }
        return nil
    }
    
    func saveObject<T>(forKey: PersistentStorageKeys, value: T) async where T : Sendable {
        userDefaults.set(value, forKey: forKey.rawValue)
    }
    
    func deleteObject(forKey: PersistentStorageKeys) async {
        userDefaults.removeObject(forKey: forKey.rawValue)
    }
    
    func readEncodableObject<Value>(forKey: PersistentStorageKeys, castTo type: Value.Type) async throws -> Value where Value : Decodable {
        let data = userDefaults.data(forKey: forKey.rawValue) ?? Data()
        let decoder = JSONDecoder()
        do {
            let object = try decoder.decode(type, from: data)
            return object
        } catch {
            throw ObjectSavableError.unableToDecode
        }
    }
    
    func saveEncodableObject<Value>(forKey: PersistentStorageKeys, value: Value) async throws where Value : Encodable, Value : Sendable {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(value)
            userDefaults.set(data, forKey: forKey.rawValue)
        } catch {
            throw ObjectSavableError.unableToEncode
        }
    }
    
    func clearAllData() async {}
    

    
}

extension UserDefaultsManager {
    enum ObjectSavableError: String, LocalizedError {
        case unableToEncode = "Unable to encode object into data"
        case noValue = "No data object found for the given key"
        case unableToDecode = "Unable to decode object into given type"

        var errorDescription: String? {
            rawValue
        }
    }
}
