import Foundation

public extension ProcessHandoffMonitor {
    init(
        snapshotProvider: @escaping @Sendable () async throws -> [ProcessSnapshot],
        sleeper: @escaping Sleeper = { duration in try await Task.sleep(for: duration) }
    ) {
        self.init(
            snapshotProvider: {
                let box = LockedResultBox<[ProcessSnapshot]>()
                let semaphore = DispatchSemaphore(value: 0)

                Task.detached {
                    do {
                        box.store(.success(try await snapshotProvider()))
                    } catch {
                        box.store(.failure(error))
                    }
                    semaphore.signal()
                }

                semaphore.wait()
                guard let result = box.load() else {
                    throw ProcessHandoffAsyncProviderError.missingResult
                }
                return try result.get()
            },
            sleeper: sleeper
        )
    }
}

private final class LockedResultBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?

    func store(_ value: Result<Value, Error>) {
        lock.lock()
        result = value
        lock.unlock()
    }

    func load() -> Result<Value, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

public enum ProcessHandoffAsyncProviderError: Error, Equatable {
    case missingResult
}
