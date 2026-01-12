//
//  ResponseFetcher.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/11/26.
//

import Foundation

public protocol ResponseFetching: Sendable {
    func fetch(url: URL) async throws -> VersionLockoutResponse
}

public struct ResponseFetcher: ResponseFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(url: URL) async throws -> VersionLockoutResponse {
        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ResponseError(statusCode: http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(VersionLockoutResponse.self, from: data)
    }
}
