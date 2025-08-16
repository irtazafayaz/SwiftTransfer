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

    /// Stable identifier owned by the manager/VM (injected to allow resume with same ID)
    let id: UUID
    let url: URL

    /// Callbacks now include the stable op ID
    var onProgress: ((UUID, Double?) -> Void)?
    var onComplete: ((UUID, Result<URL, Error>) -> Void)?

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
            let old = stateLock.withLock { _state }
            willChangeValue(forKey: old.keyPath)
            willChangeValue(forKey: newValue.keyPath)
            stateLock.withLock { _state = newValue }
            didChangeValue(forKey: old.keyPath)
            didChangeValue(forKey: newValue.keyPath)
        }
    }

    /// Registrar provided by the manager to map task -> operation
    var registrar: ((URLSessionTask, DownloadOperation) -> Void)?

    // MARK: - Operation overrides
    override var isAsynchronous: Bool { true }
    override var isReady: Bool { super.isReady && state == .ready }
    override var isExecuting: Bool { state == .executing }
    override var isFinished: Bool { state == .finished }

    init(id: UUID = UUID(), url: URL, session: URLSession) {
        self.id = id
        self.url = url
        self.session = session
        super.init()
    }

    override func start() {
        if isCancelled { finish(); return }
        super.start()

        state = .executing

        if let resumeData {
            LogManager.i(.operation, "op \(id) creating downloadTask (resume) \(url.absoluteString)")
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            LogManager.i(.operation, "op \(id) creating downloadTask \(url.absoluteString)")
            task = session.downloadTask(with: url)
        }

        guard let task else {
            LogManager.e(.operation, "op \(id) failed to create URLSessionDownloadTask")
            onComplete?(id, .failure(URLError(.unknown)))
            finish()
            return
        }

        registrar?(task, self)
        LogManager.d(.operation, "op \(id) registered task #\(task.taskIdentifier)")
        task.resume()
        LogManager.i(.operation, "op \(id) task #\(task.taskIdentifier) resumed")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onProgress?(self.id, 0)
        }
    }

    override func cancel() {
        LogManager.w(.operation, "op \(id) cancel() requested")
        task?.cancel(byProducingResumeData: { [weak self] data in
            guard let self else { return }
            self.resumeData = data
            LogManager.d(.operation, "op \(self.id) captured resumeData: \(data?.count ?? 0) bytes")
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

    // MARK: - Helpers
    private func finish() {
        if !isFinished { state = .finished }
    }

    // Internal hooks called by the session delegate
    func _didWrite(bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpected: Int64) {
        let progress: Double
        if totalBytesExpected > 0 {
            progress = max(0, min(1, Double(totalBytesWritten) / Double(totalBytesExpected)))
        } else {
            progress = 0
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onProgress?(self.id, progress)
        }
    }

    func _didFinish(location: URL) {
        LogManager.i(.operation, "op \(id) FINISHED task #\(task?.taskIdentifier ?? -1) temp: \(location.lastPathComponent)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onProgress?(self.id, 1.0)
            self.onComplete?(self.id, .success(location))
        }
        finish()
    }

    func _didFail(_ error: Error) {
        LogManager.e(.operation, "op \(id) FAILED task #\(task?.taskIdentifier ?? -1) error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onComplete?(self.id, .failure(error))
        }
        finish()
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
