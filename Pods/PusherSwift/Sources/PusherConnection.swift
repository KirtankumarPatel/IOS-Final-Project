//
//  PusherConnection.swift
//  PusherSwift
//
//  Created by Kirtrankumar Patel , Hemal patel on 11/08/2023.
//
//

import Foundation

public typealias PusherEventJSON = [String: AnyObject]

@objcMembers
@objc open class PusherConnection: NSObject {
    open let url: String
    open let key: String
    open var options: PusherClientOptions
    open var globalChannel: GlobalChannel!
    open var socketId: String?
    open var connectionState = ConnectionState.disconnected
    open var channels = PusherChannels()
    open var socket: WebSocket!
    open var URLSession: Foundation.URLSession
    open var userDataFetcher: (() -> PusherPresenceChannelMember)?
    open var reconnectAttemptsMax: Int? = 6
    open var reconnectAttempts: Int = 0
    open var maxReconnectGapInSeconds: Double? = nil
    open weak var delegate: PusherDelegate?
    internal var reconnectTimer: Timer? = nil

    open var socketConnected: Bool = false {
        didSet {
            updateConnectionStateAndAttemptSubscriptions()
        }
    }
    open var connectionEstablishedMessageReceived: Bool = false {
        didSet {
            updateConnectionStateAndAttemptSubscriptions()
        }
    }

    open lazy var reachability: Reachability? = {
        let reachability = Reachability.init()
        reachability?.whenReachable = { [weak self] reachability in
            guard self != nil else {
                print("Your Pusher instance has probably become deallocated. See https://github.com/pusher/pusher-websocket-swift/issues/109 for more information")
                return
            }

            self!.delegate?.debugLog?(message: "[PUSHER DEBUG] Network reachable")
            if self!.connectionState == .disconnected || self!.connectionState == .reconnectingWhenNetworkBecomesReachable {
                self!.attemptReconnect()
            }
        }
        reachability?.whenUnreachable = { [weak self] reachability in
            guard self != nil else {
                print("Your Pusher instance has probably become deallocated. See https://github.com/pusher/pusher-websocket-swift/issues/109 for more information")
                return
            }

            self!.delegate?.debugLog?(message: "[PUSHER DEBUG] Network unreachable")
        }
        return reachability
    }()

   
    public init(
        key: String,
        socket: WebSocket,
        url: String,
        options: PusherClientOptions,
        URLSession: Foundation.URLSession = Foundation.URLSession.shared) {
            self.url = url
            self.key = key
            self.options = options
            self.URLSession = URLSession
            self.socket = socket
            super.init()
            self.socket.delegate = self
    }

    internal func subscribe(
        channelName: String,
        auth: PusherAuth? = nil,
        onMemberAdded: ((PusherPresenceChannelMember) -> ())? = nil,
        onMemberRemoved: ((PusherPresenceChannelMember) -> ())? = nil) -> PusherChannel {
            let newChannel = channels.add(
                name: channelName,
                connection: self,
                auth: auth,
                onMemberAdded: onMemberAdded,
                onMemberRemoved: onMemberRemoved
            )

            guard self.connectionState == .connected else { return newChannel }

            if !self.authorize(newChannel, auth: auth) {
                print("Unable to subscribe to channel: \(newChannel.name)")
            }

            return newChannel
    }

    internal func subscribeToPresenceChannel(
        channelName: String,
        auth: PusherAuth? = nil,
        onMemberAdded: ((PusherPresenceChannelMember) -> ())? = nil,
        onMemberRemoved: ((PusherPresenceChannelMember) -> ())? = nil) -> PusherPresenceChannel {
            let newChannel = channels.addPresence(
                channelName: channelName,
                connection: self,
                auth: auth,
                onMemberAdded: onMemberAdded,
                onMemberRemoved: onMemberRemoved
            )

            guard self.connectionState == .connected else { return newChannel }

            if !self.authorize(newChannel, auth: auth) {
                print("Unable to subscribe to channel: \(newChannel.name)")
            }

            return newChannel
    }

