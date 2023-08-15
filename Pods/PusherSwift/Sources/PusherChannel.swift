//
//  PusherChannel.swift
//  PusherSwift
//
//  Created by Kirtankumar Patel, Hemal Patel on 11/08/2023.
//
//

public enum PusherChannelType {
    case `private`
    case presence
    case normal

    public init(name: String) {
        self = Swift.type(of: self).type(forName: name)
    }

    public static func type(forName name: String) -> PusherChannelType {
        if (name.components(separatedBy: "-")[0] == "presence") {
            return .presence
        } else if (name.components(separatedBy: "-")[0] == "private") {
            return .private
        } else {
            return .normal
        }
    }

    public static func isPresenceChannel(name: String) -> Bool {
        return PusherChannelType(name: name) == .presence
    }
}

@objcMembers
open class PusherChannel: NSObject {
    open var eventHandlers: [String: [EventHandler]] = [:]
    open var subscribed = false
    open let name: String
    open weak var connection: PusherConnection?
    open var unsentEvents = [PusherEvent]()
    open let type: PusherChannelType
    public var auth: PusherAuth?

    public init(name: String, connection: PusherConnection, auth: PusherAuth? = nil) {
        self.name = name
        self.connection = connection
        self.auth = auth
        self.type = PusherChannelType(name: name)
    }

   
    @discardableResult open func bind(eventName: String, callback: @escaping (Any?) -> Void) -> String {
        let randomId = UUID().uuidString
        let eventHandler = EventHandler(id: randomId, callback: callback)
        if self.eventHandlers[eventName] != nil {
            self.eventHandlers[eventName]?.append(eventHandler)
        } else {
            self.eventHandlers[eventName] = [eventHandler]
        }
        return randomId
    }

    open func unbind(eventName: String, callbackId: String) {
        if let eventSpecificHandlers = self.eventHandlers[eventName] {
            self.eventHandlers[eventName] = eventSpecificHandlers.filter({ $0.id != callbackId })
        }
    }

    open func unbindAll() {
        self.eventHandlers = [:]
    }

    
    open func unbindAll(forEventName eventName: String) {
        self.eventHandlers[eventName] = []
    }

    open func handleEvent(name: String, data: String) {
        if let eventHandlerArray = self.eventHandlers[name] {
            let jsonize = connection?.options.attemptToReturnJSONObject ?? true

            for eventHandler in eventHandlerArray {
                eventHandler.callback(jsonize ? connection?.getEventDataJSON(from: data) : data)
            }
        }
    }

    open func trigger(eventName: String, data: Any) {
        if subscribed {
            connection?.sendEvent(event: eventName, data: data, channel: self)
        } else {
            unsentEvents.insert(PusherEvent(name: eventName, data: data), at: 0)
        }
    }
}

public struct EventHandler {
    let id: String
    let callback: (Any?) -> Void
}

public struct PusherEvent {
    public let name: String
    public let data: Any
}
