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

import UIKit
import WireUtilities

@objc public protocol BackgroundActivityManager: NSObjectProtocol {
    func beginBackgroundTask(withName name: String?, expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier
    func endBackgroundTask(_ task: UIBackgroundTaskIdentifier)
}

extension UIApplication: BackgroundActivityManager {}

/**
 * Manages the creation and lifecycle of background tasks.
 *
 * To improve the behavior of the app in background contexts, this object starts and stops a single background task,
 * and associates "tokens" to these tasks to keep track of the progress, and handles expiration automatically.
 *
 * When you request background activity:
 * - if there is no active activity: we create a new UIKit background task and save a token
 * - if there are current active activities: we reuse the active UIKit task and save a token
 *
 * When you end a background activity manually:
 * - if the activity was the last in the list: we tell UIKit that the background task ended and remove the token from the list
 * - if there are still other activities in the list: we remove the token from the list
 *
 * When the system sends a background time expiration warning:
 * 1. We notify all the task tokens that they will expire soon, and give them an opportunity to clean up before the app gets suspended
 * 2. We end the active background task and block new activities from starting
 */

@objcMembers open class BackgroundActivityFactory: NSObject {
    
    private static let _instance : BackgroundActivityFactory = BackgroundActivityFactory()
    
    open weak var activityManager : BackgroundActivityManager? = nil
    open weak var mainGroupQueue : ZMSGroupQueue? = nil

    open var isActive: Bool {
        return currentBackgroundTask != nil && self.currentBackgroundTask != UIBackgroundTaskInvalid
    }

    private var currentBackgroundTask: UIBackgroundTaskIdentifier?
    private var activities: Set<BackgroundActivity> = []

    /// Get the shared instance.
    @objc open class func sharedInstance() -> BackgroundActivityFactory
    {
        return _instance
    }

    // MARK: - Starting Background Activities

    /**
     * Starts a background activity if possible.
     * - parameter name: The name of the task, for debugging purposes.
     * - returns: A token representing the activity, if the background execution is available.
     * - warning: If this method returns `nil`, you should **not** perform the work yu are planning to do.
     */

    @objc open func backgroundActivity(withName name: String) -> BackgroundActivity?
    {
        return startActivityIfPossible(name, nil)
    }

    /**
     * Starts a background activity if possible.
     * - parameter name: The name of the task, for debugging purposes.
     * - parameter handler: The code to execute to clean up the state as the app is about to be suspended. This value can be set later.
     * - warning: If this method returns `nil`, you should **not** perform the work yu are planning to do.
     */

    @objc open func backgroundActivity(withName name: String, expirationHandler: @escaping (() -> Void)) -> BackgroundActivity?
    {
        return startActivityIfPossible(name, expirationHandler)
    }

    // MARK: - Management

    /**
     * Call this method when the app resumes from foreground.
     */

    @objc open func resume() {
        mainGroupQueue?.performGroupedBlock {
            if self.currentBackgroundTask == UIBackgroundTaskInvalid {
                self.currentBackgroundTask = nil
            }
        }
    }

    @objc open func endActivity(_ activity: BackgroundActivity) {
        mainGroupQueue?.performGroupedBlock {
            guard self.isActive else {
                return
            }

            self.activities.remove(activity)

            if self.activities.count == 0 {
                self.finishBackgroundTask()
            }
        }
    }

    // MARK: - Helpers

    /// Starts the background activity of the system allows it.
    func startActivityIfPossible(_ name: String, _ expirationHandler: (() -> Void)?) -> BackgroundActivity? {
        // Do not start new tasks if the background timer is running.
        guard self.currentBackgroundTask != UIBackgroundTaskInvalid else { return nil }
        guard let mainGroupQueue = mainGroupQueue, let activityManager = activityManager else { return nil }

        let activity = BackgroundActivity(name: name, expirationHandler: expirationHandler)

        mainGroupQueue.performGroupedBlock {
            if self.currentBackgroundTask == nil {
                self.currentBackgroundTask = activityManager.beginBackgroundTask(withName: "BackgroundActivityFactory", expirationHandler: self.handleExpiration)
            }

            self.activities.insert(activity)
        }

        return activity
    }

    /// Called when the background timer is about to expire.
    func handleExpiration() {
        mainGroupQueue?.performGroupedBlock {
            self.activities.forEach { $0.expirationHandler?() }
            self.activities.removeAll()

            self.finishBackgroundTask()
            self.currentBackgroundTask = UIBackgroundTaskInvalid
        }
    }

    /// Ends the current background task.
    func finishBackgroundTask() {
        if let currentBackgroundTask = self.currentBackgroundTask {
            self.activityManager?.endBackgroundTask(currentBackgroundTask)
        }
    }
    
}
