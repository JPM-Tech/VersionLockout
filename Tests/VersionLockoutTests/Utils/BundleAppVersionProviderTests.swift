//
//  BundleAppVersionProviderTests.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/11/26.
//

import Foundation
import Testing
@testable import VersionLockout

/// A tiny Bundle stub that lets us control Info.plist keys.
/// We override object(forInfoDictionaryKey:) only.
final class StubBundle: Bundle, @unchecked Sendable {
    private let values: [String: Any]

    init(_ values: [String: Any]) {
        self.values = values
        super.init()
    }

    override func object(forInfoDictionaryKey key: String) -> Any? {
        values[key]
    }
}

struct BundleAppVersionProviderTests {
    @Test("Prefers CFBundleShortVersionString when present")
    func prefersShortVersionString() throws {
        let bundle = StubBundle([
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "999"
        ])

        let sut = BundleAppVersionProvider(bundle: bundle, fallback: "0.0.0")
        #expect(sut.appVersionString() == "1.2.3")
    }

    @Test("Trims CFBundleShortVersionString and still prefers it if non-empty")
    func trimsShortVersionString() throws {
        let bundle = StubBundle([
            "CFBundleShortVersionString": "  2.0.1 \n",
            "CFBundleVersion": "999"
        ])

        let sut = BundleAppVersionProvider(bundle: bundle, fallback: "0.0.0")
        #expect(sut.appVersionString() == "  2.0.1 \n") // provider returns original string, just checks emptiness after trimming
    }

    @Test("Falls back to CFBundleVersion when short version is missing")
    func fallsBackToBuildWhenShortMissing() throws {
        let bundle = StubBundle([
            "CFBundleVersion": "123"
        ])

        let sut = BundleAppVersionProvider(bundle: bundle, fallback: "0.0.0")
        #expect(sut.appVersionString() == "123")
    }

    @Test("Falls back to CFBundleVersion when short version is empty/whitespace")
    func fallsBackToBuildWhenShortEmpty() throws {
        let bundle = StubBundle([
            "CFBundleShortVersionString": "   \n",
            "CFBundleVersion": "456"
        ])

        let sut = BundleAppVersionProvider(bundle: bundle, fallback: "0.0.0")
        #expect(sut.appVersionString() == "456")
    }

    @Test("Uses fallback when both CFBundleShortVersionString and CFBundleVersion are missing")
    func usesFallbackWhenBothMissing() throws {
        let bundle = StubBundle([:])

        let sut = BundleAppVersionProvider(bundle: bundle, fallback: "9.9.9")
        #expect(sut.appVersionString() == "9.9.9")
    }

    @Test("Uses fallback when both CFBundleShortVersionString and CFBundleVersion are empty/whitespace")
    func usesFallbackWhenBothEmpty() throws {
        let bundle = StubBundle([
            "CFBundleShortVersionString": " ",
            "CFBundleVersion": "\n\t"
        ])

        let sut = BundleAppVersionProvider(bundle: bundle, fallback: "0.0.0")
        #expect(sut.appVersionString() == "0.0.0")
    }

    @Test("Does not treat non-String values as valid; falls back appropriately")
    func ignoresNonStringValues() throws {
        let bundle = StubBundle([
            "CFBundleShortVersionString": 123, // not a String
            "CFBundleVersion": 456           // not a String
        ])

        let sut = BundleAppVersionProvider(bundle: bundle, fallback: "0.0.0")
        #expect(sut.appVersionString() == "0.0.0")
    }

    @Test("Falls back to CFBundleVersion if short version is non-String but build is valid String")
    func shortNonStringBuildValid() throws {
        let bundle = StubBundle([
            "CFBundleShortVersionString": 123,
            "CFBundleVersion": "789"
        ])

        let sut = BundleAppVersionProvider(bundle: bundle, fallback: "0.0.0")
        #expect(sut.appVersionString() == "789")
    }
}
