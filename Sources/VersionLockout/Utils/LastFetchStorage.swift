//
//  LastFetchStorage.swift
//  VersionLockout
//
//  Created by Jacob Zivan Rakidzich on 1/16/26.
//

import Foundation

public protocol LastFetchStoring: Sendable {
    func lastFetchDate() -> Date?
    func setLastFetchDate(_ date: Date)
}

public final class UserDefaultsLastFetchStorage: LastFetchStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "VersionLockout.lastFetchDate") {
        self.defaults = defaults
        self.key = key
    }

    public func lastFetchDate() -> Date? {
        defaults.object(forKey: key) as? Date
    }

    public func setLastFetchDate(_ date: Date) {
        defaults.set(date, forKey: key)
    }
}
