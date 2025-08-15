//
//  Untitled.swift
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
    
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.example.swifttransfer.downloads"
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    private var operationsByTaskID: [Int: DownloadOperation] = [:]
    private var operationsByID: [UUID: DownloadOperation] = [:]
    
    // MARK: - Public APIs
    @discardableResult
    func enqueue(
        url: URL,
        priority: Operation.QueuePriority = .normal,
        onProgress: ((Double?) -> Void)?,
        onComplete: ((Result<URL, Error>) -> Void)? = nil
    ) -> UUID {
        let operation = DownloadOperation(url: url, session: session)
        operation.queuePriority = priority
        operation.onProgress = onProgress
        operation.onComplete = onComplete
        
        operation.registrar = { [weak self] task, operation in
            self?.operationsByTaskID[task.taskIdentifier] = operation
        }
        
        operationsByID[operation.id] = operation
        queue.addOperation(operation)
        return operation.id
    }
    
    func cancel(id: UUID) {
        operationsByID[id]?.cancel()
        operationsByID[id] = nil
    }
    
    func pause(id: UUID) {
        operationsByID[id]?.pause()
    }
    
    func resume(id: UUID) {
        guard let old = operationsByID[id], let resumeData = old.resumeData else { return }
        // Create a new op with resumeData
        let newOp = DownloadOperation(url: old.url, session: session)
        newOp.onProgress = old.onProgress
        newOp.onComplete = old.onComplete
        
        // Seed resume data
        newOp.resumeData = resumeData
        
        operationsByID[id] = newOp
        queue.addOperation(newOp)
    }
    
    func setMaxConcurrentDownloads(_ count: Int) {
        queue.maxConcurrentOperationCount = max(1, count)
    }
}

// MARK: - URLSessionDownloadDelegate
// DownloadManager+Delegate.swift
import Foundation

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let op = operationsByTaskID[downloadTask.taskIdentifier] else { return }

        // Check HTTP status
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {

            // Clean up temp file and fail with status
            try? FileManager.default.removeItem(at: location)
            op._didFail(DownloadError.httpStatus(http.statusCode))
        } else {
            op._didFinish(location: location)
        }

        operationsByTaskID[downloadTask.taskIdentifier] = nil
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error = error,
              let op = operationsByTaskID[task.taskIdentifier] else { return }

        op._didFail(DownloadError.from(error))
        operationsByTaskID[task.taskIdentifier] = nil
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if let op = operationsByTaskID[downloadTask.taskIdentifier] {
            op._didWrite(bytesWritten: bytesWritten,
                         totalBytesWritten: totalBytesWritten,
                         totalBytesExpected: totalBytesExpectedToWrite)
        }
    }
}