    /**
        Unsubscribes from a PusherChannel with a given name

        - parameter channelName: The name of the channel
    */
    internal func unsubscribe(channelName: String) {
        if let chan = self.channels.find(name: channelName), chan.subscribed {
            self.sendEvent(event: "pusher:unsubscribe",
                data: [
                    "channel": channelName
                ] as [String : Any]
            )
            self.channels.remove(name: channelName)
        }
    }
    
    /**
        Unsubscribes from all PusherChannels
    */
    internal func unsubscribeAll() {
        for (_, channel) in channels.channels {
            unsubscribe(channelName: channel.name)
        }
    }

    
    open func sendEvent(event: String, data: Any, channel: PusherChannel? = nil) {
        if event.components(separatedBy: "-")[0] == "client" {
            sendClientEvent(event: event, data: data, channel: channel)
        } else {
            let dataString = JSONStringify(["event": event, "data": data])
            self.delegate?.debugLog?(message: "[PUSHER DEBUG] sendEvent \(dataString)")
            self.socket.write(string: dataString)
        }
    }

    fileprivate func sendClientEvent(event: String, data: Any, channel: PusherChannel?) {
        if let channel = channel {
            if channel.type == .presence || channel.type == .private {
                let dataString = JSONStringify(["event": event, "data": data, "channel": channel.name] as [String : Any])
                self.delegate?.debugLog?(message: "[PUSHER DEBUG] sendClientEvent \(dataString)")
                self.socket.write(string: dataString)
            } else {
                print("You must be subscribed to a private or presence channel to send client events")
            }
        }
    }

    /**
        JSON stringifies an object

        - parameter value: The value to be JSON stringified

        - returns: A JSON-stringified version of the value
    */
    fileprivate func JSONStringify(_ value: Any) -> String {
        if JSONSerialization.isValidJSONObject(value) {
            do {
                let data = try JSONSerialization.data(withJSONObject: value, options: [])
                let string = String(data: data, encoding: .utf8)
                if string != nil {
                    return string!
                }
            } catch _ {
            }
        }
        return ""
    }

    /**
        Disconnects the websocket
    */
    open func disconnect() {
        if self.connectionState == .connected {
            self.reachability?.stopNotifier()
            updateConnectionState(to: .disconnecting)
            self.socket.disconnect()
        }
    }

    @objc open func connect() {
        if self.connectionState == .connected {
            return
        } else {
            updateConnectionState(to: .connecting)
            self.socket.connect()
            if self.options.autoReconnect {
                _ = try? reachability?.startNotifier()
            }
        }
    }

    
    internal func createGlobalChannel() {
        self.globalChannel = GlobalChannel(connection: self)
    }

    
    internal func addCallbackToGlobalChannel(_ callback: @escaping (Any?) -> Void) -> String {
        return globalChannel.bind(callback)
    }
    internal func removeCallbackFromGlobalChannel(callbackId: String) {
        globalChannel.unbind(callbackId: callbackId)
    }

    internal func removeAllCallbacksFromGlobalChannel() {
        globalChannel.unbindAll()
    }

    
    internal func updateConnectionState(to newState: ConnectionState) {
        let oldState = self.connectionState
        self.connectionState = newState
        self.delegate?.changedConnectionState?(from: oldState, to: newState)
    }

    
    fileprivate func updateConnectionStateAndAttemptSubscriptions() {
        if self.connectionEstablishedMessageReceived && self.socketConnected && self.connectionState != .connected {
            updateConnectionState(to: .connected)
            attemptSubscriptionsToUnsubscribedChannels()
        }
    }

