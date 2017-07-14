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


protocol UnauthenticatedTransportSessionDelegate {
    func session(_ session: UnauthenticatedTransportSession, cookieStorageBecameAvailable cookieStorage: ZMPersistentCookieStorage) // TODO:
}

final public class UnauthenticatedTransportSession: NSObject {

    private let maximumNumberOfRequests: Int32 = 3
    private var numberOfRunningRequests: Int32 = 0
    private let baseURL: URL
    private let session = URLSession.shared

    public init(baseURL: URL) {
        self.baseURL = baseURL
        super.init()
    }

    public func enqueueRequest(withGenerator generator: ZMTransportRequestGenerator) -> ZMTransportEnqueueResult {

        func decrement(notify: Bool) {
            let newCount = withUnsafeMutablePointer(to: &numberOfRunningRequests, OSAtomicDecrement32)
            guard newCount < maximumNumberOfRequests, notify else { return }
            ZMTransportSession.notifyNewRequestsAvailable(self)
        }

        let newCount = withUnsafeMutablePointer(to: &numberOfRunningRequests, OSAtomicIncrement32)
        if maximumNumberOfRequests < newCount {
            decrement(notify: false)
            return .init(didHaveLessRequestsThanMax: false, didGenerateNonNullRequest: false)
        }

        guard let request = generator() else {
            decrement(notify: false)
            return .init(didHaveLessRequestsThanMax: true, didGenerateNonNullRequest: false)
        }

        guard let url = URL(string: request.path, relativeTo: baseURL) else { preconditionFailure() }

        let urlRequest = NSMutableURLRequest(url: url)
        urlRequest.configure(with: request)
        let task = session.dataTask(with: urlRequest as URLRequest) { data, response, error in
            decrement(notify: true)
            let response = ZMTransportResponse(httpurlResponse: response as! HTTPURLResponse, data: data, error: error)
            request.complete(with: response)
        }

        task.resume()
        return .init(didHaveLessRequestsThanMax: true, didGenerateNonNullRequest: true)
    }

}


extension UnauthenticatedTransportSession: URLSessionDelegate {

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let protectionSpace = challenge.protectionSpace
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            guard verifyServerTrust(protectionSpace.serverTrust, protectionSpace.host) else { return completionHandler(.cancelAuthenticationChallenge, nil) }
        }
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

}

extension NSMutableURLRequest {

    @objc(configureWithRequest:) func configure(with request: ZMTransportRequest) {
        httpMethod = request.methodAsString
        ZMUserAgent.setUserAgentOn(self)
        request.setAcceptedResponseMediaTypeOnHTTP(self)
        request.setBodyDataAndMediaTypeOnHTTP(self)
        request.setAdditionalHeaderFieldsOnHTTP(self)
        request.setContentDispositionOnHTTP(self)
    }

}
