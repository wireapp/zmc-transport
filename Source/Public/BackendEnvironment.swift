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

let log = ZMSLog(tag: "backend-environment")

public enum EnvironmentType: Equatable {
    case production
    case staging
    case custom(host: String)

    var stringValue: String {
        switch self {
        case .production:
            return "production"
        case .staging:
            return "staging"
        case .custom(host: let host):
            return "custom-\(host)"
        }
    }

    init(stringValue: String) {
        switch stringValue {
        case EnvironmentType.staging.stringValue:
            self = .staging
        case _ where stringValue.starts(with: "custom-"):
            let host = stringValue.dropFirst("custom-".count)
            self = .custom(host: String(host))
        default:
            self = .production
        }
    }

    private static let defaultsKey = "ZMBackendEnvironmentType"
    
    public init(userDefaults: UserDefaults) {
        if let value = userDefaults.string(forKey: EnvironmentType.defaultsKey) {
            self.init(stringValue: value)
        } else {
            self = .production
        }
    }
    
    public func save(in userDefaults: UserDefaults) {
        userDefaults.setValue(self.stringValue, forKey: EnvironmentType.defaultsKey)
    }
}

public class BackendEnvironment: NSObject {
    let endpoints: BackendEndpointsProvider
    let certificateTrust: BackendTrustProvider
    let type: EnvironmentType
    
    init(environmentType: EnvironmentType, endpoints: BackendEndpointsProvider, certificateTrust: BackendTrustProvider) {
        self.type = environmentType
        self.endpoints = endpoints
        self.certificateTrust = certificateTrust
    }
    
    public convenience init?(host: String) {
        guard let endpoints = BackendEndpoints(host: host) else { return nil }
        let type = EnvironmentType.custom(host: host)
        self.init(environmentType: type, endpoints: endpoints, certificateTrust: ServerCertificateTrust(trustData: []))
    }
    
    // Will try to deserialize backend environment from .json files inside configurationBundle.
    public static func from(environmentType: EnvironmentType, configurationBundle: Bundle) -> BackendEnvironment? {        
        struct SerializedData: Decodable {
            let endpoints: BackendEndpoints
            let pinnedKeys: [TrustData]?
        }

        guard let path = configurationBundle.path(forResource: environmentType.stringValue, ofType: "json") else {
            log.error("Could not find \(environmentType.stringValue).json inside bundle \(configurationBundle)")
            return nil 
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { 
            log.error("Could not read \(environmentType.stringValue).json")
            return nil 
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let backendData = try decoder.decode(SerializedData.self, from: data)
            let pinnedKeys = backendData.pinnedKeys ?? []
            let certificateTrust = ServerCertificateTrust(trustData: pinnedKeys)
            return BackendEnvironment(environmentType: environmentType, endpoints: backendData.endpoints, certificateTrust: certificateTrust)
        } catch {
            log.error("Could decode information from \(environmentType.stringValue).json")
            return nil
        }
    }

}

extension BackendEnvironment: BackendEnvironmentProvider {
    public var environmentType: EnvironmentTypeProvider {
        return EnvironmentTypeProvider(environmentType: type)
    }
    
    public var backendURL: URL {
        return endpoints.backendURL
    }
    
    public var backendWSURL: URL {
        return endpoints.backendWSURL
    }
    
    public var blackListURL: URL {
        return endpoints.blackListURL
    }
    
    public var frontendURL: URL {
        return endpoints.frontendURL
    }
    
    public func verifyServerTrust(trust: SecTrust, host: String?) -> Bool {
        return certificateTrust.verifyServerTrust(trust: trust, host: host)
    }
}
