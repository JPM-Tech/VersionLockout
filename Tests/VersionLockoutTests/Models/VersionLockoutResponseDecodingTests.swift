//
//  VersionLockoutResponseDecodingTests.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/11/26.
//

import Foundation
import Testing
@testable import VersionLockout

struct VersionLockoutResponseDecodingTests {
    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    @Test("Decodes valid response (snake_case keys) and absolute update_url")
    func decodesValidSnakeCase() throws {
        let json = """
        {
          "recommended_version": "3.0.0",
          "required_version": "2.0.0",
          "update_url": "https://example.com/update",
          "eol": false,
          "message": "ok"
        }
        """
        let data = Data(json.utf8)

        let decoded = try makeDecoder().decode(VersionLockoutResponse.self, from: data)

        #expect(decoded.recommendedVersion == "3.0.0")
        #expect(decoded.requiredVersion == "2.0.0")
        #expect(decoded.updateUrl == URL(string: "https://example.com/update")!)
        #expect(decoded.eol == false)
        #expect(decoded.message == "ok")
    }

    @Test("message omitted decodes as nil")
    func messageOmittedIsNil() throws {
        let json = """
        {
          "recommended_version": "3.0.0",
          "required_version": "2.0.0",
          "update_url": "https://example.com/update",
          "eol": false
        }
        """
        let data = Data(json.utf8)

        let decoded = try makeDecoder().decode(VersionLockoutResponse.self, from: data)

        #expect(decoded.message == nil)
    }

    @Test("message null decodes as nil")
    func messageNullIsNil() throws {
        let json = """
        {
          "recommended_version": "3.0.0",
          "required_version": "2.0.0",
          "update_url": "https://example.com/update",
          "eol": false,
          "message": null
        }
        """
        let data = Data(json.utf8)

        let decoded = try makeDecoder().decode(VersionLockoutResponse.self, from: data)

        #expect(decoded.message == nil)
    }

    @Test("Decoding fails when update_url is relative")
    func updateUrlRelativeThrows() throws {
        let json = """
        {
          "recommended_version": "3.0.0",
          "required_version": "2.0.0",
          "update_url": "/update",
          "eol": false
        }
        """
        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try makeDecoder().decode(VersionLockoutResponse.self, from: data)
        }
    }

    @Test("Decoding fails when update_url has no scheme")
    func updateUrlNoSchemeThrows() throws {
        let json = """
        {
          "recommended_version": "3.0.0",
          "required_version": "2.0.0",
          "update_url": "example.com/update",
          "eol": false
        }
        """
        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try makeDecoder().decode(VersionLockoutResponse.self, from: data)
        }
    }

    @Test("Decoding fails when update_url is null")
    func updateUrlNullThrows() throws {
        let json = """
        {
          "recommended_version": "3.0.0",
          "required_version": "2.0.0",
          "update_url": null,
          "eol": false
        }
        """
        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try makeDecoder().decode(VersionLockoutResponse.self, from: data)
        }
    }

    @Test("Decoding fails when required key is missing (required_version)")
    func missingRequiredVersionThrows() throws {
        let json = """
        {
          "recommended_version": "3.0.0",
          "update_url": "https://example.com/update",
          "eol": false
        }
        """
        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try makeDecoder().decode(VersionLockoutResponse.self, from: data)
        }
    }

    @Test("Decoding fails when types are wrong (eol is string)")
    func wrongTypeThrows() throws {
        let json = """
        {
          "recommended_version": "3.0.0",
          "required_version": "2.0.0",
          "update_url": "https://example.com/update",
          "eol": "false"
        }
        """
        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try makeDecoder().decode(VersionLockoutResponse.self, from: data)
        }
    }
}

