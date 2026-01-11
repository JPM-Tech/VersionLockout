//
//  File.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/11/26.
//

import Foundation

public protocol StatusCalculating: Sendable {
    func calculate(response: VersionLockoutResponse, appVersion: String) -> VersionLockoutStatus
}

public struct StatusCalculator: StatusCalculating {
    public init() {}

    public func calculate(
        response: VersionLockoutResponse,
        appVersion: String
    ) -> VersionLockoutStatus {
        if response.eol {
            return .eol(response.message)
        }

        if appVersion < response.requiredVersion {
            return .required(response.updateUrl)
        }
        if appVersion < response.recommendedVersion {
            return .recommended(response.updateUrl)
        }
        return .upToDate
    }
}
