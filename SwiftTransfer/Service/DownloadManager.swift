//
//  DownloadManager.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import Foundation

final class DownloadManager: NSObject {
    static let shared = DownloadManager()

    // MARK: - Session

    private lazy var session: URLSession = {
        let useBackground = false
        if useBackground {
            let config = URLSessionConfiguration.background(withIdentifier: "com.example.swifttransfer.bg")
            config.allowsExpensiveNetworkAccess = true
            config.allowsConstrainedNetworkAccess = true
            config.waitsForConnectivity = true
            return URLSession(configuration: config, delegate: self, delegateQueue: nil)
        } else {
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            config.allowsExpensiveNetworkAccess = true
            return URLSession(configuration: config, delegate: self, delegateQueue: nil)
        }
    }()

    // MARK: - Queue

    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.example.swifttransfer.downloads"
        q.maxConcurrentOperationCount = 3
        q.qualityOfService = .userInitiated
        return q
    }()

    // MARK: - State

    private var operationsByTaskID: [Int: DownloadOperation] = [:]
    private var operationsByID: [UUID: DownloadOperation] = [:]

    // MARK: - Public API

    @discardableResult
    func enqueue(
        url: URL,
        priority: Operation.QueuePriority = .normal,
        onProgress: @escaping (UUID, Double?) -> Void,
        onComplete: ((UUID, Result<URL, Error>) -> Void)? = nil
    ) -> UUID {
        let opID = UUID()
        let op = DownloadOperation(id: opID, url: url, session: session)
        op.queuePriority = priority
        op.onProgress = onProgress
        op.onComplete = onComplete

        // Registrar is called when the op creates its URLSessionTask.
        op.registrar = { [weak self] task, operation in
            self?.operationsByTaskID[task.taskIdentifier] = operation
            LogManager.d(.operation, "map task #\(task.taskIdentifier) -> op \(operation.id)")
        }

        operationsByID[opID] = op
        queue.addOperation(op)
        return opID
    }

    func cancel(id: UUID) {
        operationsByID[id]?.cancel()
        operationsByID[id] = nil
    }

    func pause(id: UUID) {
        operationsByID[id]?.pause()
    }

    func resume(id: UUID) {
        guard let old = operationsByID[id], let resumeData = old.resumeData else {
            LogManager.w(.operation, "resume(id:) no resume data for \(id)")
            return
        }
        let newOp = DownloadOperation(id: id, url: old.url, session: session)
        newOp.onProgress = old.onProgress
        newOp.onComplete = old.onComplete
        newOp.resumeData = resumeData
        newOp.registrar = { [weak self] task, operation in
            self?.operationsByTaskID[task.taskIdentifier] = operation
            LogManager.d(.operation, "map task #\(task.taskIdentifier) -> op \(operation.id) [resumed]")
        }
        operationsByID[id] = newOp
        queue.addOperation(newOp)
    }

    func setMaxConcurrentDownloads(_ count: Int) {
        queue.maxConcurrentOperationCount = max(1, count)
    }

    // Helper to find op for a given task
    fileprivate func operationFor(task: URLSessionTask) -> DownloadOperation? {
        operationsByTaskID[task.taskIdentifier]
    }

    // Cleanup helpers
    private func clear(taskID: Int) {
        operationsByTaskID[taskID] = nil
    }

    fileprivate func clear(op: DownloadOperation) {
        operationsByID[op.id] = nil
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let op = operationFor(task: downloadTask) else { return }

        do {
            // Prefer server-suggested filename; fallback to request URL component.
            let suggested = downloadTask.response?.suggestedFilename
            let requestName = op.url.lastPathComponent.removingPercentEncoding ?? op.url.lastPathComponent
            let base = (suggested?.isEmpty == false ? suggested! : requestName)
            let name = base.isEmpty ? "download" : base
            let hasExt = !(name as NSString).pathExtension.isEmpty
            let finalName = hasExt ? name : name + inferredExtension(from: downloadTask)

            // Destination in Caches
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let dst = uniqueURL(base: caches.appendingPathComponent(finalName))

            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.moveItem(at: location, to: dst)

            op._didFinish(location: dst)

        } catch {
            op._didFail(error)
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let op = operationsByTaskID[downloadTask.taskIdentifier] else { return }
        op._didWrite(bytesWritten: bytesWritten,
                     totalBytesWritten: totalBytesWritten,
                     totalBytesExpected: totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let op = operationsByTaskID[task.taskIdentifier] else { return }
        defer { clear(taskID: task.taskIdentifier) }
        if let error { op._didFail(error) }
        // If no error, success path already handled in didFinishDownloadingTo.
    }

    // MARK: - Filename helpers

    private func inferredExtension(from task: URLSessionDownloadTask) -> String {
        let mime = (task.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type")?
            .lowercased() ?? ""
        if mime.contains("pdf") { return ".pdf" }
        if mime.contains("json") { return ".json" }
        if mime.contains("zip") { return ".zip" }
        if mime.contains("jpeg") || mime.contains("jpg") { return ".jpg" }
        if mime.contains("png") { return ".png" }
        return "" // unknown
    }

    private func uniqueURL(base: URL) -> URL {
        var url = base
        var idx = 1
        while FileManager.default.fileExists(atPath: url.path) {
            let stem = base.deletingPathExtension().lastPathComponent
            let ext = base.pathExtension
            let newName = ext.isEmpty ? "\(stem)-\(idx)" : "\(stem)-\(idx).\(ext)"
            url = base.deletingLastPathComponent().appendingPathComponent(newName)
            idx += 1
        }
        return url
    }
}
