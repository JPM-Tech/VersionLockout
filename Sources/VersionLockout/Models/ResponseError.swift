//
//  ResponseError.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/11/26.
//

import Foundation

public struct ResponseError: Error, Sendable, Equatable {
    public let statusCode: Int
    public init(statusCode: Int) { self.statusCode = statusCode }
}
