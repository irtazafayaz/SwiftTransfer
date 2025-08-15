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
    
    func addDownload(urlString: String) {
        guard let url = URL(string: urlString) else {
            LogManager.w(.ui, "Bad URL: \(urlString)")
            return
        }
        
        let id = DownloadManager.shared.enqueue(
            url: url,
            onProgress: { [weak self] p in
                guard let self else { return }
                
                LogManager.d(.ui, "onProgress id=\(id) p=\(Int(((p ?? 0.0) * 100).rounded()))%")
                
                if let idx = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[idx].progress = p?.isFinite ?? true ? p : nil
                    self.items[idx].status = "Downloading"
                } else {
                    self.items.append(DownloadItem(id: id, url: url, progress: p, status: "Downloading"))
                }
            },
            onComplete: { [weak self] result in
                guard let self else { return }
                switch result {
                    case .success(let tmpURL):
                        LogManager.i(.ui, "onComplete SUCCESS id=\(id) tmp=\(tmpURL.lastPathComponent)")
                        if let idx = self.items.firstIndex(where: { $0.id == id }) {
                            self.items[idx].progress = 1.0
                            self.items[idx].status = "Completed: \(tmpURL.lastPathComponent)"
                            self.items[idx].errorMessage = nil
                        } else {
                            self.items.append(DownloadItem(id: id, url: url, progress: 1.0, status: "Completed: \(tmpURL.lastPathComponent)"))
                        }
                    case .failure(let err):
                        LogManager.e(.ui, "onComplete FAILURE id=\(id) error=\(err.localizedDescription)")
                        if let idx = self.items.firstIndex(where: { $0.id == id }) {
                            self.items[idx].status = "Failed"
                            self.items[idx].errorMessage = err.localizedDescription
                            self.items[idx].progress = nil
                        } else {
                            self.items.append(DownloadItem(id: id, url: url, progress: nil, status: "Failed", errorMessage: err.localizedDescription))
                        }
                }
            }
        )
    }
    
    func cancelDownload(id: UUID) {
        LogManager.w(.ui, "Cancel \(id)")
        DownloadManager.shared.cancel(id: id)
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].status = "Canceled"
            items[i].progress = nil
        }
    }
}
