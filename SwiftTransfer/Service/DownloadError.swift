//
//  DownloadError.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import Foundation

enum DownloadError: LocalizedError {
    case httpStatus(Int)
    case cancelled
    case noInternet
    case timedOut
    case cannotFindHost
    case fileSystem(Error)
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code): return "Server responded with status \(code)."
        case .cancelled:           return "Download was cancelled."
        case .noInternet:          return "No internet connection."
        case .timedOut:            return "The request timed out."
        case .cannotFindHost:      return "Cannot find host."
        case .fileSystem(let err): return "File error: \(err.localizedDescription)"
        case .other(let err):      return err.localizedDescription
        }
    }
}

extension DownloadError {
    static func from(_ error: Error) -> DownloadError {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .cancelled:         return .cancelled
            case .notConnectedToInternet: return .noInternet
            case .timedOut:          return .timedOut
            case .cannotFindHost,
                 .cannotConnectToHost: return .cannotFindHost
            default:                 return .other(urlErr)
            }
        }
        return .other(error)
    }
}
