//
//  StatusCalculatorTests.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/11/26.
//

import Foundation
import Testing
@testable import VersionLockout

struct StatusCalculatorTests {
    struct VersionCase: Sendable {
        let name: String
        let appVersion: String
        let required: String
        let recommended: String
    }

    static let eolCases: [VersionCase] = [
        .init(name: "semver", appVersion: "0.0.1", required: "999.0.0", recommended: "999.0.0"),
        .init(name: "date",  appVersion: "2026.01.14", required: "2099.01.01", recommended: "2099.01.02"),
    ]

    static let belowRequiredCases: [VersionCase] = [
        .init(name: "semver", appVersion: "1.9.9", required: "2.0.0", recommended: "3.0.0"),
        .init(name: "date",  appVersion: "2026.01.14", required: "2026.01.15", recommended: "2026.02.01"),
    ]

    static let belowRecommendedCases: [VersionCase] = [
        .init(name: "semver", appVersion: "2.5.0", required: "2.0.0", recommended: "3.0.0"),
        .init(name: "date",  appVersion: "2026.01.20", required: "2026.01.15", recommended: "2026.02.01"),
    ]

    static let atOrAboveRecommendedCases: [VersionCase] = [
        .init(name: "semver", appVersion: "3.0.0", required: "2.0.0", recommended: "3.0.0"),
        .init(name: "date",  appVersion: "2026.02.01", required: "2026.01.15", recommended: "2026.02.01"),
    ]

    static let appEqualRequiredCases: [VersionCase] = [
        .init(name: "semver", appVersion: "2.0.0", required: "2.0.0", recommended: "2.1.0"),
        .init(name: "date",  appVersion: "2026.01.15", required: "2026.01.15", recommended: "2026.01.16"),
    ]

    static let appEqualRecommendedCases: [VersionCase] = [
        .init(name: "semver", appVersion: "2.1.0", required: "2.0.0", recommended: "2.1.0"),
        .init(name: "date",  appVersion: "2026.01.16", required: "2026.01.15", recommended: "2026.01.16"),
    ]

    static let requiredPriorityCases: [VersionCase] = [
        .init(name: "semver", appVersion: "1.0.0", required: "5.0.0", recommended: "6.0.0"),
        .init(name: "date",  appVersion: "2026.01.01", required: "2026.02.01", recommended: "2026.03.01"),
    ]
    
    private func makeResponse(
        eol: Bool = false,
        message: String = "EOL message",
        required: String = "2.0.0",
        recommended: String = "3.0.0",
        updateUrl: URL = URL(string: "https://example.com/update")!
    ) -> VersionLockoutResponse {
        VersionLockoutResponse(
            recommendedVersion: recommended,
            requiredVersion: required,
            updateUrl: updateUrl,
            eol: eol,
            message: message
        )
    }

    @Test("EOL returns .eol(message) regardless of versions", arguments: StatusCalculatorTests.eolCases)
    func eolReturnsEol(_ c: VersionCase) throws {
        let calc = StatusCalculator()
        let response = makeResponse(
            eol: true,
            message: "App is end-of-life",
            required: c.required,
            recommended: c.recommended
        )

        let status = calc.calculate(response: response, appVersion: c.appVersion)
        #expect(status == .eol("App is end-of-life"), Comment(rawValue: c.name))
    }

    @Test("App below required returns .required(updateUrl)", arguments: StatusCalculatorTests.belowRequiredCases)
    func belowRequiredReturnsRequired(_ c: VersionCase) throws {
        let calc = StatusCalculator()
        let url = URL(string: "https://example.com/update")!
        let response = makeResponse(required: c.required, recommended: c.recommended, updateUrl: url)

        let status = calc.calculate(response: response, appVersion: c.appVersion)
        #expect(status == .required(url), Comment(rawValue: c.name))
    }

    @Test("App below recommended but >= required returns .recommended(updateUrl)", arguments: StatusCalculatorTests.belowRecommendedCases)
    func belowRecommendedReturnsRecommended(_ c: VersionCase) throws {
        let calc = StatusCalculator()
        let url = URL(string: "https://example.com/update")!
        let response = makeResponse(required: c.required, recommended: c.recommended, updateUrl: url)

        let status = calc.calculate(response: response, appVersion: c.appVersion)
        #expect(status == .recommended(url), Comment(rawValue: c.name))
    }

    @Test("App >= recommended returns .upToDate", arguments: StatusCalculatorTests.atOrAboveRecommendedCases)
    func atOrAboveRecommendedReturnsUpToDate(_ c: VersionCase) throws {
        let calc = StatusCalculator()
        let response = makeResponse(required: c.required, recommended: c.recommended)

        // exact == recommended
        let statusAt = calc.calculate(response: response, appVersion: c.appVersion)
        #expect(statusAt == .upToDate, Comment(rawValue: "\(c.name) (at recommended)"))

        // "above" recommended: bump patch for semver; bump day for date-style
        let aboveVersion: String = {
            if c.name == "semver" {
                return "3.0.1"
            } else {
                return "2026.02.02"
            }
        }()

        let statusAbove = calc.calculate(response: response, appVersion: aboveVersion)
        #expect(statusAbove == .upToDate, Comment(rawValue: "\(c.name) (above recommended)"))
    }

    @Test("Boundary: app == required is NOT required (falls through to recommended check)", arguments: StatusCalculatorTests.appEqualRequiredCases)
    func appEqualRequiredNotRequired(_ c: VersionCase) throws {
        let calc = StatusCalculator()
        let url = URL(string: "https://example.com/update")!
        let response = makeResponse(required: c.required, recommended: c.recommended, updateUrl: url)

        let status = calc.calculate(response: response, appVersion: c.appVersion)

        // Since app == required, it's not < required.
        // But app < recommended, so it should recommend.
        #expect(status == .recommended(url), Comment(rawValue: c.name))
    }

    @Test("Boundary: app == recommended is upToDate", arguments: StatusCalculatorTests.appEqualRecommendedCases)
    func appEqualRecommendedUpToDate(_ c: VersionCase) throws {
        let calc = StatusCalculator()
        let response = makeResponse(required: c.required, recommended: c.recommended)

        let status = calc.calculate(response: response, appVersion: c.appVersion)
        #expect(status == .upToDate, Comment(rawValue: c.name))
    }

    @Test("Recommended check never overrides required: if app < required, required wins", arguments: StatusCalculatorTests.requiredPriorityCases)
    func requiredTakesPriorityOverRecommended(_ c: VersionCase) throws {
        let calc = StatusCalculator()
        let url = URL(string: "https://example.com/update")!
        let response = makeResponse(required: c.required, recommended: c.recommended, updateUrl: url)

        let status = calc.calculate(response: response, appVersion: c.appVersion)
        #expect(status == .required(url), Comment(rawValue: c.name))
    }
}
