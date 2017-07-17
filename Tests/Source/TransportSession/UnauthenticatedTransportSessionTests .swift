//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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


import WireTesting
@testable import WireTransport


private class MockTask: DataTaskProtocol {

    var resumeCallCount = 0

    func resume() {
        resumeCallCount += 1
    }

}


private class MockURLSession: SessionProtocol {

    var recordedRequest: URLRequest?
    var recordedCompletionHandler: ((Data?, URLResponse?, Error?) -> Void)?
    var nextCompletionParameters: (Data?, URLResponse?, Error?)?
    var nextMockTask: MockTask?

    func task(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> DataTaskProtocol {
        recordedRequest = request
        recordedCompletionHandler = completionHandler
        if let params = nextCompletionParameters {
            completionHandler(params.0, params.1, params.2)
        }
        return nextMockTask ?? MockTask()
    }

}


private class MockDelegate: UnauthenticatedTransportSessionDelegate {

    var cookieData: Data?

    func session(_ session: UnauthenticatedTransportSession, cookieDataBecomeAvailable data: Data) {
        cookieData = data
    }

}


final class UnauthenticatedTransportSessionTests: ZMTBaseTest {

    private var sut: UnauthenticatedTransportSession!
    private var sessionMock: MockURLSession!
    private var mockDelegate: MockDelegate!
    private let url = URL(string: "http://base.example.com")!

    override func setUp() {
        super.setUp()
        sessionMock = MockURLSession()
        mockDelegate = MockDelegate()
        sut = UnauthenticatedTransportSession(baseURL: url, delegate: mockDelegate, urlSession: sessionMock)
    }

    override func tearDown() {
        sessionMock = nil
        mockDelegate = nil
        sut = nil
        super.tearDown()
    }

    func testThatItEnqueuesANonNilRequestAndReturnsTheCorrectResult() {
        // given
        let task = MockTask()
        sessionMock.nextMockTask = task

        // when
        let result = sut.enqueueRequest { .init(getFromPath: "/") }

        // then
        XCTAssert(result.didHaveLessRequestThanMax)
        XCTAssert(result.didGenerateNonNullRequest)
        XCTAssertEqual(task.resumeCallCount, 1)
    }

    func testThatItReturnsTheCorrectResultForNilRequests() {
        // when
        let result = sut.enqueueRequest { nil }

        // then
        XCTAssert(result.didHaveLessRequestThanMax)
        XCTAssertFalse(result.didGenerateNonNullRequest)
    }

    func testThatItDoesNotEnqueueMoreThanThreeRequests() {
        // when
        (0..<3).forEach { _ in
            let result = sut.enqueueRequest { .init(getFromPath: "/") }
            XCTAssert(result.didHaveLessRequestThanMax)
            XCTAssert(result.didGenerateNonNullRequest)
        }

        // then
        let result = sut.enqueueRequest { .init(getFromPath: "/") }
        XCTAssertFalse(result.didHaveLessRequestThanMax)
        XCTAssertFalse(result.didGenerateNonNullRequest)
    }

    func testThatItDoesEnqueueAnotherRequestAfterTheLastOneHasBeenCompleted() {
        // when
        (0..<3).forEach { _ in
            let result = sut.enqueueRequest { .init(getFromPath: "/") }
            XCTAssert(result.didHaveLessRequestThanMax)
            XCTAssert(result.didGenerateNonNullRequest)
        }

        guard let lastCompletion = sessionMock.recordedCompletionHandler else { return XCTFail("No completion handler") }

        // then
        do {
            let result = sut.enqueueRequest { .init(getFromPath: "/") }
            XCTAssertFalse(result.didHaveLessRequestThanMax)
            XCTAssertFalse(result.didGenerateNonNullRequest)
        }

        // when
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
        lastCompletion(nil, response, nil)

        // then
        do {
            let result = sut.enqueueRequest { .init(getFromPath: "/") }
            XCTAssert(result.didHaveLessRequestThanMax)
            XCTAssert(result.didGenerateNonNullRequest)
        }
    }

    func testThatItCallsTheRequestsCompletionHandler() {
        // given
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
        sessionMock.nextCompletionParameters = (nil, response, nil)
        let completionExpectation = expectation(description: "Completion handler should be called")
        let request = ZMTransportRequest(getFromPath: "/")

        request.addCompletionHandler(ZMCompletionHandler(on: fakeUIContext) { response in
            // then
            XCTAssertEqual(response.httpStatus, 200)
            completionExpectation.fulfill()
        })

        // when
        let result = sut.enqueueRequest { request }
        XCTAssert(waitForCustomExpectations(withTimeout: 0.1))

        // then
        XCTAssert(result.didHaveLessRequestThanMax)
        XCTAssert(result.didGenerateNonNullRequest)
    }

    func testThatPostsANewRequestAvailableNotificationAfterCompletingARunningRequest() {
        // given && then
        _ = expectation(
            forNotification: NSNotification.Name.ZMTransportSessionNewRequestAvailable.rawValue,
            object: nil,
            handler: nil
        )

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        sessionMock.nextCompletionParameters = (nil, response, nil)
        let request = ZMTransportRequest(getFromPath: "/")

        // when
        _ = sut.enqueueRequest { request }
        XCTAssert(waitForCustomExpectations(withTimeout: 0.1))

    }

    func testThatItParsesCookieDataAndCallsTheDelegate() {
        // given
        let headers = [
            "Date": "Thu, 24 Jul 2014 09:06:45 GMT",
            "Content-Encoding": "gzip",
            "Server": "nginx",
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "file://",
            "Connection": "keep-alive",
            "Set-Cookie": "zuid=wjCWn1Y1pBgYrFCwuU7WK2eHpAVY8Ocu-rUAWIpSzOcvDVmYVc9Xd6Ovyy-PktFkamLushbfKgBlIWJh6ZtbAA==.1721442805.u.7eaaa023.08326f5e-3c0f-4247-a235-2b4d93f921a4; Expires=Sun, 21-Jul-2024 09:06:45 GMT; Domain=wire.com; HttpOnly; Secure",
            "Content-Length": "214"
        ]

        let request = ZMTransportRequest(getFromPath: "/")
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)
        sessionMock.nextCompletionParameters = (nil, response, nil)

        // when
        _ = sut.enqueueRequest { request }

        // then
        XCTAssertNotNil(mockDelegate.cookieData)
    }

    func testThatItParsesCookieDataAndDoesNotCallTheDelegateIfTheCookieIsMissingRequiredFields() {
        // given
        let headers = [
            "Date": "Thu, 24 Jul 2014 09:06:45 GMT",
            "Content-Encoding": "gzip",
            "Server": "nginx",
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "file://",
            "Connection": "keep-alive",
            "Set-Cookie": "Expires=Sun, 21-Jul-2024 09:06:45 GMT; Domain=wire.com; HttpOnly; Secure",
            "Content-Length": "214"
        ]

        let request = ZMTransportRequest(getFromPath: "/")
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)
        sessionMock.nextCompletionParameters = (nil, response, nil)

        // when
        _ = sut.enqueueRequest { request }

        // then
        XCTAssertNil(mockDelegate.cookieData)
    }

}
