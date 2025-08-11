//
//  UserDefaultsManaging.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 12/08/2025.
//

protocol UserDefaultsManaging: Sendable {
    func readObject<T: Sendable>(forKey: PersistentStorageKeys, for type: T.Type) async -> T?
    func saveObject<T: Sendable>(forKey: PersistentStorageKeys, value: T) async
    func deleteObject(forKey: PersistentStorageKeys) async
    
    func readEncodableObject<Value: Sendable>(forKey: PersistentStorageKeys, castTo type: Value.Type) async throws -> Value where Value: Decodable
    func saveEncodableObject<Value: Sendable>(forKey: PersistentStorageKeys, value: Value) async throws where Value: Encodable
    func clearAllData() async
}
