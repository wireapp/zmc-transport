//
// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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

#import <Foundation/Foundation.h>

@class ZMAccessToken;

NS_SWIFT_NAME(PushChannelType)
@protocol ZMPushChannelType<ZMReachabilityObserver, ZMPushChannel>

@property (nonatomic, nullable) ZMAccessToken *accessToken;

/// Set the consumer of push channel messsages.
///
/// - parameter consumer: Consumer of messages.
/// - parameter groupQueue: Queue on which the consumer is called.
- (void)setPushChannelConsumer:(id<ZMPushChannelConsumer> _Nullable)consumer
                         queue:(id<ZMSGroupQueue> _Nonnull)groupQueue;

/// Close push channel connection.
- (void)close;

/// Open push channel connection.
- (void)open;

/// Schedule push channel to be open.
///
/// Only relevant for legacy push channel implementation
- (void)scheduleOpen;

@end
