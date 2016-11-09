//
//  ZMBackendEnvironment+Default.swift
//  ZMTransport
//
//  Created by Jacob on 09/11/16.
//  Copyright © 2016 Wire. All rights reserved.
//

import Foundation


extension ZMBackendEnvironment {
    
    public static func setupDefaultEnvironment() {
        ZMBackendEnvironment.setupEnvironment(of: .production, withBackendHost: "prod-nginz-https.wire.com", wsHost: "prod-nginz-ssl.wire.com", blackListEndpoint: "clientblacklist.wire.com/prod/ios", frontendHost: "wire.com")
        ZMBackendEnvironment.setupEnvironment(of: .staging, withBackendHost: "staging-nginz-https.zinfra.io", wsHost: "staging-nginz-ssl.zinfra.io", blackListEndpoint: "clientblacklist.wire.com/staging/ios", frontendHost: "edge-website.zinfra.io")
        ZMBackendEnvironment.setupEnvironment(of: .edge, withBackendHost: "edge-nginz-https.zinfra.io", wsHost: "edge-nginz-ssl.zinfra.io", blackListEndpoint: "clientblacklist.wire.com/edge/ios", frontendHost: "edge-website.zinfra.io")
    }
    
}
