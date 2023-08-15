//
//  PusherGlobalChannel.swift
//  PusherSwift
//
//  Created by Kirtankumar Patel, Hemal Patel on 11/08/2023.
//
//

import Foundation

@objcMembers
@objc open class GlobalChannel: PusherChannel {
    open var globalCallbacks: [String : (Any?) -> Void] = [:]

    init(connection: PusherConnection) {
        super.init(name: "pusher_global_internal_channel", connection: connection)
    }

    
    internal func handleEvent(name: String, data: String, channelName: String?) {
        for (_, callback) in self.globalCallbacks {
            if let channelName = channelName {
                callback(["channel": channelName, "event": name, "data": data] as [String: Any])
            } else {
                callback(["event": name, "data": data] as [String: Any])
            }
        }
    }

    
    internal func handleErrorEvent(name: String, data: [String: AnyObject]) {
        for (_, callback) in self.globalCallbacks {
            callback(["event": name, "data": data])
        }
    }

    
    internal func bind(_ callback: @escaping (Any?) -> Void) -> String {
        let randomId = UUID().uuidString
        self.globalCallbacks[randomId] = callback
        return randomId
    }

    internal func unbind(callbackId: String) {
        globalCallbacks.removeValue(forKey: callbackId)
    }

    override open func unbindAll() {
        globalCallbacks = [:]
    }
}
