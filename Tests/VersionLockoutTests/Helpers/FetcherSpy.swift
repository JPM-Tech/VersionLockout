//
//  FetcherSpy.swift
//  VersionLockout
//
//  Created by Jacob Rakidzich on 1/16/26.
//

import Foundation
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
