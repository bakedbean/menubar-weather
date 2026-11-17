struct TimeoutError: Error {}

/// Returns `operation`'s result, or throws `TimeoutError` after `limit`.
/// The operation isn't awaited past the limit, so a never-resuming continuation can't block the caller.
@MainActor
func withTimeout<T: Sendable>(_ limit: Duration, _ operation: @escaping @MainActor () async throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        var resumed = false
        func finish(_ result: Result<T, Error>) {
            guard !resumed else { return }
            resumed = true
            continuation.resume(with: result)
        }
        let work = Task { @MainActor in
            do { finish(.success(try await operation())) } catch { finish(.failure(error)) }
        }
        Task { @MainActor in
            try? await Task.sleep(for: limit)
            finish(.failure(TimeoutError()))
            work.cancel()
        }
    }
}
