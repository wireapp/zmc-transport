//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

@objc public enum EnvironmentType: Int {
    case production
    case staging

    var stringValue: String {
        switch self {
        case .production:
            return "production"
        case .staging:
            return "staging"
        }
    }

    init(stringValue: String) {
        switch stringValue {
        case EnvironmentType.staging.stringValue:
            self = .staging
        default:
            self = .production
        }
    }

    public init(userDefaults: UserDefaults) {
        if let value = userDefaults.string(forKey: "ZMBackendEnvironmentType") {
            self.init(stringValue: value)
        } else {
            self = .production
        }
    }
}

// Swift migration notice: this class conforms to NSObject only to be usable from Obj-C.
@objcMembers
public class BackendEnvironment: NSObject, BackendEnvironmentProvider, Decodable {
    
    public let backendURL: URL
    public let backendWSURL: URL
    public let blackListURL: URL
    public let frontendURL: URL
    let trustData: [TrustData]

    public convenience init(backendURL: URL, backendWSURL: URL, blackListURL: URL, frontendURL: URL) {
        self.init(backendURL: backendURL, backendWSURL: backendWSURL, blackListURL: blackListURL, frontendURL: frontendURL, trustData: [])
    }
    
    init(backendURL: URL, backendWSURL: URL, blackListURL: URL, frontendURL: URL, trustData: [TrustData]) {
        self.backendURL   = backendURL
        self.backendWSURL = backendWSURL
        self.blackListURL = blackListURL
        self.frontendURL  = frontendURL
        self.trustData = trustData
        super.init()
    }

    // Will try to deserialize backend environment from .json files inside configurationBundle.
    public static func from(environmentType: EnvironmentType, configurationBundle: Bundle) -> Self? {
        guard let path = configurationBundle.path(forResource: environmentType.stringValue, ofType: "json") else { return nil }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .base64
        return try? decoder.decode(self, from: data)
    }
    
    public func verifyServerTrust(trust: SecTrust, host: String?) -> Bool {
        guard let host = host else { return false }
        let pinnedKeys = trustData
            .lazy
            .filter { trust in
                trust.matches(host: host)
            }
            .compactMap { trust in
                trust.certificateKey
            }
            .prefix(upTo: 1)

        return verifyServerTrustWithPinnedKeys(trust, Array(pinnedKeys))
    }
}
