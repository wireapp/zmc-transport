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


import Foundation


public protocol UnauthenticatedTransportSessionDelegate: class {
    func session(_ session: UnauthenticatedTransportSession, cookieDataBecomeAvailable data: Data)
}

final public class UnauthenticatedTransportSession: NSObject {

    private let maximumNumberOfRequests: Int32 = 3
    private var numberOfRunningRequests: Int32 = 0
    private let baseURL: URL
    private var session: URLSession!
    private weak var delegate: UnauthenticatedTransportSessionDelegate?

    public init(baseURL: URL, delegate: UnauthenticatedTransportSessionDelegate) {
        self.baseURL = baseURL
        self.delegate = delegate
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
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
        let task = session.dataTask(with: urlRequest as URLRequest) { [weak self] data, response, error in
            decrement(notify: true)
            self?.parseCookie(from: response as! HTTPURLResponse)
            request.complete(with: .init(httpurlResponse: response as! HTTPURLResponse, data: data, error: error))
        }

        task.resume()
        return .init(didHaveLessRequestsThanMax: true, didGenerateNonNullRequest: true)
    }

    private func parseCookie(from response: HTTPURLResponse) {
        guard let data = response.extractCookieData() else { return }
        delegate?.session(self, cookieDataBecomeAvailable: data)
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


private enum CookieKey: String {
    case zetaId = "zuid"
    case properties
}

extension HTTPURLResponse {

    func extractCookieData() -> Data? {
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaderFields as! [String : String], for: url!)
        guard !cookies.isEmpty else { return nil }
        let properties = cookies.flatMap { $0.properties }
        guard (properties.first?[.name] as? String) == CookieKey.zetaId.rawValue else { return nil }
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.requiresSecureCoding = true
        archiver.encode(properties, forKey: CookieKey.properties.rawValue)
        archiver.finishEncoding()

        if TARGET_OS_IPHONE == 1 {
            let key = UserDefaults.cookiesKey()
            let encrypted = data.zmEncryptPrefixingIV(withKey: key)
            return encrypted?.base64EncodedData()
        }

        return data as Data
    }

}
