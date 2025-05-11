//
//  DownloadService.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 26/03/2025.
//

import SwiftUI

class DownloadService: NSObject, URLSessionDownloadDelegate {
    private var progressHandler: (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?

    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
    }

    func startDownload(using session: URLSession, from url: URL) async throws -> URL {
        let task = session.downloadTask(with: url)
        task.resume()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    // MARK: - Delegate methods

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressHandler(progress)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // ✅ Extract original filename or default to "video.mp4"
        let suggestedFilename = downloadTask.originalRequest?.url?.lastPathComponent ?? "video.mp4"
        let destURL = docs.appendingPathComponent(suggestedFilename)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: location, to: destURL)

            continuation?.resume(returning: destURL)
        } catch {
            continuation?.resume(throwing: error)
        }

        continuation = nil
    }


    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}


