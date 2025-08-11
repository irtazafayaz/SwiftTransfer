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
    
    private var delegate: DownloadService?
    private var session: URLSession?

    func downloadFile(from urlString: String, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let delegate = await DownloadService(progressHandler: progressHandler)
        self.delegate = delegate // retain it
        let session = URLSession(configuration: .background(withIdentifier: UUID().uuidString),
                                 delegate: delegate,
                                 delegateQueue: nil)
        self.session = session
        
        return try await delegate.startDownload(using: session, from: url)
    }
}

