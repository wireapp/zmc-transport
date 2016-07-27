//
//  BackgroundActivityFactory.swift
//  ZMTransport
//
//  Created by Florian Morel on 7/27/16.
//  Copyright © 2016 Wire. All rights reserved.
//


private var _instance : BackgroundActivityFactory? = BackgroundActivityFactory() // swift automatically dispatch_once make this thread safe

@objc public class BackgroundActivityFactory: NSObject {
    
    public var mainGroupQueue : ZMSGroupQueue?
    
    @objc public class func instance() -> BackgroundActivityFactory
    {
        if _instance == nil {
            _instance = BackgroundActivityFactory()
        }
        return _instance!
    }
    
    @objc public class func tearDownInstance()
    {
        _instance = nil
    }
    
    override init()
    {
        self.mainGroupQueue = nil
        super.init()
    }

    
    @objc public func backgroundActivity(withName name: String) -> ZMBackgroundActivity?
    {
        guard let mainGroupQueue = mainGroupQueue else { return nil }
        return ZMBackgroundActivity.beginBackgroundActivityWithName(name, groupQueue: mainGroupQueue)
    }
    
    @objc public func backgroundActibity(withName name: String, expirationHandler handler:(Void -> Void)) -> ZMBackgroundActivity?
    {
        guard let mainGroupQueue = mainGroupQueue else { return nil }
        return ZMBackgroundActivity.beginBackgroundActivityWithName(name, groupQueue: mainGroupQueue, expirationHandler: handler)
    }
    
}
