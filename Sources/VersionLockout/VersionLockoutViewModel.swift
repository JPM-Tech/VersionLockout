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

    public init(
        _ versionLockoutURL: URL,
        fetcher: ResponseFetching = ResponseFetcher(),
        statusCalculator: StatusCalculating = StatusCalculator(),
        appVersionProvider: AppVersionProviding = BundleAppVersionProvider()
    ) {
        self.url = versionLockoutURL
        self.fetcher = fetcher
        self.statusCalculator = statusCalculator
        self.appVersionProvider = appVersionProvider
    }

    /// Call from `.task {}` or on app launch.
    public func refreshStatus() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await fetcher.fetch(url: url)
            status = statusCalculator.calculate(response: response!, appVersion: appVersionProvider.appVersionString())
        } catch {
            NSLog("VersionLockoutViewModel.refreshStatus error: %@", String(describing: error))
            // I want to fail open (safe)
            status = .upToDate
        }
    }
}
