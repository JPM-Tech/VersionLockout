//
//  FixedAppVersionProvider.swift
//  VersionLockout
//
//  Created by Jacob Rakidzich on 1/16/26.
//

import Foundation
@testable import VersionLockout

struct FixedAppVersionProvider: AppVersionProviding {
    let version: String
    func appVersionString() -> String { version }
}
