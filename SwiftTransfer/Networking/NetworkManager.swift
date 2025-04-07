//
//  NetworkManager.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 26/03/2025.
//

import SwiftUI
import Alamofire

actor NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    
    func downloadFile(from url: String, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        let destination: DownloadRequest.Destination = { _, response in
            let fileManager = FileManager.default
            let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileUrl = documentsUrl.appendingPathComponent(response.suggestedFilename ?? "downloadedFile")
            return (fileUrl, [.removePreviousFile, .createIntermediateDirectories])
        }

        return try await withCheckedThrowingContinuation { continuation in
            AF.download(url, to: destination)
                .downloadProgress { progress in
                    progressHandler(progress.fractionCompleted)
                }
                .responseURL { response in
                    if let fileURL = response.fileURL {
                        continuation.resume(returning: fileURL)
                    } else if let error = response.error {
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

}
