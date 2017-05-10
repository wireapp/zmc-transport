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

#import <XCTest/XCTest.h>
#import "ZMServerTrust.h"

extern BOOL verifyServerTrust(SecTrustRef const serverTrust, NSString *host);

@import WireTesting;

@interface ZMServerTrustTests : ZMTBaseTest <NSURLSessionDataDelegate>

@property (nonatomic) NSURLSession *urlSession;
@property (nonatomic) XCTestExpectation *trustedServer;

@end

@implementation ZMServerTrustTests

- (void)setUp {
    [super setUp];
    
    self.urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
}

- (void)tearDown {
    self.urlSession = nil;
    
    [super tearDown];
}

- (void)testProductionBackendPinning {
    
    NSArray<NSString *> *pinnedHosts = @[@"prod-nginz-https.wire.com", @"prod-nginz-ssl.wire.com", @"prod-assets.wire.com", @"www.wire.com", @"wire.com"];
    
    for (NSString *pinnedHost in pinnedHosts) {
        self.trustedServer = [self expectationWithDescription:@"We are trusting the server"];
        
        [[self.urlSession dataTaskWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@", pinnedHost]]] resume];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:5.0]);
    }
}

- (void)URLSession:(NSURLSession * __unused)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    NSURLProtectionSpace *protectionSpace = challenge.protectionSpace;
    if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        BOOL const didTrust = verifyServerTrust(protectionSpace.serverTrust, protectionSpace.host);
        
        if (! didTrust) {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        } else {
            [self.trustedServer fulfill];
        }
    }
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

@end
