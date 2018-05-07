//
//  ZMTransportRequestLoggingTests.swift
//  WireTransport-ios
//
//  Created by Nicola Giancecchi on 07.05.18.
//  Copyright © 2018 Wire. All rights reserved.
//

import XCTest
import WireTesting
@testable import WireTransport


final class ZMTransportRequestLoggingTests: ZMTBaseTest {

    
    func testThatItObfuscatesPasswordsInLogs() {
        
        //given
        let password = "secret"
        
        let payload: [String:String] = [
            "username":"test@test.xyz",
            "password":password
        ]
        
        //when
        let requestDescription = ZMTransportRequest(path: "/test",
                                                    method: .methodGET,
                                                    payload: payload as ZMTransportData).description
        
        //then
        XCTAssertTrue(requestDescription.contains("password = \"<redacted>\""))
        XCTAssertFalse(requestDescription.contains("password = \"\(password)\""))
    }
}