    fileprivate func handleSubscriptionSucceededEvent(json: PusherEventJSON) {
        if let channelName = json["channel"] as? String, let chan = self.channels.find(name: channelName) {
            chan.subscribed = true

            guard let eventData = json["data"] as? String else {
                self.delegate?.debugLog?(message: "Subscription succeeded event received without data key in payload")
                return
            }

            if PusherChannelType.isPresenceChannel(name: channelName) {
                if let presChan = self.channels.find(name: channelName) as? PusherPresenceChannel {
                    if let dataJSON = getPusherEventJSON(from: eventData) {
                        if let presenceData = dataJSON["presence"] as? [String : AnyObject],
                           let presenceHash = presenceData["hash"] as? [String : AnyObject]
                        {
                            presChan.addExistingMembers(memberHash: presenceHash)
                        }
                    }
                }
            }

            callGlobalCallbacks(forEvent: "pusher:subscription_succeeded", jsonObject: json)
            chan.handleEvent(name: "pusher:subscription_succeeded", data: eventData)

            self.delegate?.subscribedToChannel?(name: channelName)

            chan.auth = nil

            while chan.unsentEvents.count > 0 {
                if let pusherEvent = chan.unsentEvents.popLast() {
                    chan.trigger(eventName: pusherEvent.name, data: pusherEvent.data)
                }
            }
        }
    }

   
    fileprivate func handleConnectionEstablishedEvent(json: PusherEventJSON) {
        if let data = json["data"] as? String {
            if let connectionData = getPusherEventJSON(from: data), let socketId = connectionData["socket_id"] as? String {
                self.socketId = socketId
                self.reconnectAttempts = 0
                self.reconnectTimer?.invalidate()

                self.connectionEstablishedMessageReceived = true
            }
        }
    }

    /
    fileprivate func attemptSubscriptionsToUnsubscribedChannels() {
        for (_, channel) in self.channels.channels {
            if !channel.subscribed {
                if !self.authorize(channel, auth: channel.auth) {
                    print("Unable to subscribe to channel: \(channel.name)")
                }
            }
        }
    }

    fileprivate func handleMemberAddedEvent(json: PusherEventJSON) {
        if let data = json["data"] as? String {
            if let channelName = json["channel"] as? String, let chan = self.channels.find(name: channelName) as? PusherPresenceChannel {
                if let memberJSON = getPusherEventJSON(from: data) {
                    chan.addMember(memberJSON: memberJSON)
                } else {
                    print("Unable to add member")
                }
            }
        }
    }

    fileprivate func handleMemberRemovedEvent(json: PusherEventJSON) {
        if let data = json["data"] as? String {
            if let channelName = json["channel"] as? String, let chan = self.channels.find(name: channelName) as? PusherPresenceChannel {
                if let memberJSON = getPusherEventJSON(from: data) {
                    chan.removeMember(memberJSON: memberJSON)
                } else {
                    print("Unable to remove member")
                }
            }
        }
    }

    fileprivate func handleAuthorizationError(forChannel channelName: String, response: URLResponse?, data: String?, error: NSError?) {
        let eventName = "pusher:subscription_error"
        let json = [
            "event": eventName,
            "channel": channelName,
            "data": data ?? ""
        ]
        DispatchQueue.main.async {
            // TODO: Consider removing in favour of exclusively using delegate
            self.handleEvent(eventName: eventName, jsonObject: json as [String : AnyObject])
        }
        
        self.delegate?.failedToSubscribeToChannel?(name: channelName, response, response, data: data, error:error)
    }
    
    open func getPusherEventJSON(from string: String) -> [String : AnyObject]? {
        let data = (string as NSString).data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)

