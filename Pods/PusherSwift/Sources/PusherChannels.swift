//
//  PusherGlobalChannel.swift
//  PusherSwift
//
//  Created by Kirtankumar Patel , Hemal Patel on 11/08/2023.
//
//

import Foundation

@objcMembers
@objc open class PusherChannels: NSObject {
    open var channels = [String: PusherChannel]()

    
    internal func add(
        name: String,
        connection: PusherConnection,
        auth: PusherAuth? = nil,
        onMemberAdded: ((PusherPresenceChannelMember) -> ())? = nil,
        onMemberRemoved: ((PusherPresenceChannelMember) -> ())? = nil) -> PusherChannel {
            if let channel = self.channels[name] {
                return channel
            } else {
                var newChannel: PusherChannel
                if PusherChannelType.isPresenceChannel(name: name) {
                    newChannel = PusherPresenceChannel(
                        name: name,
                        connection: connection,
                        auth: auth,
                        onMemberAdded: onMemberAdded,
                        onMemberRemoved: onMemberRemoved
                    )
                } else {
                    newChannel = PusherChannel(name: name, connection: connection, auth: auth)
                }
                self.channels[name] = newChannel
                return newChannel
            }
    }

    internal func addPresence(
        channelName: String,
        connection: PusherConnection,
        auth: PusherAuth? = nil,
        onMemberAdded: ((PusherPresenceChannelMember) -> ())? = nil,
        onMemberRemoved: ((PusherPresenceChannelMember) -> ())? = nil) -> PusherPresenceChannel {
        if let channel = self.channels[channelName] as? PusherPresenceChannel {
            return channel
        } else {
            let newChannel = PusherPresenceChannel(
                name: channelName,
                connection: connection,
                auth: auth,
                onMemberAdded: onMemberAdded,
                onMemberRemoved: onMemberRemoved
            )
            self.channels[channelName] = newChannel
            return newChannel
        }
    }
        internal func remove(name: String) {
        self.channels.removeValue(forKey: name)
    }

    public func find(name: String) -> PusherChannel? {
        return self.channels[name]
    }

   /
    public func findPresence(name: String) -> PusherPresenceChannel? {
        return self.channels[name] as? PusherPresenceChannel
    }
}
