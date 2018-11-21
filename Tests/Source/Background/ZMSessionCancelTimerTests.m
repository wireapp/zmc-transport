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


@import XCTest;
@import WireTesting;
@import OCMock;

#import <WireTransport/WireTransport-Swift.h>
#import "WireTransport_ios_tests-Swift.h"

#import "ZMSessionCancelTimer.h"
#import "ZMSessionCancelTimer+Internal.h"
#import "ZMURLSession.h"
#import "ZMTransportSession.h"

@interface ZMSessionCancelTimerTests : XCTestCase

@property (nonatomic, strong) MockBackgroundActivityManager *activityManager;

@end

@implementation ZMSessionCancelTimerTests

- (void)setUp
{
    [super setUp];
    self.activityManager = [[MockBackgroundActivityManager alloc] init];
    BackgroundActivityFactory.sharedFactory.mainQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
    BackgroundActivityFactory.sharedFactory.activityManager = self.activityManager;
}

- (void)tearDown
{
    self.activityManager = nil;
    BackgroundActivityFactory.sharedFactory.mainQueue = dispatch_get_main_queue();
    BackgroundActivityFactory.sharedFactory.activityManager = nil;
    [super tearDown];
}

- (void)testThatItCancelsATask
{
    // GIVEN
    ZMMockURLSession *session = [ZMMockURLSession createMockSession];
    ZMSessionCancelTimer *sut = [[ZMSessionCancelTimer alloc] initWithURLSession:session timeout:0.05];

    // EXPECTATIONS
    XCTestExpectation *cancelledCalledExpectation = [self expectationWithDescription:@"requests are cancelled"];

    session.cancellationHandler = ^{
        [cancelledCalledExpectation fulfill];
    };

    // WHEN
    [sut start];

    // THEN
    [self waitForExpectations:@[cancelledCalledExpectation] timeout:0.5];
}

- (void)testThatItNotifiesTheOperationLoopAfterAllTasksHaveBeenCancelled;
{
    // GIVEN
    ZMMockURLSession *session = [ZMMockURLSession createMockSession];
    ZMSessionCancelTimer *sut = [[ZMSessionCancelTimer alloc] initWithURLSession:session timeout:0.05];

    // EXPECTATIONS
    XCTestExpectation *newRequestsExpectation = [self expectationForNotification:ZMTransportSessionNewRequestAvailableNotification
                                                                          object:nil
                                                                         handler:nil];

    // WHEN
    [sut start];

    // THEN
    [self waitForExpectations:@[newRequestsExpectation] timeout:0.5];
}

- (void)testThatItBeginsABackgroundActivityWhenStarting
{
    // GIVEN
    ZMURLSession *session = [OCMockObject mockForClass:ZMURLSession.class];
    ZMSessionCancelTimer *sut = [[ZMSessionCancelTimer alloc] initWithURLSession:session timeout:1.0];

    // WHEN
    [sut start];

    // THEN
    XCTAssertTrue(BackgroundActivityFactory.sharedFactory.isActive);
    XCTAssertEqual(self.activityManager.numberOfTasks, 1);
}

- (void)testThatItEndsTheActivityAfterAllTasksHaveBeenCancelled;
{
    // GIVEN
    ZMMockURLSession *session = [ZMMockURLSession createMockSession];
    ZMSessionCancelTimer *sut = [[ZMSessionCancelTimer alloc] initWithURLSession:session timeout:0.05];

    // EXPECTATIONS
    NSPredicate *deactivatedPredicate = [NSPredicate predicateWithFormat:@"isActive == NO"];
    XCTestExpectation *taskCancelledExpectation = [self expectationForPredicate:deactivatedPredicate evaluatedWithObject:BackgroundActivityFactory.sharedFactory handler:^BOOL{
        return self.activityManager.numberOfTasks == 0;
    }];

    // WHEN
    [sut start];

    // THEN
    [self waitForExpectations:@[taskCancelledExpectation] timeout:0.5];
}

- (void)testThatItDoesntStartTheTimerIfTheAppIsBeingSuspended
{
    // GIVEN
    ZMMockURLSession *session = [ZMMockURLSession createMockSession];
    ZMSessionCancelTimer *sut = [[ZMSessionCancelTimer alloc] initWithURLSession:session timeout:0.05];
    [self.activityManager triggerExpiration];

    // EXPECTATIONS
    NSPredicate *cancelCalledPredicate = [NSPredicate predicateWithFormat:@"wasCancelledCalled == true"];
    XCTestExpectation *cancelledCalledExpectation = [self expectationForPredicate:cancelCalledPredicate evaluatedWithObject:session handler:nil];

    NSPredicate *activatedPredicate = [NSPredicate predicateWithFormat:@"isActive == true"];
    XCTestExpectation *taskCreatedExpectation = [self expectationForPredicate:activatedPredicate evaluatedWithObject:BackgroundActivityFactory.sharedFactory handler:nil];

    taskCreatedExpectation.inverted = YES;

    // WHEN
    [sut start];
    XCTAssertEqual(sut.timer.state, ZMTimerStateNotStarted);
    XCTAssertEqual(self.activityManager.numberOfTasks, 0);

    // THEN
    [self waitForExpectations:@[cancelledCalledExpectation, taskCreatedExpectation] timeout:0.5];
}

- (void)testThatItEndsTheBackgroundTaskWhenItIsCancelled;
{
    // GIVEN
    ZMMockURLSession *session = [ZMMockURLSession createMockSession];
    ZMSessionCancelTimer *sut = [[ZMSessionCancelTimer alloc] initWithURLSession:session timeout:2];

    // EXPECTATIONS

//    XCTestExpectation *taskEndedExpectation = [self expectationForPredicate:deactivatedPredicate evaluatedWithObject:BackgroundActivityFactory.sharedFactory handler:^BOOL{
//        return self.activityManager.numberOfTasks == 0;
//    }];

    // WHEN
    [sut start];
    [sut cancel];

    // THEN
//    [self waitForExpectations:@[taskEndedExpectation] timeout:0.5];
}

- (void)testThatItCancelsWhenTheApplicationCallsTheExpirationTimer
{
    // GIVEN
    ZMMockURLSession *session = [ZMMockURLSession createMockSession];
    ZMSessionCancelTimer *sut = [[ZMSessionCancelTimer alloc] initWithURLSession:session timeout:2];

    // EXPECTATIONS
    XCTestExpectation *cancelledCalledExpectation = [self expectationWithDescription:@"requests are cancelled"];

    session.cancellationHandler = ^{
        [cancelledCalledExpectation fulfill];
    };

    // WHEN
    [sut start];
    [self.activityManager triggerExpiration];

    // THEN
    [self waitForExpectations:@[cancelledCalledExpectation] timeout:0.5];
}

@end