        do {
            if let jsonData = data, let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String : AnyObject] {
                return jsonObject
            } else {
                print("Unable to parse string from WebSocket: \(string)")
            }
        } catch let error as NSError {
            print("Error: \(error.localizedDescription)")
        }
        return nil
    }

    open func getEventDataJSON(from string: String) -> Any {
        let data = (string as NSString).data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)

        do {
            if let jsonData = data, let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) {
                return jsonObject
            } else {
                print("Returning data string instead because unable to parse string as JSON - check that your JSON is valid.")
            }
        }
        return string
    }

    open func handleEvent(eventName: String, jsonObject: [String : AnyObject]) {
        switch eventName {
        case "pusher_internal:subscription_succeeded":
            handleSubscriptionSucceededEvent(json: jsonObject)
        case "pusher:connection_established":
            handleConnectionEstablishedEvent(json: jsonObject)
        case "pusher_internal:member_added":
            handleMemberAddedEvent(json: jsonObject)
        case "pusher_internal:member_removed":
            handleMemberRemovedEvent(json: jsonObject)
        default:
            callGlobalCallbacks(forEvent: eventName, jsonObject: jsonObject)
            if let channelName = jsonObject["channel"] as? String, let internalChannel = self.channels.find(name: channelName) {
                if let eName = jsonObject["event"] as? String, let eData = jsonObject["data"] as? String {
                    internalChannel.handleEvent(name: eName, data: eData)
                }
            }
        }
    }

    fileprivate func callGlobalCallbacks(forEvent eventName: String, jsonObject: [String : AnyObject]) {
        if let globalChannel = self.globalChannel {
            if let eData =  jsonObject["data"] as? String {
                let channelName = jsonObject["channel"] as! String?
                globalChannel.handleEvent(name: eventName, data: eData, channelName: channelName)
            } else if let eData =  jsonObject["data"] as? [String: AnyObject] {
                globalChannel.handleErrorEvent(name: eventName, data: eData)
            }
        }
    }
    
    fileprivate func authorize(_ channel: PusherChannel, auth: PusherAuth? = nil) -> Bool {
        if channel.type != .presence && channel.type != .private {
            subscribeToNormalChannel(channel)
            return true
        } else if let auth = auth {
            // Don't go through normal auth flow if auth value provided
            if channel.type == .private {
                self.handlePrivateChannelAuth(authValue: auth.auth, channel: channel)
            } else if let channelData = auth.channelData {
                self.handlePresenceChannelAuth(authValue: auth.auth, channel: channel, channelData: channelData)
            } else {
                self.delegate?.debugLog?(message: "Attempting to subscribe to presence channel but no channelData value provided")
                return false
            }

            return true
        } else {
            guard let socketId = self.socketId else {
                print("socketId value not found. You may not be connected.")
                return false
            }

            switch self.options.authMethod {
            case .noMethod:
                let errorMessage = "Authentication method required for private / presence channels but none provided."
                let error = NSError(domain: "com.pusher.PusherSwift", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey: errorMessage])

                print(errorMessage)

                handleAuthorizationError(forChannel: channel.name, response: nil, data: nil, error: error)

                return false
            case .endpoint(authEndpoint: let authEndpoint):
                let request = requestForAuthValue(from: authEndpoint, socketId: socketId, channelName: channel.name)
                sendAuthorisationRequest(request: request, channel: channel)
                return true
            case .authRequestBuilder(authRequestBuilder: let builder):
                if let request = builder.requestFor?(socketID: socketId, channel: channel) {
                    sendAuthorisationRequest(request: request as URLRequest, channel: channel)

                    return true
                } else if let request = builder.requestFor?(socketID: socketId, channelName: channel.name) {
                    sendAuthorisationRequest(request: request, channel: channel)

                    return true
                } else {
                    let errorMessage = "Authentication request could not be built"
                    let error = NSError(domain: "com.pusher.PusherSwift", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey: errorMessage])

                    handleAuthorizationError(forChannel: channel.name, response: nil, data: nil, error: error)

                    return false
                }
            case .authorizer(authorizer: let authorizer):
                authorizer.fetchAuthValue(socketID: socketId, channelName: channel.name) { authInfo in
                    guard let authInfo = authInfo else {
                        print("Auth info passed to authorizer completionHandler was nil so channel subscription failed")
                        return
                    }

                    self.handleAuthInfo(authString: authInfo.auth, channelData: authInfo.channelData, channel: channel)
                }

                return true
            case .inline(secret: let secret):
                var msg = ""
                var channelData = ""
                if channel.type == .presence {
                    channelData = getUserDataJSON()
                    msg = "\(self.socketId!):\(channel.name):\(channelData)"
                } else {
                    msg = "\(self.socketId!):\(channel.name)"
                }

                let secretBuff: [UInt8] = Array(secret.utf8)
                let msgBuff: [UInt8] = Array(msg.utf8)

                if let hmac = try? HMAC(key: secretBuff, variant: .sha256).authenticate(msgBuff) {
                    let signature = Data(bytes: hmac).toHexString()
                    let auth = "\(self.key):\(signature)".lowercased()

                    if channel.type == .private {
                        self.handlePrivateChannelAuth(authValue: auth, channel: channel)
                    } else {
                        self.handlePresenceChannelAuth(authValue: auth, channel: channel, channelData: channelData)
                    }
                }

                return true
            }
        }
    }

    fileprivate func getUserDataJSON() -> String {
        if let userDataFetcher = self.userDataFetcher {
            let userData = userDataFetcher()
            if let userInfo: Any = userData.userInfo {
                return JSONStringify(["user_id": userData.userId, "user_info": userInfo])
            } else {
                return JSONStringify(["user_id": userData.userId])
            }
        } else {
            if let socketId = self.socketId {
                return JSONStringify(["user_id": socketId])
            } else {
                print("Authentication failed. You may not be connected")
                return ""
            }
        }
    }

    fileprivate func subscribeToNormalChannel(_ channel: PusherChannel) {
        self.sendEvent(
            event: "pusher:subscribe",
            data: [
                "channel": channel.name
            ]
        )
    }
   
    fileprivate func requestForAuthValue(from endpoint: String, socketId: String, channelName: String) -> URLRequest {
        let allowedCharacterSet = CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[] ").inverted
        let encodedChannelName = channelName.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? channelName

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = "socket_id=\(socketId)&channel_name=\(encodedChannelName)".data(using: String.Encoding.utf8)

        return request
    }

    
    fileprivate func sendAuthorisationRequest(request: URLRequest, channel: PusherChannel) {
        let task = URLSession.dataTask(with: request, completionHandler: { data, response, sessionError in
            if let error = sessionError {
                print("Error authorizing channel [\(channel.name)]: \(error)")
                self.handleAuthorizationError(forChannel: channel.name, response: response, data: nil, error: error as NSError?)
                return
            }

            guard let data = data else {
                print("Error authorizing channel [\(channel.name)]")
                self.handleAuthorizationError(forChannel: channel.name, response: response, data: nil, error: nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
                let dataString = String(data: data, encoding: String.Encoding.utf8)
                print ("Error authorizing channel [\(channel.name)]: \(String(describing: dataString))")
                self.handleAuthorizationError(forChannel: channel.name, response: response, data: dataString, error: nil)
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []), let json = jsonObject as? [String: AnyObject] else {
                print("Error authorizing channel [\(channel.name)]")
                self.handleAuthorizationError(forChannel: channel.name, response: httpResponse, data: nil, error: nil)
                return
            }

            self.handleAuthResponse(json: json, channel: channel)
        })

        task.resume()
    }

    
    fileprivate func handleAuthResponse(
        json: [String : AnyObject],
        channel: PusherChannel) {
            if let auth = json["auth"] as? String {
                handleAuthInfo(
                    authString: auth,
                    channelData: json["channel_data"] as? String,
                    channel: channel
                )
            }
    }

    
    fileprivate func handleAuthInfo(authString: String, channelData: String?, channel: PusherChannel) {
        if let channelData = channelData {
            handlePresenceChannelAuth(authValue: authString, channel: channel, channelData: channelData)
        } else {
            handlePrivateChannelAuth(authValue: authString, channel: channel)
        }
    }

    fileprivate func handlePresenceChannelAuth(
        authValue: String,
        channel: PusherChannel,
        channelData: String) {
            (channel as? PusherPresenceChannel)?.setMyUserId(channelData: channelData)

            self.sendEvent(
                event: "pusher:subscribe",
                data: [
                    "channel": channel.name,
                    "auth": authValue,
                    "channel_data": channelData
                ]
            )
    }

    fileprivate func handlePrivateChannelAuth(authValue auth: String, channel: PusherChannel) {
        self.sendEvent(
            event: "pusher:subscribe",
            data: [
                "channel": channel.name,
                "auth": auth
            ]
        )
    }
}

@objc public class PusherAuth: NSObject {
    public let auth: String
    public let channelData: String?

    public init(auth: String, channelData: String? = nil) {
        self.auth = auth
        self.channelData = channelData
    }
}

@objc public enum ConnectionState: Int {
    case connecting
    case connected
    case disconnecting
    case disconnected
    case reconnecting
    case reconnectingWhenNetworkBecomesReachable

    static let connectionStates = [
        connecting: "connecting",
        connected: "connected",
        disconnecting: "disconnecting",
        disconnected: "disconnected",
        reconnecting: "reconnecting",
        reconnectingWhenNetworkBecomesReachable: "reconnreconnectingWhenNetworkBecomesReachable",
    ]

    public func stringValue() -> String {
        return ConnectionState.connectionStates[self]!
    }
}
