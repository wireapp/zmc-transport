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


@import WireSystem;

#import "ZMURLSessionSwitch.h"
#import "ZMURLSession.h"
#import "ZMSessionCancelTimer.h"



@interface ZMURLSessionSwitch ()

@property (nonatomic) BOOL tornDown;
@property (nonatomic) ZMURLSession *currentSession;
@property (nonatomic) ZMURLSession *foregroundSession;
@property (nonatomic) ZMURLSession *backgroundSession;
@property (nonatomic) Class sessionCancelTimerClass;

@property (nonatomic) ZMSessionCancelTimer *cancelForegroundTimer;
@end



@implementation ZMURLSessionSwitch

ZM_EMPTY_ASSERTING_INIT();

- (instancetype)initWithForegroundSession:(ZMURLSession *)foregroundSession backgroundSession:(ZMURLSession *)backgroundSession;
{
    return [self initWithForegroundSession:foregroundSession backgroundSession:backgroundSession sessionCancelTimerClass:nil];
}

- (instancetype)initWithForegroundSession:(ZMURLSession *)foregroundSession backgroundSession:(ZMURLSession *)backgroundSession sessionCancelTimerClass:(Class)sessionCancelTimerClass;
{
    Require(foregroundSession != nil);
    Require(backgroundSession != nil);

    self = [super init];
    if (self) {
        self.foregroundSession = foregroundSession;
        self.backgroundSession = backgroundSession;
        self.currentSession = self.foregroundSession;
        self.sessionCancelTimerClass = sessionCancelTimerClass ?: ZMSessionCancelTimer.class;
    }
    return self;
}

- (void)dealloc
{
    RequireString(self.tornDown, "Did not tear down %p", (__bridge void *) self);
}

- (void)tearDown
{
    self.tornDown = YES;
    [self.foregroundSession tearDown];
    [self.backgroundSession tearDown];
    [self.cancelForegroundTimer cancel];
}

- (void)switchToForegroundSession;
{
    if (self.currentSession == self.foregroundSession) {
        return;
    }
    self.currentSession = self.foregroundSession;
    
    // Let background tasks finish, no need to cancel them.

    [self.cancelForegroundTimer cancel];
    self.cancelForegroundTimer = nil;
}

- (void)switchToBackgroundSession;
{
    if (self.currentSession == self.backgroundSession) {
        return;
    }
    self.currentSession = self.backgroundSession;
    
    [self.cancelForegroundTimer cancel];
    self.cancelForegroundTimer = [[self.sessionCancelTimerClass alloc] initWithURLSession:self.foregroundSession timeout:ZMSessionCancelTimerDefaultTimeout];
    [self.cancelForegroundTimer start];
}

- (NSArray <ZMURLSession *>*)allSessions
{
    return @[self.foregroundSession, self.backgroundSession];
}

@end
