//
//  VersionLockoutViewModelTests.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/11/26.
//

import Foundation
import Testing
@testable import VersionLockout

final class FetcherSpy: ResponseFetching, @unchecked Sendable {
    enum Behavior: Sendable {
        case succeed(VersionLockoutResponse)
        case fail(any Error)
        case delayedSucceed(VersionLockoutResponse, nanos: UInt64)
        case delayedFail(any Error, nanos: UInt64)
    }

    private let behavior: Behavior

    // Mutated only from main actor in these tests (by your guarantee)
    private(set) var callCount: Int = 0
    private(set) var lastURL: URL?

    init(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func fetch(url: URL) async throws -> VersionLockoutResponse {
        // This runs on main actor per your guarantee (VM is @MainActor in prod)
        callCount += 1
        lastURL = url

        switch behavior {
        case .succeed(let response):
            return response

        case .fail(let error):
            throw error

        case .delayedSucceed(let response, let nanos):
            try await Task.sleep(nanoseconds: nanos)
            return response

        case .delayedFail(let error, let nanos):
            try await Task.sleep(nanoseconds: nanos)
            throw error
        }
    }
}

final class StatusCalculatorSpy: StatusCalculating, @unchecked Sendable {
    private(set) var callCount: Int = 0
    private(set) var lastResponse: VersionLockoutResponse?
    private(set) var lastAppVersion: String?

    let result: VersionLockoutStatus

    init(result: VersionLockoutStatus) {
        self.result = result
    }

    func calculate(response: VersionLockoutResponse, appVersion: String) -> VersionLockoutStatus {
        // Called on main actor per your guarantee
        callCount += 1
        lastResponse = response
        lastAppVersion = appVersion
        return result
    }
}

struct FixedAppVersionProvider: AppVersionProviding {
    let version: String
    func appVersionString() -> String { version }
}

final class InMemoryLastFetchStorage: LastFetchStoring, @unchecked Sendable {
    private(set) var storedDate: Date?
    private(set) var setCallCount: Int = 0

    init(storedDate: Date? = nil) {
        self.storedDate = storedDate
    }

    func lastFetchDate() -> Date? { storedDate }

    func setLastFetchDate(_ date: Date) {
        setCallCount += 1
        storedDate = date
    }
}

private enum TestError: Error { case boom }

@MainActor
struct VersionLockoutViewModelTests {
    private func makeResponse(
        recommendedVersion: String = "3.0.0",
        requiredVersion: String = "2.0.0",
        updateUrl: URL = URL(string: "https://example.com/update")!,
        eol: Bool = false,
        message: String? = "ok"
    ) -> VersionLockoutResponse {
        VersionLockoutResponse(
            recommendedVersion: recommendedVersion,
            requiredVersion: requiredVersion,
            updateUrl: updateUrl,
            eol: eol,
            message: message
        )
    }

    @Test("refreshStatus success: sets response and status")
    func refreshStatusSuccess_setsResponseAndStatus() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse(message: "ok")

        let expectedStatus: VersionLockoutStatus = .recommended(response.updateUrl)

        let fetcher = FetcherSpy(.succeed(response))
        let calculator = StatusCalculatorSpy(result: expectedStatus)
        let appVersionProvider = FixedAppVersionProvider(version: "1.2.3")

        let vm = VersionLockoutViewModel(
            url,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: appVersionProvider
        )

        await vm.refreshStatus()

        #expect(vm.isLoading == false)
        #expect(vm.response == response)
        #expect(vm.status == expectedStatus)

        #expect(fetcher.callCount == 1)
        #expect(fetcher.lastURL == url)

        #expect(calculator.callCount == 1)
        #expect(calculator.lastResponse == response)
        #expect(calculator.lastAppVersion == "1.2.3")
    }

    @Test("refreshStatus failure: fails open to .upToDate and does not call calculator")
    func refreshStatusFailure_failsOpen() async {
        let url = URL(string: "https://example.com/lockout.json")!

        let fetcher = FetcherSpy(.fail(TestError.boom))
        let calculator = StatusCalculatorSpy(result: .required(URL(string: "https://should-not-be-used.example")!))
        let appVersionProvider = FixedAppVersionProvider(version: "1.2.3")

        let vm = VersionLockoutViewModel(
            url,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: appVersionProvider
        )

        await vm.refreshStatus()

        #expect(vm.isLoading == false)
        #expect(vm.response == nil)
        #expect(vm.status == .upToDate)

        #expect(fetcher.callCount == 1)
        #expect(calculator.callCount == 0)
    }

