//
//  RestClient.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import Foundation

enum RestClientError: Error {
    case notAuthenticated
    case badStatus(code: Int)
}

protocol RestClient: Sendable {
    associatedtype Endpoint: RestEndpoint

    func request(parameters: Endpoint.Parameters) async throws
}

protocol RestResultClient: Sendable {
    associatedtype ResultEndpoint: RestResultEndpoint

    func request(parameters: ResultEndpoint.Parameters, dynamicComponents: [String: String]) async throws -> ResultEndpoint.Result
}

extension RestResultClient {
    func request(parameters: ResultEndpoint.Parameters) async throws -> ResultEndpoint.Result {
        try await request(parameters: parameters, dynamicComponents: [:])
    }
}

protocol DownloadClient: Sendable {
    func request(url: URL, localURL: URL, setProgress: @escaping @MainActor @Sendable (Double, Bool) -> Void) async throws -> URL
}

protocol UploadClient: Sendable {
    associatedtype Endpoint: RestEndpoint

    func uploadRequest(
        parameters: Endpoint.Parameters,
        setProgress: @escaping @MainActor @Sendable (Double, Bool) -> Void
    ) async throws
}
