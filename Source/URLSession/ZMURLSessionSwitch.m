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

@interface ZMURLSessionSwitch ()

@property (nonatomic) BOOL tornDown;
@property (nonatomic) ZMURLSession *currentSession;
@property (nonatomic) ZMURLSession *foregroundSession;
@property (nonatomic) ZMURLSession *backgroundSession;
@property (nonatomic) ZMURLSession *voipSession;

@end



@implementation ZMURLSessionSwitch

ZM_EMPTY_ASSERTING_INIT();

- (instancetype)initWithForegroundSession:(ZMURLSession *)foregroundSession backgroundSession:(ZMURLSession *)backgroundSession voipSession:(ZMURLSession *)voipSession;
{
    Require(foregroundSession != nil);
    Require(backgroundSession != nil);
    Require(voipSession != nil);
    
    self = [super init];
    if (self) {
        self.foregroundSession = foregroundSession;
        self.backgroundSession = backgroundSession;
        self.voipSession = voipSession;
        self.currentSession = self.foregroundSession;
    }
    return self;
}

- (ZMURLSession *)currentSession
{
    return self.foregroundSession;
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
    [self.voipSession tearDown];
}

- (NSArray <ZMURLSession *>*)allSessions
{
    return @[self.foregroundSession, self.backgroundSession, self.voipSession];
}

- (void)switchToBackgroundSession
{
    
}

- (void)switchToForegroundSession
{
    
}

@end
