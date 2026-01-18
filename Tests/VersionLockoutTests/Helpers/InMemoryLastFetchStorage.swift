//
//  InMemoryLastFetchStorage.swift
//  VersionLockout
//
//  Created by Jacob Rakidzich on 1/16/26.
//

import Foundation
@testable import VersionLockout

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
