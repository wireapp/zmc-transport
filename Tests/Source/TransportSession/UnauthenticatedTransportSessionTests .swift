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


final class UnauthenticatedTransportSessionTests: ZMTBaseTest {

    private var sut: UnauthenticatedTransportSession!
    private var sessionMock: MockURLSession!
    private let url = URL(string: "http://base.example.com")!

    override func setUp() {
        super.setUp()
        sessionMock = MockURLSession()
        sut = UnauthenticatedTransportSession(baseURL: url, urlSession: sessionMock, reachability: nil)
    }

    override func tearDown() {
        sessionMock = nil
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
        XCTAssertEqual(result, .success)
        XCTAssertEqual(task.resumeCallCount, 1)
    }

    func testThatItReturnsTheCorrectResultForNilRequests() {
        // when
        let result = sut.enqueueRequest { nil }

        // then
        XCTAssertEqual(result, .nilRequest)
    }

    func testThatItDoesNotEnqueueMoreThanThreeRequests() {
        // when
        (0..<3).forEach { _ in
            let result = sut.enqueueRequest { .init(getFromPath: "/") }
            XCTAssertEqual(result, .success)
        }

        // then
        let result = sut.enqueueRequest { .init(getFromPath: "/") }
        XCTAssertEqual(result, .maximumNumberOfRequests)
    }

    func testThatItDoesEnqueueAnotherRequestAfterTheLastOneHasBeenCompleted() {
        // when
        (0..<3).forEach { _ in
            let result = sut.enqueueRequest { .init(getFromPath: "/") }
            XCTAssertEqual(result, .success)
        }

        guard let lastCompletion = sessionMock.recordedCompletionHandler else { return XCTFail("No completion handler") }

        // then
        do {
            let result = sut.enqueueRequest { .init(getFromPath: "/") }
            XCTAssertEqual(result, .maximumNumberOfRequests)
        }

        // when
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
        lastCompletion(nil, response, nil)

        // then
        do {
            let result = sut.enqueueRequest { .init(getFromPath: "/") }
            XCTAssertEqual(result, .success)
        }
    }

    func testThatItCallsTheRequestsCompletionHandler() {
        // given
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
        sessionMock.nextCompletionParameters = (nil, response, nil)
        let completionExpectation = expectation(description: "Completion handler should be called")
        let request = ZMTransportRequest(getFromPath: "/")

        request.add(ZMCompletionHandler(on: fakeUIContext) { response in
            // then
            XCTAssertEqual(response.httpStatus, 200)
            completionExpectation.fulfill()
        })

        // when
        let result = sut.enqueueRequest { request }
        XCTAssert(waitForCustomExpectations(withTimeout: 0.1))

        // then
        XCTAssertEqual(result, .success)
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

    func testThatItParsesCookieDataAndCallsTheDelegate() throws {
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
        let userId = UUID.create()

        let data = try JSONSerialization.data(withJSONObject: ["user": userId.transportString()], options: [])
        sessionMock.nextCompletionParameters = (data, response, nil)
        let userExpectation = expectation(description: "UserInfo should become available")

        sut.didReceiveUserInfo = UserInfoAvailableClosure(queue: .main) { info in
            userExpectation.fulfill()
            XCTAssertNotNil(info.cookieData)
            XCTAssertEqual(info.identifier, userId)
        }

        // when
        _ = sut.enqueueRequest { request }

        // then
        XCTAssert(waitForCustomExpectations(withTimeout: 0.1))
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
        _ = expectation(description: "UserInfo should become available")

        sut.didReceiveUserInfo = UserInfoAvailableClosure(queue: .main) { _ in
            XCTFail("No UserInfo should become available")
        }

        // when
        _ = sut.enqueueRequest { request }

        // then
        XCTAssertFalse(waitForCustomExpectations(withTimeout: 0.01))
    }

}
