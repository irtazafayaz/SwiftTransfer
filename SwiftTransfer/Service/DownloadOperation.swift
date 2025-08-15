//
//  DownloadOperation.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import Foundation

final class DownloadOperation: Operation {
    enum State: String {
        case ready, executing, finished
        fileprivate var keyPath: String { "is" + rawValue.capitalized }
    }
    
    // MARK: - Public API
    
    let id: UUID = .init()
    let url: URL
    var onProgress: ((Double?) -> Void)?
    var onComplete: ((Result<URL, Error>) -> Void)?
    
    // Pause/resume support
    var resumeData: Data?
    
    // MARK: - Private
    
    private var task: URLSessionDownloadTask?
    private let session: URLSession
    private let stateLock = NSLock()
    
    // KVO-compliant state
    private var _state: State = .ready
    private var state: State {
        get { stateLock.withLock { _state } }
        set {
            willChangeValue(forKey: _state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
            stateLock.withLock { _state = newValue }
            didChangeValue(forKey: _state.keyPath)
            didChangeValue(forKey: newValue.keyPath)
        }
    }
    
    var registrar: ((URLSessionTask, DownloadOperation) -> Void)?
    
    // MARK: - Operation overrides
    override var isAsynchronous: Bool { true }
    override var isReady: Bool { super.isReady && state == .ready }
    override var isExecuting: Bool { state == .executing }
    override var isFinished: Bool { state == .finished }
    
    init(url: URL, session: URLSession) {
        self.url = url
        self.session = session
        super.init()
    }
    
    override func start() {
        if isCancelled { finish(); return }
        super.start() // sets executing + logs
        
        if let resumeData {
            LogManager.i(.operation, "op \(id) creating downloadTask (resume) \(url.absoluteString)")
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            LogManager.i(.operation, "op \(id) creating downloadTask \(url.absoluteString)")
            task = session.downloadTask(with: url)
        }
        
        if let task {
            registrar?(task, self)
            LogManager.d(.operation, "op \(id) registered task #\(task.taskIdentifier)")
            task.resume()
            LogManager.i(.operation, "op \(id) task #\(task.taskIdentifier) resumed")
        } else {
            LogManager.e(.operation, "op \(id) failed to create URLSessionDownloadTask")
            onComplete?(.failure(URLError(.unknown)))
            finish()
            return
        }
        
        // Nudge UI from "Queued" → "Starting"
        DispatchQueue.main.async { [weak self] in self?.onProgress?(0) }
    }
    
    
    
    override func cancel() {
        LogManager.w(.operation, "op \(id) cancel() requested")
        task?.cancel(byProducingResumeData: { [weak self] data in
            self?.resumeData = data
            LogManager.d(.operation, "op \(self?.id.uuidString ?? "?") captured resumeData: \(data?.count ?? 0) bytes")
        })
        super.cancel()
        finish()
    }
    
    // MARK: - Controls
    func pause() {
        guard state == .executing else { return }
        task?.cancel(byProducingResumeData: { [weak self] data in
            self?.resumeData = data
        })
        finish()
    }
    
    func resume() {
        guard isFinished, let _ = resumeData else { return }
        // TODO: Complete resume function
    }
    
    // MARK: - Helpers
    private func finish() {
        if !isFinished { state = .finished }
    }
    
    private func attachHandlers() {
        // Handled in URLSession delegate owned by DownloadManager.
        // Kept empty here to emphasize the manager/delegate pattern.
    }
    
    // Internal hooks called by the session delegate
    // In DownloadOperation._didWrite(...)
    func _didWrite(bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpected: Int64) {
        let progress: Double
        if totalBytesExpected > 0 {
            progress = max(0, min(1, Double(totalBytesWritten) / Double(totalBytesExpected)))
        } else {
            progress = 0 // unknown size; keep at 0 but we still log occasionally
        }
        
        DispatchQueue.main.async { [weak self] in self?.onProgress?(progress) }
    }
    
    func _didFinish(location: URL) {
        LogManager.i(.operation, "op \(id) FINISHED task #\(task?.taskIdentifier ?? -1) temp: \(location.lastPathComponent)")
        DispatchQueue.main.async { [weak self] in
            self?.onProgress?(1.0)                         // <— force fill
            self?.onComplete?(.success(location))
        }
        finish()
    }
    
    func _didFail(_ error: Error) {
        LogManager.e(.operation, "op \(id) FAILED task #\(task?.taskIdentifier ?? -1) error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in self?.onComplete?(.failure(error)) }
        finish()
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
