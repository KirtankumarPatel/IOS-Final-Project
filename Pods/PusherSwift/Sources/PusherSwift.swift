//
//  PusherSwift.swift
//
//  Created by Kirtankumar Patel, Hemal Patel on 10/08/2023.
//
//

import Foundation

let PROTOCOL = 7
let VERSION = "5.1.1"
let CLIENT_NAME = "pusher-websocket-swift"

@objcMembers
@objc open class Pusher: NSObject {
    open let connection: PusherConnection
    open weak var delegate: PusherDelegate? = nil {
        willSet {
            self.connection.delegate = newValue
#if os(iOS) || os(OSX)
            self.nativePusher.delegate = newValue
#endif
        }
    }
    private let key: String

#if os(iOS) || os(OSX)
    public let nativePusher: NativePusher

    public init(key: String, options: PusherClientOptions = PusherClientOptions(), nativePusher: NativePusher? = nil) {
        self.key = key
        let urlString = constructUrl(key: key, options: options)
        let ws = WebSocket(url: URL(string: urlString)!)
        connection = PusherConnection(key: key, socket: ws, url: urlString, options: options)
        connection.createGlobalChannel()
        self.nativePusher = nativePusher ?? NativePusher()
        self.nativePusher.setPusherAppKey(pusherAppKey: key)
    }
#endif

#if os(tvOS)
    
    public init(key: String, options: PusherClientOptions = PusherClientOptions()) {
        self.key = key
        let urlString = constructUrl(key: key, options: options)
        let ws = WebSocket(url: URL(string: urlString)!)
        connection = PusherConnection(key: key, socket: ws, url: urlString, options: options)
        connection.createGlobalChannel()
    }
#endif

open func subscribe(
        _ channelName: String,
        auth: PusherAuth? = nil,
        onMemberAdded: ((PusherPresenceChannelMember) -> ())? = nil,
        onMemberRemoved: ((PusherPresenceChannelMember) -> ())? = nil) -> PusherChannel {
            return self.connection.subscribe(
                channelName: channelName,
                auth: auth,
                onMemberAdded: onMemberAdded,
                onMemberRemoved: onMemberRemoved
            )
    }

    
    open func subscribeToPresenceChannel(
        channelName: String,
        auth: PusherAuth? = nil,
        onMemberAdded: ((PusherPresenceChannelMember) -> ())? = nil,
        onMemberRemoved: ((PusherPresenceChannelMember) -> ())? = nil) -> PusherPresenceChannel {
            return self.connection.subscribeToPresenceChannel(
                channelName: channelName,
                auth: auth,
                onMemberAdded: onMemberAdded,
                onMemberRemoved: onMemberRemoved
            )
    }

    /**
        Unsubscribes the client from a given channel

        - parameter channelName: The name of the channel to unsubscribe from
    */
    open func unsubscribe(_ channelName: String) {
        self.connection.unsubscribe(channelName: channelName)
    }
    
    /**
        Unsubscribes the client from all channels
    */
    open func unsubscribeAll() {
        self.connection.unsubscribeAll()
    }

    @discardableResult open func bind(_ callback: @escaping (Any?) -> Void) -> String {
        return self.connection.addCallbackToGlobalChannel(callback)
    }
    open func unbind(callbackId: String) {
        self.connection.removeCallbackFromGlobalChannel(callbackId: callbackId)
    }

    /**
        Unbinds the client from all global callbacks
    */
    open func unbindAll() {
        self.connection.removeAllCallbacksFromGlobalChannel()
    }

    /**
        Disconnects the client's connection
    */
    open func disconnect() {
        self.connection.disconnect()
    }

    /**
        Initiates a connection attempt using the client's existing connection details
    */
    open func connect() {
        self.connection.connect()
    }
}

func constructUrl(key: String, options: PusherClientOptions) -> String {
    var url = ""

    if options.encrypted {
        url = "wss://\(options.host):\(options.port)/app/\(key)"
    } else {
        url = "ws://\(options.host):\(options.port)/app/\(key)"
    }
    return "\(url)?client=\(CLIENT_NAME)&version=\(VERSION)&protocol=\(PROTOCOL)"
}
