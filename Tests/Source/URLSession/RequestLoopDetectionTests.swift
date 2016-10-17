//
//  RequestLoopDetectionTests.swift
//  ZMTransport
//
//  Created by Marco Conti on 17/10/16.
//  Copyright © 2016 Wire. All rights reserved.
//

import Foundation
import XCTest
@testable import ZMTransport

class RequestLoopDetectionTests : XCTestCase {
    
    func testThatItDetectsALoopWithOneRepeatedRequest() {
        
        // given
        var triggered = false
        let path = "foo.com"
        
        let sut = RequestLoopDetection() {
            XCTAssertEqual(path, $0)
            triggered = true
        }
        
        // when
        (0..<RequestLoopDetection.repetitionTriggerThreshold).forEach { _ in
            sut.recordRequest(path: path, date: nil)
        }
        
        // then
        XCTAssertTrue(triggered)
    }
    
    func testThatItDoesNotDetectsALoopWithOneRepeatedRequestIfMoreThan5MinutesApart() {
        
        // given
        let path = "foo.com"
        var startDate = Date(timeIntervalSince1970: 100)
        
        let sut = RequestLoopDetection() { _ in
            XCTFail()
        }
        
        // when
        (0..<RequestLoopDetection.repetitionTriggerThreshold).forEach { _ in
            sut.recordRequest(path: path, date: startDate)
            startDate.addTimeInterval(10*60)
        }
    }
    
    func testThatItDoesNotDetectsALoopWithOneRepeatedRequesInsertedAtWrongTime() {
        
        // given
        let path = "foo.com"
        var startDate = Date()
        
        let sut = RequestLoopDetection() { _ in
            XCTFail()
        }
        
        // when
        (0..<RequestLoopDetection.repetitionTriggerThreshold).forEach { _ in
            sut.recordRequest(path: path, date: startDate)
            startDate.addTimeInterval(-4*60)
        }
    }
    
    func testThatItDoesNotDetectsALoopWithManyDifferentRequest() {
        
        // given
        let sut = RequestLoopDetection() { _ in
            XCTFail()
        }
        
        // when
        (0..<RequestLoopDetection.repetitionTriggerThreshold).forEach {
            sut.recordRequest(path: "foo.com/\($0)", date: nil)
        }
    }
    
    func testThatItDetectsALoopWithOneRepeatedRequestOnlyOnceEveryThreshold() {
        
        // given
        let path = "foo.com"
        var triggerCount = 0
        
        let sut = RequestLoopDetection() {
            triggerCount += 1
            XCTAssertEqual(path, $0)
        }
        
        // when
        (0..<RequestLoopDetection.repetitionTriggerThreshold*3).forEach { _ in
            sut.recordRequest(path: path, date: nil)
        }
        
        // then
        XCTAssertEqual(triggerCount, 3)
    }
    
    func testThatItDetectsMultipleLoopsFromDifferentURLs() {
        
        // given
        var paths = ["foo.com", "bar.de", "baz.org"]
        var triggeredURLs : [String] = []
        
        let sut = RequestLoopDetection() {
            triggeredURLs.append($0)
        }
        
        // when
        (0..<RequestLoopDetection.repetitionTriggerThreshold*4).forEach {
            let path = paths[$0 % paths.count] // this will insert them in interleaved order
            sut.recordRequest(path: path, date: nil)
         }
        
        // then
        XCTAssertEqual(triggeredURLs, paths)
    }
    
    func testThatItDoesNotStoreMoreThan2000URLs() {
        
        // given
        let path = "MyURL.com"
        var triggered = false
        
        let sut = RequestLoopDetection() { _ in
            triggered = true
        }
        
        // when
        sut.recordRequest(path: path, date: nil)
        (0..<2500).forEach {
            sut.recordRequest(path: "url\($0).com", date: nil)
        }
        sut.recordRequest(path: path, date: nil)
        
        // then
        XCTAssertFalse(triggered)
    }
}
