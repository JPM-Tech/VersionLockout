//
//  StatusCalculatorSpy.swift
//  VersionLockout
//
//  Created by Jacob Rakidzich on 1/16/26.
//

import Foundation
@testable import VersionLockout

final class StatusCalculatorSpy: StatusCalculating, @unchecked Sendable {
    private(set) var callCount: Int = 0
    private(set) var lastResponse: VersionLockoutResponse?
    private(set) var lastAppVersion: String?

    let result: VersionLockoutStatus

    init(result: VersionLockoutStatus) {
        self.result = result
    }

    func calculate(response: VersionLockoutResponse, appVersion: String) -> VersionLockoutStatus {
        callCount += 1
        lastResponse = response
        lastAppVersion = appVersion
        return result
    }
}