    @Test("refreshStatus toggles isLoading while awaiting fetch")
    func refreshStatus_togglesLoading() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()
        let expectedStatus: VersionLockoutStatus = .upToDate

        let fetcher = FetcherSpy(.delayedSucceed(response, nanos: 150_000_000)) // 0.15s
        let calculator = StatusCalculatorSpy(result: expectedStatus)
        let appVersionProvider = FixedAppVersionProvider(version: "1.0.0")

        let vm = VersionLockoutViewModel(
            url,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: appVersionProvider
        )

        async let work: Void = vm.refreshStatus()

        await Task.yield()
        #expect(vm.isLoading == true)

        await work
        #expect(vm.isLoading == false)
    }

    @Test("concurrent refreshStatus calls await the same in-flight task")
    func refreshStatus_concurrentCallsAwaitSameTask() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()
        let expectedStatus: VersionLockoutStatus = .upToDate

        let fetcher = FetcherSpy(.delayedSucceed(response, nanos: 200_000_000)) // 0.2s
        let calculator = StatusCalculatorSpy(result: expectedStatus)
        let appVersionProvider = FixedAppVersionProvider(version: "1.0.0")

        let vm = VersionLockoutViewModel(
            url,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: appVersionProvider
        )

        async let first: Void = vm.refreshStatus()
        await Task.yield()

        await vm.refreshStatus() // awaits the same in-flight task

        await first

        // Only one fetch and calculation, even with concurrent calls
        #expect(fetcher.callCount == 1)
        #expect(calculator.callCount == 1)
        // Both callers see the result
        #expect(vm.status == expectedStatus)
    }

    @Test("refreshStatus passes appVersion from provider to calculator")
    func refreshStatus_passesAppVersionToCalculator() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let fetcher = FetcherSpy(.succeed(response))
        let calculator = StatusCalculatorSpy(result: .upToDate)
        let appVersionProvider = FixedAppVersionProvider(version: "2026.01.14")

        let vm = VersionLockoutViewModel(
            url,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: appVersionProvider
        )

        await vm.refreshStatus()

        #expect(calculator.lastAppVersion == "2026.01.14")
    }

    // MARK: - Caching Tests

    @Test("refreshStatusIfNeeded skips fetch when within refresh interval")
    func refreshStatusIfNeeded_skipsWhenWithinInterval() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let now = Date()
        let lastFetch = now.addingTimeInterval(-1 * 3600) // 1 hour ago

        let fetcher = FetcherSpy(.succeed(response))
        let calculator = StatusCalculatorSpy(result: .upToDate)
        let storage = InMemoryLastFetchStorage(storedDate: lastFetch)

        let vm = VersionLockoutViewModel(
            url,
            refreshIntervalHours: 3,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0"),
            dateProvider: { now },
            lastFetchStorage: storage
        )

        await vm.refreshStatusIfNeeded()

        #expect(fetcher.callCount == 0)
    }

    @Test("refreshStatusIfNeeded fetches when past refresh interval")
    func refreshStatusIfNeeded_fetchesWhenPastInterval() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let now = Date()
        let lastFetch = now.addingTimeInterval(-4 * 3600) // 4 hours ago

        let fetcher = FetcherSpy(.succeed(response))
        let calculator = StatusCalculatorSpy(result: .upToDate)
        let storage = InMemoryLastFetchStorage(storedDate: lastFetch)

        let vm = VersionLockoutViewModel(
            url,
            refreshIntervalHours: 3,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0"),
            dateProvider: { now },
            lastFetchStorage: storage
        )

        await vm.refreshStatusIfNeeded()

        #expect(fetcher.callCount == 1)
    }

    @Test("refreshStatusIfNeeded fetches at exact refresh interval boundary")
    func refreshStatusIfNeeded_fetchesAtExactBoundary() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let now = Date()
        let lastFetch = now.addingTimeInterval(-3 * 3600) // exactly 3 hours ago

        let fetcher = FetcherSpy(.succeed(response))
        let calculator = StatusCalculatorSpy(result: .upToDate)
        let storage = InMemoryLastFetchStorage(storedDate: lastFetch)

        let vm = VersionLockoutViewModel(
            url,
            refreshIntervalHours: 3,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0"),
            dateProvider: { now },
            lastFetchStorage: storage
        )

        await vm.refreshStatusIfNeeded()

        #expect(fetcher.callCount == 1)
    }

    @Test("refreshStatusIfNeeded fetches when no previous fetch recorded")
    func refreshStatusIfNeeded_fetchesWhenNoPreviousFetch() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let now = Date()

        let fetcher = FetcherSpy(.succeed(response))
        let calculator = StatusCalculatorSpy(result: .upToDate)
        let storage = InMemoryLastFetchStorage(storedDate: nil)

        let vm = VersionLockoutViewModel(
            url,
            refreshIntervalHours: 3,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0"),
            dateProvider: { now },
            lastFetchStorage: storage
        )

        await vm.refreshStatusIfNeeded()

        #expect(fetcher.callCount == 1)
    }

    @Test("refreshStatus saves fetch date after successful fetch")
    func refreshStatus_savesFetchDateOnSuccess() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let now = Date()

        let fetcher = FetcherSpy(.succeed(response))
        let calculator = StatusCalculatorSpy(result: .upToDate)
        let storage = InMemoryLastFetchStorage(storedDate: nil)

        let vm = VersionLockoutViewModel(
            url,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0"),
            dateProvider: { now },
            lastFetchStorage: storage
        )

        await vm.refreshStatus()

        #expect(storage.setCallCount == 1)
        #expect(storage.storedDate == now)
    }

    @Test("refreshStatus does not save fetch date on failure")
    func refreshStatus_doesNotSaveFetchDateOnFailure() async {
        let url = URL(string: "https://example.com/lockout.json")!

        let now = Date()

        let fetcher = FetcherSpy(.fail(TestError.boom))
        let calculator = StatusCalculatorSpy(result: .upToDate)
        let storage = InMemoryLastFetchStorage(storedDate: nil)

        let vm = VersionLockoutViewModel(
            url,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0"),
            dateProvider: { now },
            lastFetchStorage: storage
        )

        await vm.refreshStatus()

        #expect(storage.setCallCount == 0)
        #expect(storage.storedDate == nil)
    }

    // MARK: - Loading State Tests

    @Test("isLoading is true on initial load when status is nil")
    func isLoading_trueOnInitialLoad() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let fetcher = FetcherSpy(.delayedSucceed(response, nanos: 100_000_000))
        let calculator = StatusCalculatorSpy(result: .upToDate)

        let vm = VersionLockoutViewModel(
            url,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0")
        )

        #expect(vm.status == nil)

        async let work: Void = vm.refreshStatus()
        await Task.yield()

        #expect(vm.isLoading == true)

        await work
    }

    @Test("isLoading is false on refresh when showLoadingOnRefresh is false (default)")
    func isLoading_falseOnRefresh_whenOptionDisabled() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let fetcher = FetcherSpy(.delayedSucceed(response, nanos: 100_000_000))
        let calculator = StatusCalculatorSpy(result: .upToDate)

        let vm = VersionLockoutViewModel(
            url,
            showLoadingOnRefresh: false,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0")
        )

        // Complete initial load
        await vm.refreshStatus()
        #expect(vm.status == .upToDate)
        #expect(vm.isLoading == false)

        // Now do a refresh - isLoading should stay false
        async let work: Void = vm.refreshStatus()
        await Task.yield()

        #expect(vm.isLoading == false)

        await work
    }

    @Test("isLoading is true on refresh when showLoadingOnRefresh is true")
    func isLoading_trueOnRefresh_whenOptionEnabled() async {
        let url = URL(string: "https://example.com/lockout.json")!
        let response = makeResponse()

        let fetcher = FetcherSpy(.delayedSucceed(response, nanos: 100_000_000))
        let calculator = StatusCalculatorSpy(result: .upToDate)

        let vm = VersionLockoutViewModel(
            url,
            showLoadingOnRefresh: true,
            fetcher: fetcher,
            statusCalculator: calculator,
            appVersionProvider: FixedAppVersionProvider(version: "1.0.0")
        )

        // Complete initial load
        await vm.refreshStatus()
        #expect(vm.status == .upToDate)
        #expect(vm.isLoading == false)

        // Now do a refresh - isLoading should be true
        async let work: Void = vm.refreshStatus()
        await Task.yield()

        #expect(vm.isLoading == true)

        await work
    }
}
