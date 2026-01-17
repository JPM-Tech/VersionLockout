//
//  DeferredTaskTests.swift
//  VersionLockout
//
//  Created by Jacob Zivan Rakidzich on 1/16/26.
//

import Foundation
import Testing
@testable import VersionLockout

@MainActor
struct DeferredTaskTests {

    @Test("getOrPut returns result from work")
    func getOrPut_returnsResult() async {
        let deferred = DeferredTask<Int>()

        let task = deferred.getOrPut(Task { 42 })
        let result = await task.value

        #expect(result == 42)
    }

    @Test("getOrPut clears task after completion")
    func getOrPut_clearsTaskAfterCompletion() async {
        let deferred = DeferredTask<Int>()

        #expect(deferred.hasInFlightTask == false)

        let task = deferred.getOrPut(Task { 42 })
        #expect(deferred.hasInFlightTask == true)

        _ = await task.value

        // Give the defer a moment to execute
        await yield()
        #expect(deferred.hasInFlightTask == false)
    }

    @Test("concurrent getOrPut calls share the same task")
    func getOrPut_deduplicatesConcurrentCalls() async {
        let deferred = DeferredTask<Int>()
        let counter = Counter()

        // Start first call with slow task
        let task1 = deferred.getOrPut(Task {
            counter.increment()
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            return 42
        })

        await yield()

        // Start second call while first is in flight - should get same task
        let task2 = deferred.getOrPut(Task {
            counter.increment()
            return 99 // Different value to prove this doesn't run
        })

        // Both should get the same result from the first task
        let r1 = await task1.value
        let r2 = await task2.value

        #expect(r1 == 42)
        #expect(r2 == 42)

        // Work should only execute once
        #expect(counter.value == 1)
    }

    @Test("sequential getOrPut calls execute separate tasks")
    func getOrPut_allowsSequentialCalls() async {
        let deferred = DeferredTask<Int>()
        let counter = Counter()

        // First call
        let result1 = await deferred.getOrPut(Task {
            counter.increment()
            return counter.value
        }).value

        await yield() // Let defer clear the task

        // Second call (after first completed)
        let result2 = await deferred.getOrPut(Task {
            counter.increment()
            return counter.value
        }).value

        #expect(result1 == 1)
        #expect(result2 == 2)
        #expect(counter.value == 2)
    }

    @Test("clear removes in-flight task reference")
    func clear_removesTaskReference() async {
        let deferred = DeferredTask<Int>()

        _ = deferred.getOrPut(Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            return 42
        })

        #expect(deferred.hasInFlightTask == true)

        deferred.clear()

        #expect(deferred.hasInFlightTask == false)
    }

    @Test("clear allows new task to start")
    func clear_allowsNewTaskToStart() async {
        let deferred = DeferredTask<Int>()
        let counter = Counter()

        // Start a slow task
        let task1 = deferred.getOrPut(Task {
            counter.increment()
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            return 1
        })

        #expect(deferred.hasInFlightTask == true)

        // Clear while in flight
        deferred.clear()

        #expect(deferred.hasInFlightTask == false)

        // Start a new task - this should be allowed now
        let task2 = deferred.getOrPut(Task {
            counter.increment()
            return 2
        })

        let result2 = await task2.value
        #expect(result2 == 2)

        // Original task still completes (not cancelled)
        let result1 = await task1.value
        #expect(result1 == 1)

        // Both tasks executed
        #expect(counter.value == 2)
    }

    @Test("hasInFlightTask reflects current state")
    func hasInFlightTask_reflectsState() async {
        let deferred = DeferredTask<Int>()

        #expect(deferred.hasInFlightTask == false)

        let task = deferred.getOrPut(Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            return 42
        })

        #expect(deferred.hasInFlightTask == true)

        _ = await task.value
        await yield()

        #expect(deferred.hasInFlightTask == false)
    }
}

/// Thread-safe counter for testing
@MainActor
final class Counter: @unchecked Sendable {
    private var _value = 0
    var value: Int { _value }
    func increment() { _value += 1 }
}
