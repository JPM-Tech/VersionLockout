//
//  DeferredTask.swift
//  VersionLockout
//
//  Created by Jacob Zivan Rakidzich  on 1/16/26.
//

import Foundation

/// A container that deduplicates concurrent async work.
///
/// When multiple callers request work simultaneously, they all await the same
/// in-flight task rather than starting duplicate work. The task is automatically
/// cleared when complete, allowing fresh work on the next request.
///
/// Example usage:
/// ```swift
/// let deferred = DeferredTask<String>()
///
/// // Multiple concurrent calls will share the same task
/// let result = await deferred.getOrPut {
///     try await fetchDataFromNetwork()
/// }
/// ```
///
/// - Note: This type is `@MainActor` isolated, so all access is serialized
///   and no locks are needed.
@MainActor
public final class DeferredTask<T: Sendable> {
    private var inFlightTask: Task<T, Never>?

    public init() {}

    /// Returns the result of an existing in-flight task, or creates and stores
    /// a new task if none exists.
    ///
    /// - Parameter work: A closure that produces the task to execute if no
    ///   task is currently in flight. The closure is `@autoclosure` so the
    ///   task is only created when needed.
    /// - Returns: The result of the task.
    public func getOrPut(_ work: @autoclosure @escaping () -> Task<T, Never>) -> Task<T, Never> {
        if let existing = inFlightTask {
            return existing
        }

        let task = Task<T, Never> {
            defer { self.inFlightTask = nil }
            return await work().value
        }

        inFlightTask = task
        return task
    }

    /// Clears any stored in-flight task.
    ///
    /// This does not cancel the task; callers who already have a reference
    /// will still see it complete.
    public func clear() {
        inFlightTask = nil
    }

    /// Whether a task is currently in flight.
    public var hasInFlightTask: Bool {
        inFlightTask != nil
    }
}
