//
//  Endpoints.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import Foundation

extension RestResultEndpoint {
    static var register: ConcreteResultEndpoint<RegisterRequest, RegisterResponse> {
        ConcreteResultEndpoint(
            requestType: .post,
            path: "/api/register",
            parameters: RegisterRequest.self,
            parameterContentType: .json,
            requiresAuthentication: false,
            resultType: RegisterResponse.self
        )
    }
}

struct RegisterRequest: Codable, Equatable {
    let firstName: String
    let lastName: String
    let email: String
    let username: String
    let password: String
}

struct RegisterResponse {}
extension RegisterResponse: Codable {}
extension RegisterResponse: Equatable {}
