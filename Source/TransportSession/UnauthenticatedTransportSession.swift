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


public enum EnqueueResult {
    case success, nilRequest, maximumNumberOfRequests
}


public protocol UnauthenticatedTransportSessionProtocol: class {

    var delegate: UnauthenticatedTransportSessionDelegate? { get set }
    func enqueueRequest(withGenerator generator: ZMTransportRequestGenerator) -> EnqueueResult
    
}


public struct UserInfo {
    public let identifier: UUID
    public let cookieData: Data
    
    public init(identifier: UUID, cookieData: Data) {
        self.identifier = identifier
        self.cookieData = cookieData
    }
}


public protocol UnauthenticatedTransportSessionDelegate: class {
    func session(_ session: UnauthenticatedTransportSessionProtocol, didReceiveUserInfo userInfo: UserInfo)
}


/// The `UnauthenticatedTransportSession` class should be used instead of `ZMTransportSession`
/// until a user has been authenticated. Consumers should set themselves as delegate to 
/// be notified when a cookie was parsed from a response of a request made using this transport session.
/// When cookie data became available it should be used to create a `ZMPersistentCookieStorage` and
/// to create a regular transport session with it.
final public class UnauthenticatedTransportSession: NSObject, UnauthenticatedTransportSessionProtocol {

    public weak var delegate: UnauthenticatedTransportSessionDelegate?

    private let maximumNumberOfRequests: Int32 = 3
    private var numberOfRunningRequests: Int32 = 0
    private let baseURL: URL
    private var session: SessionProtocol!
    private let delegateQueue: OperationQueue
    private var foundCookie = false

    public init(
        baseURL: URL,
        delegate: UnauthenticatedTransportSessionDelegate? = nil,
        delegateQueue: OperationQueue = .main,
        urlSession: SessionProtocol? = nil
        ) {
        self.baseURL = baseURL
        self.delegateQueue = delegateQueue
        self.delegate = delegate
        super.init()
        self.session = urlSession ?? URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    /// Creates and resumes a request on the internal `URLSession`.
    /// If there are too many requests in progress no request will be enqueued.
    /// - parameter generator: The closure used to retrieve a new request.
    /// - returns: The result of the enqueue operation.
    public func enqueueRequest(withGenerator generator: ZMTransportRequestGenerator) -> EnqueueResult {
        // Increment the running requests count and return early in case we are above the limit.
        let newCount = increment()
        if maximumNumberOfRequests < newCount {
            decrement(notify: false)
            return .maximumNumberOfRequests
        }

        // Ask the generator to create a request and return early if there is none.
        guard let request = generator() else {
            decrement(notify: false)
            return .nilRequest
        }

        guard let urlRequest = URL(string: request.path, relativeTo: baseURL).flatMap(NSMutableURLRequest.init) else { preconditionFailure() }
        urlRequest.configure(with: request)

        let task = session.task(with: urlRequest as URLRequest) { [weak self] data, response, error in
            let transportResponse = ZMTransportResponse(httpurlResponse: response as! HTTPURLResponse, data: data, error: error)
            request.complete(with: transportResponse)
            self?.delegateQueue.addOperation { self?.parseCookie(from: transportResponse) }
            self?.decrement(notify: true)
        }

        task.resume()
        return .success
    }

    /// Parses cookie data from a response and calls the delegate with it.
    /// - parameter response: The response from which the cookie should be parsed.
    private func parseCookie(from response: ZMTransportResponse) {
        guard let data = response.extractCookieData(), let id = response.extractUserIdentifier() else { return }
        delegateQueue.addOperation { [weak self] in
            guard let `self` = self else { return }
            self.delegate?.session(self, didReceiveUserInfo: UserInfo(identifier: id, cookieData: data))
        }
    }

    /// Decrements the number of running requests and posts a new
    /// request notification in case we are below the limit.
    /// - parameter notify: Whether a new request available notificaiton should be posted
    /// when the amount of running requests is below the maximum after decrementing.
    private func decrement(notify: Bool) {
        let newCount = withUnsafeMutablePointer(to: &numberOfRunningRequests, OSAtomicDecrement32)
        guard newCount < maximumNumberOfRequests, notify else { return }
        ZMTransportSession.notifyNewRequestsAvailable(self)
    }

    /// Increments the number of running requests.
    /// - returns: The value after the increment.
    private func increment() -> Int32 {
        return withUnsafeMutablePointer(to: &numberOfRunningRequests, OSAtomicIncrement32)
    }

}

// MARK: - SSL Pinning

extension UnauthenticatedTransportSession: URLSessionDelegate {

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let protectionSpace = challenge.protectionSpace
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            guard verifyServerTrust(protectionSpace.serverTrust, protectionSpace.host) else { return completionHandler(.cancelAuthenticationChallenge, nil) }
        }
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

}

// MARK: - Request configuration

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

// MARK: - Cookie Parsing

private enum CookieKey: String {
    case zetaId = "zuid"
    case properties
}

private enum UserKey: String {
    case user
}


fileprivate extension ZMTransportResponse {

    /// Extracts the wire cookie data from the response.
    /// - returns: The encrypted cookie data (using the cookies key) if there is any.
    func extractCookieData() -> Data? {
        guard let response = rawResponse else { return nil }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: response.allHeaderFields as! [String : String], for: response.url!)
        guard !cookies.isEmpty else { return nil }
        let properties = cookies.flatMap { $0.properties }
        guard (properties.first?[.name] as? String) == CookieKey.zetaId.rawValue else { return nil }
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.requiresSecureCoding = true
        archiver.encode(properties, forKey: CookieKey.properties.rawValue)
        archiver.finishEncoding()
        let key = UserDefaults.cookiesKey()
        return data.zmEncryptPrefixingIV(withKey: key).base64EncodedData()
    }

    func extractUserIdentifier() -> UUID? {
        guard let data = payload as? [String: Any] else { return nil }
        return (data[UserKey.user.rawValue] as? String).flatMap(UUID.init)
    }

}
