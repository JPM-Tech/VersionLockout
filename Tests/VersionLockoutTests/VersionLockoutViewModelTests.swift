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

    @Test("refreshStatus is gated by isLoading: second call while loading returns early")
    func refreshStatus_gatePreventsDoubleFetch() async {
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

        await vm.refreshStatus() // should early-return

        await first

        #expect(fetcher.callCount == 1)
        #expect(calculator.callCount == 1)
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
}
