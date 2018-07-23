//
//  HTTPCookie+HelperTests.swift
//  WireTransport-ios-tests
//
//  Created by Silvan Dähn on 23.07.18.
//  Copyright © 2018 Wire. All rights reserved.
//

import Foundation
import XCTest
@testable import WireTransport

final class HTTPCookieHelperTests: XCTestCase {
    
    func testThatItCanCreateACookieFromAString() {
        // given
        let domain = ".example.com"
        let name = "zuid"
        let path = "/access"
        let value = "this-is-not-a-valid-cookie-value"
        let cookieString = "\(name)=\(value); \(HTTPCookiePropertyKey.domain.rawValue)=\(domain); \(HTTPCookiePropertyKey.path.rawValue)=\(path)"
        
        // when
        let cookies = HTTPCookie.cookies(from: cookieString, for: URL(string: "exmaple.com")!)
        
        // then
        XCTAssertEqual(cookies.count, 1)
        
        guard let properties = cookies.first?.properties else { return XCTFail("no cookie properties") }
        XCTAssertEqual(properties[.name] as? String, name)
        XCTAssertEqual(properties[.domain] as? String, domain)
        XCTAssertEqual(properties[.path] as? String, path)
        XCTAssertEqual(properties[.value] as? String, value)
    }
    
    func testThatItDoesReturnCookieDataFromAString() {
        // given
        let domain = ".example.com"
        let name = "zuid"
        let path = "/access"
        let value = "this-is-not-a-valid-cookie-value"
        let cookieString = "\(name)=\(value); \(HTTPCookiePropertyKey.domain.rawValue)=\(domain); \(HTTPCookiePropertyKey.path.rawValue)=\(path)"
        
        // when
        guard let data = HTTPCookie.extractCookieData(from: cookieString, url: URL(string: "exmaple.com")!) else { return XCTFail("no cookie data") }
        
        // then
        guard let decryptedData = Data(base64Encoded: data)?.zmDecryptPrefixedIV(key: UserDefaults.cookiesKey()) else { return XCTFail("failed to decrypt") }
        let unarchiver = NSKeyedUnarchiver(forReadingWith: decryptedData)
        unarchiver.requiresSecureCoding = true
        
        guard let propertiesArray = unarchiver.decodePropertyList(forKey: "properties") as? [[String: Any]] else { return XCTFail("no properties") }
        XCTAssertEqual(propertiesArray.count, 1)
        
        guard let properties = propertiesArray.first else { return XCTFail("no properties") }
        XCTAssertEqual(properties["Name"] as? String, name)
        XCTAssertEqual(properties["Value"] as? String, value)
        XCTAssertEqual(properties["Domain"] as? String, domain)
        XCTAssertEqual(properties["Path"] as? String, path)
    }
    
    func testThatItDoesNotReturnCookieDataFromAStringInCaseTheNameValueIsInvalid() {
        // given
        let domain = ".example.com"
        let name = "cookie"
        let path = "/access"
        let value = "this-is-not-a-valid-cookie-value"
        let cookieString = "\(name)=\(value); \(HTTPCookiePropertyKey.domain.rawValue)=\(domain); \(HTTPCookiePropertyKey.path.rawValue)=\(path)"
        
        // when
        let data = HTTPCookie.extractCookieData(from: cookieString, url: URL(string: "exmaple.com")!)
        
        // then
        XCTAssertNil(data)
    }
    
}
