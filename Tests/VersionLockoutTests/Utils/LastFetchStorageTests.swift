//
//  LastFetchStorageTests.swift
//  VersionLockout
//
//  Created by Jacob Zivan Rakidzich on 1/16/26.
//

import Foundation
import Testing
@testable import VersionLockout

struct LastFetchStorageTests {
    @Test("Returns nil when no date stored")
    func returnsNilWhenNoDateStored() {
        let defaults = UserDefaults(suiteName: "LastFetchStorageTests.nilTest")!
        defaults.removePersistentDomain(forName: "LastFetchStorageTests.nilTest")

        let storage = UserDefaultsLastFetchStorage(
            defaults: defaults,
            key: "test.lastFetchDate"
        )

        #expect(storage.lastFetchDate() == nil)
    }

    @Test("Stores and retrieves date correctly")
    func storesAndRetrievesDateCorrectly() {
        let defaults = UserDefaults(suiteName: "LastFetchStorageTests.storeTest")!
        defaults.removePersistentDomain(forName: "LastFetchStorageTests.storeTest")

        let storage = UserDefaultsLastFetchStorage(
            defaults: defaults,
            key: "test.lastFetchDate"
        )

        let date = Date(timeIntervalSince1970: 1700000000)
        storage.setLastFetchDate(date)

        let retrieved = storage.lastFetchDate()
        #expect(retrieved == date)
    }
}
