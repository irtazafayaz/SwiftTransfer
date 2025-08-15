//
//  RestEndpoint.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 12/08/2025.
//

import Foundation

enum RequestType {
    case get
    case post
}

/// Workaround until a future version ow swift when KeyPaths are sendable:
/// https://github.com/apple/swift/issues/57560#issuecomment-1997512126
extension KeyPath: @unchecked Sendable {}

enum ContentType<Parameters>: Sendable {
    case get
    case url([KeyPath<Parameters, String>])
    case json

    case multipartFormData
}

enum FormDataPart {
    case string(name: String, string: String)
    case data(name: String, data: Data, mimeType: String)
    case file(name: String, localURL: URL, mimeType: String)
}

protocol MultipartFormDataConvertable {
    var data: [FormDataPart] { get }
    var fileURL: URL { get }
    var mimeType: String { get }
    var filename: String { get }
}

protocol RestEndpoint: Sendable {
    associatedtype Parameters: Encodable, Sendable

    var requestType: RequestType { get }
    var pathBuilder: @Sendable (Parameters) -> String { get }
    var parameters: Parameters.Type { get }
    var parameterContentType: ContentType<Parameters> { get }
    var requiresAuthentication: Bool { get }
}

extension RestEndpoint {
    func requestURL(withBaseURL root: URL, parameters: Parameters, dynamicPathComponents: [String: String]) -> URL {
        var path = pathBuilder(parameters)

        if !dynamicPathComponents.isEmpty {
            for (key, value) in dynamicPathComponents {
                path = path.replacingOccurrences(of: "{\(key)}", with: value)
            }
        }

        switch parameterContentType {
        case let .url(keyPaths):
            let components = URLComponents(string: path)

            let pathTokens = path.split(separator: "/")
            var index = 0
            let path = "/" + String(pathTokens.map { token in
                guard token.starts(with: "{") else {
                    return String(token)
                }

                let result = parameters[keyPath: keyPaths[index]]
                index += 1
                return result
            }
            .joined(separator: "/"))
            var finalURL = root.appendingPathComponent(path)
            if let queryItems = components?.queryItems {
                finalURL = finalURL.appending(queryItems: queryItems)
            }
            return finalURL

        case .get, .json, .multipartFormData:
            let components = URLComponents(string: path)

            if let path = components?.path {
                var finalURL = root.appendingPathComponent(path)
                if let queryItems = components?.queryItems {
                    finalURL = finalURL.appending(queryItems: queryItems)
                }

                return finalURL
            }
            return root.appendingPathComponent(path)
        }
    }
}

struct ConcreteEndpoint<Parameters: Encodable & Sendable>: RestEndpoint {
    let requestType: RequestType
    let pathBuilder: @Sendable (Parameters) -> String
    let parameters: Parameters.Type
    let parameterContentType: ContentType<Parameters>
    let requiresAuthentication: Bool

    init(
        requestType: RequestType,
        path: String,
        parameters: Parameters.Type,
        parameterContentType: ContentType<Parameters> = .get,
        requiresAuthentication: Bool = true
    ) {
        self.requestType = requestType
        pathBuilder = { _ in path }
        self.parameters = parameters
        self.parameterContentType = parameterContentType
        self.requiresAuthentication = requiresAuthentication
    }

    init(
        requestType: RequestType,
        parameters: Parameters.Type,
        parameterContentType: ContentType<Parameters> = .get,
        requiresAuthentication: Bool = true,
        dynamicPathComponents: [String: String] = [:],
        pathBuilder: @escaping @Sendable (Parameters) -> String
    ) {
        self.requestType = requestType
        self.pathBuilder = pathBuilder
        self.parameters = parameters
        self.parameterContentType = parameterContentType
        self.requiresAuthentication = requiresAuthentication
    }
}

protocol RestResultEndpoint: RestEndpoint, Sendable {
    associatedtype Result: Decodable, Sendable

    var resultType: Result.Type { get }
}

struct ConcreteResultEndpoint<Parameters: Encodable & Sendable, Result: Decodable & Sendable>: RestResultEndpoint {
    let requestType: RequestType
    let pathBuilder: @Sendable (Parameters) -> String
    let parameters: Parameters.Type
    let parameterContentType: ContentType<Parameters>
    let requiresAuthentication: Bool
    let resultType: Result.Type

    init(
        requestType: RequestType,
        path: String,
        parameters: Parameters.Type,
        parameterContentType: ContentType<Parameters> = .get,
        requiresAuthentication: Bool = true,
        resultType: Result.Type
    ) {
        self.requestType = requestType
        pathBuilder = { _ in path }
        self.parameters = parameters
        self.parameterContentType = parameterContentType
        self.requiresAuthentication = requiresAuthentication
        self.resultType = resultType
    }

    init(
        requestType: RequestType,
        parameters: Parameters.Type,
        parameterContentType: ContentType<Parameters> = .get,
        requiresAuthentication: Bool = true,
        resultType: Result.Type,
        pathBuilder: @Sendable @escaping (Parameters) -> String
    ) {
        self.requestType = requestType
        self.pathBuilder = pathBuilder
        self.parameters = parameters
        self.parameterContentType = parameterContentType
        self.requiresAuthentication = requiresAuthentication
        self.resultType = resultType
    }
}
