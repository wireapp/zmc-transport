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


@import Foundation;
#import "ZMReachability.h"
#import "ZMPushChannel.h"

@class ZMTransportRequestScheduler;
@class ZMAccessToken;
@protocol ZMPushChannelConsumer;
@protocol ZMSGroupQueue;


/// This class is responsible for opening and closing the push channel connection to the backend.
@interface ZMTransportPushChannel : NSObject <ZMReachabilityObserver, ZMPushChannel>

/// Updating will call attemptToOpen
@property (nonatomic) BOOL isAppInBackground;

/// When set not to nil an attempt open the push channel will be made
@property (nonatomic) ZMAccessToken *accessToken;

- (instancetype)initWithScheduler:(ZMTransportRequestScheduler *)scheduler userAgentString:(NSString *)userAgentString URL:(NSURL *)URL;
- (instancetype)initWithScheduler:(ZMTransportRequestScheduler *)scheduler userAgentString:(NSString *)userAgentString URL:(NSURL *)URL pushChannelClass:(Class)pushChannelClass NS_DESIGNATED_INITIALIZER;

- (void)setPushChannelConsumer:(id<ZMPushChannelConsumer>)consumer groupQueue:(id<ZMSGroupQueue>)groupQueue;
- (void)closeAndRemoveConsumer;
- (void)establishConnection;


@property (nonatomic, weak) id <ZMNetworkStateDelegate> networkStateDelegate;

@end
