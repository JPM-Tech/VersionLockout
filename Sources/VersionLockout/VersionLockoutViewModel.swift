//
//  VersionLockoutViewModel.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/9/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class VersionLockoutViewModel {
    public let url: URL
    public var response: VersionLockoutResponse? = nil
    public var status: VersionLockoutStatus? = nil
    public private(set) var isLoading: Bool = false

    private let fetcher: ResponseFetching
    private let statusCalculator: StatusCalculating
    private let appVersionProvider: AppVersionProviding
    private let refreshIntervalHours: UInt
    private let showLoadingOnRefresh: Bool
    private let dateProvider: @Sendable () -> Date
    private let lastFetchStorage: LastFetchStoring

    private let refreshTask = DeferredTask<Void>()

    /// Creates a new VersionLockoutViewModel.
    /// - Parameters:
    ///   - versionLockoutURL: The URL to fetch version lockout data from.
    ///   - refreshIntervalHours: How often to re-fetch when app returns to foreground. Default is 3 hours.
    ///   - showLoadingOnRefresh: Whether to show loading state on subsequent refreshes. Default is `false`,
    ///     meaning loading state only shows on initial load when no status exists yet.
    ///   - fetcher: The response fetcher. Default uses `ResponseFetcher`.
    ///   - statusCalculator: The status calculator. Default uses `StatusCalculator`.
    ///   - appVersionProvider: The app version provider. Default uses `BundleAppVersionProvider`.
    ///   - dateProvider: Closure that returns the current date. Default uses `Date()`.
    ///   - lastFetchStorage: Storage for the last fetch timestamp. Default uses `UserDefaultsLastFetchStorage`.
    public init(
        _ versionLockoutURL: URL,
        refreshIntervalHours: UInt = 3,
        showLoadingOnRefresh: Bool = false,
        fetcher: ResponseFetching = ResponseFetcher(),
        statusCalculator: StatusCalculating = StatusCalculator(),
        appVersionProvider: AppVersionProviding = BundleAppVersionProvider(),
        dateProvider: @escaping @Sendable () -> Date = { Date() },
        lastFetchStorage: LastFetchStoring = UserDefaultsLastFetchStorage()
    ) {
        self.url = versionLockoutURL
        self.refreshIntervalHours = refreshIntervalHours
        self.showLoadingOnRefresh = showLoadingOnRefresh
        self.fetcher = fetcher
        self.statusCalculator = statusCalculator
        self.appVersionProvider = appVersionProvider
        self.dateProvider = dateProvider
        self.lastFetchStorage = lastFetchStorage
    }

    /// Call from `.task {}` or on app launch.
    /// Multiple concurrent calls will await the same in-flight request.
    public func refreshStatus() async {
        // Set loading state synchronously before any await.
        // Only the first caller sets this; subsequent callers find hasInFlightTask == true.
        if !refreshTask.hasInFlightTask {
            // Show loading if: no status yet (initial load), or showLoadingOnRefresh is enabled
            if status == nil || showLoadingOnRefresh {
                isLoading = true
            }
        }
        await refreshTask.getOrPut(Task { await self.performRefresh() }).value
    }

    private func performRefresh() async {
        defer { isLoading = false }

        do {
            response = try await fetcher.fetch(url: url)
            status = statusCalculator.calculate(
                response: response!,
                appVersion: appVersionProvider.appVersionString()
            )
            lastFetchStorage.setLastFetchDate(dateProvider())
        } catch {
            NSLog("VersionLockoutViewModel.refreshStatus error: %@", String(describing: error))
            // Fail open (safe)
            status = .upToDate
        }
    }

    /// Call when app returns to foreground. Only fetches if refresh interval has elapsed.
    public func refreshStatusIfNeeded() async {
        guard shouldRefresh() else { return }
        await refreshStatus()
    }

    private func shouldRefresh() -> Bool {
        guard let lastFetch = lastFetchStorage.lastFetchDate() else { return true }
        let elapsed = dateProvider().timeIntervalSince(lastFetch)
        let intervalSeconds = TimeInterval(refreshIntervalHours) * 3600
        return elapsed < 0 || elapsed >= intervalSeconds
    }
}
