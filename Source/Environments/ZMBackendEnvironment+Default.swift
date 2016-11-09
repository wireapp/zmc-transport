//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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


extension ZMBackendEnvironment {
    
    public static func setupDefaultEnvironment() {
        ZMBackendEnvironment.setupEnvironment(of: .production, withBackendHost: "prod-nginz-https.wire.com", wsHost: "prod-nginz-ssl.wire.com", blackListEndpoint: "clientblacklist.wire.com/prod/ios", frontendHost: "wire.com")
        ZMBackendEnvironment.setupEnvironment(of: .staging, withBackendHost: "staging-nginz-https.zinfra.io", wsHost: "staging-nginz-ssl.zinfra.io", blackListEndpoint: "clientblacklist.wire.com/staging/ios", frontendHost: "edge-website.zinfra.io")
        ZMBackendEnvironment.setupEnvironment(of: .edge, withBackendHost: "edge-nginz-https.zinfra.io", wsHost: "edge-nginz-ssl.zinfra.io", blackListEndpoint: "clientblacklist.wire.com/edge/ios", frontendHost: "edge-website.zinfra.io")
    }
    
}
