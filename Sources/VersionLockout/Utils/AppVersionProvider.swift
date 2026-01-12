//
//  File.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/9/26.
//

import Foundation

public protocol AppVersionProviding: Sendable {
    func appVersionString() -> String
}

public struct BundleAppVersionProvider: AppVersionProviding {
    private let bundle: Bundle
    private let fallback: String

    /// - Parameters:
    ///   - bundle: Bundle to read from (default: .main)
    ///   - fallback: Used if the bundle has no readable version info (default: "0.0.0")
    public init(bundle: Bundle = .main, fallback: String = "0.0.0") {
        self.bundle = bundle
        self.fallback = fallback
    }

    public func appVersionString() -> String {
        // Prefer marketing version (e.g., 1.2.3)
        if let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !short.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return short
        }

        // Fallback to build number (e.g., 123)
        if let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !build.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return build
        }

        return fallback
    }
}
