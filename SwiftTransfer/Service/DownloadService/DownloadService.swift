//
//  DownloadService.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 26/03/2025.
//

import SwiftUI

@MainActor
class DownloadService: ObservableObject {
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedFilePath: URL?
    @Published var errorMessage: String?
    @Published var isPreviewPresented: Bool = false

    func startDownload(from url: String) {
        downloadProgress = 0.0
        downloadedFilePath = nil
        errorMessage = nil

        Task {
            do {
                let filePath = try await NetworkManager.shared.downloadFile(from: url) { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress
                    }
                }
                downloadedFilePath = filePath
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func openDownloadedFile() {
        if let filePath = downloadedFilePath {
            UIApplication.shared.open(filePath)
        }
    }
}

