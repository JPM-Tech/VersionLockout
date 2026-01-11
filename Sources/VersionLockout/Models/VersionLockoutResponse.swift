//
//  VersionLockoutResponse.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/9/26.
//

import Foundation

public struct VersionLockoutResponse: Codable, Sendable, Equatable {
    public let recommendedVersion: String
    public let requiredVersion: String
    public let updateUrl: URL
    public let eol: Bool
    public let message: String?

    public init(
        recommendedVersion: String,
        requiredVersion: String,
        updateUrl: URL,
        eol: Bool = false,
        message: String? = nil
    ) {
        self.recommendedVersion = recommendedVersion
        self.requiredVersion = requiredVersion
        self.updateUrl = updateUrl
        self.eol = eol
        self.message = message
    }
    
    enum CodingKeys: String, CodingKey {
        case recommendedVersion, requiredVersion, updateUrl, eol, message
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recommendedVersion = try c.decode(String.self, forKey: .recommendedVersion)
        requiredVersion = try c.decode(String.self, forKey: .requiredVersion)
        eol = try c.decode(Bool.self, forKey: .eol)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        
        let urlString = try c.decode(String.self, forKey: .updateUrl)
        
        if let url = URL(string: urlString), url.scheme != nil {
            updateUrl = url
        } else {
            // choose your own base (or throw)
            throw DecodingError.dataCorruptedError(
                forKey: .updateUrl,
                in: c,
                debugDescription: "updateUrl must be an absolute URL string"
            )
        }
    }
}
