//
//  VersionLockoutStatus.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/9/26.
//

import Foundation

public enum VersionLockoutStatus: Sendable, Equatable {
    case upToDate
    case recommended(URL)
    case required(URL)
    case eol(String?)
}
