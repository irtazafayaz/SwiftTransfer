//
//  DownloadVM.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import Foundation

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var items: [DownloadItem] = []
    @Published var previewURL: URL?
    @Published var shareItem: ShareItem?

    func addDownload(urlString: String) {
        guard let url = URL(string: urlString) else {
            LogManager.w(.ui, "Bad URL: \(urlString)")
            return
        }

        let id = DownloadManager.shared.enqueue(
            url: url,
            onProgress: { [weak self] opID, p in
                guard let self else { return }
                LogManager.d(.ui, "onProgress opID=\(opID) p=\(Int(((p ?? 0.0) * 100).rounded()))%)")

                if let idx = self.items.firstIndex(where: { $0.id == opID }) {
                    self.items[idx].progress = p?.isFinite ?? true ? p : nil
                    self.items[idx].status = "Downloading"
                } else {
                    self.items.append(DownloadItem(id: opID, url: url, progress: p, status: "Downloading"))
                }
            },
            onComplete: { [weak self] opID, result in
                guard let self else { return }
                switch result {
                case .success(let stableURL):
                    LogManager.i(.ui, "onComplete SUCCESS opID=\(opID) file=\(stableURL.lastPathComponent)")
                    if let idx = self.items.firstIndex(where: { $0.id == opID }) {
                        self.items[idx].progress = 1.0
                        self.items[idx].status = "Completed: \(stableURL.lastPathComponent)"
                        self.items[idx].errorMessage = nil
                        self.items[idx].localFileURL = stableURL
                    } else {
                        self.items.append(
                            DownloadItem(id: opID, url: url, progress: 1.0,
                                         status: "Completed: \(stableURL.lastPathComponent)",
                                         localFileURL: stableURL)
                        )
                    }
                case .failure(let err):
                    LogManager.e(.ui, "onComplete FAILURE opID=\(opID) error=\(err.localizedDescription)")
                    if let idx = self.items.firstIndex(where: { $0.id == opID }) {
                        self.items[idx].status = "Failed"
                        self.items[idx].errorMessage = err.localizedDescription
                        self.items[idx].progress = nil
                    } else {
                        self.items.append(DownloadItem(id: opID, url: url, progress: nil,
                                                       status: "Failed", errorMessage: err.localizedDescription))
                    }
                }
            }
        )
        // If you want to show the row immediately at 0% even before the first callback:
        if items.first(where: { $0.id == id }) == nil {
            items.append(DownloadItem(id: id, url: url, progress: 0, status: "Starting"))
        }
    }

    func cancelDownload(id: UUID) {
        LogManager.w(.ui, "Cancel \(id)")
        DownloadManager.shared.cancel(id: id)
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].status = "Canceled"
            items[i].progress = nil
        }
    }

    func pauseDownload(id: UUID) {
        LogManager.w(.ui, "Pause \(id)")
        DownloadManager.shared.pause(id: id)
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].status = "Paused"
        }
    }

    func resumeDownload(id: UUID) {
        LogManager.w(.ui, "Resume \(id)")
        DownloadManager.shared.resume(id: id)
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].status = "Resuming"
        }
    }

    func preview(id: UUID) {
        guard let fileURL = items.first(where: { $0.id == id })?.localFileURL else {
            LogManager.e(.ui, "No local file URL for \(id)")
            return
        }
        previewURL = fileURL
    }

    func saveOrShare(id: UUID) {
        guard let fileURL = items.first(where: { $0.id == id })?.localFileURL else { return }
        let newItem = ShareItem(url: fileURL)
        if shareItem != newItem { shareItem = newItem }
    }
}
