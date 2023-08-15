//
//  PusherPresenceChannel.swift
//  PusherSwift
//
//  Created by Kirtankumar Patel ,Hemal Patel on 12/84/2023.
//
//

import Foundation

public typealias PusherUserInfoObject = [String : AnyObject]

@objcMembers
@objc open class PusherPresenceChannel: PusherChannel {
    open var members: [PusherPresenceChannelMember]
    open var onMemberAdded: ((PusherPresenceChannelMember) -> ())?
    open var onMemberRemoved: ((PusherPresenceChannelMember) -> ())?
    open var myId: String? = nil

    init(
        name: String,
        connection: PusherConnection,
        auth: PusherAuth? = nil,
        onMemberAdded: ((PusherPresenceChannelMember) -> ())? = nil,
        onMemberRemoved: ((PusherPresenceChannelMember) -> ())? = nil) {
            self.members = []
            self.onMemberAdded = onMemberAdded
            self.onMemberRemoved = onMemberRemoved
            super.init(name: name, connection: connection, auth: auth)
    }

    internal func addMember(memberJSON: [String : AnyObject]) {
        let member: PusherPresenceChannelMember

        if let userId = memberJSON["user_id"] as? String {
            if let userInfo = memberJSON["user_info"] as? PusherUserInfoObject {
                member = PusherPresenceChannelMember(userId: userId, userInfo: userInfo as AnyObject?)

            } else {
                member = PusherPresenceChannelMember(userId: userId)
            }
        } else {
            if let userInfo = memberJSON["user_info"] as? PusherUserInfoObject {
                member = PusherPresenceChannelMember(userId: String.init(describing: memberJSON["user_id"]!), userInfo: userInfo as AnyObject?)
            } else {
                member = PusherPresenceChannelMember(userId: String.init(describing: memberJSON["user_id"]!))
            }
        }
        members.append(member)
        self.onMemberAdded?(member)
    }

    
    internal func addExistingMembers(memberHash: [String : AnyObject]) {
        for (userId, userInfo) in memberHash {
            let member: PusherPresenceChannelMember
            if let userInfo = userInfo as? PusherUserInfoObject {
                member = PusherPresenceChannelMember(userId: userId, userInfo: userInfo as AnyObject?)
            } else {
                member = PusherPresenceChannelMember(userId: userId)
            }
            self.members.append(member)
        }
    }

    internal func removeMember(memberJSON: [String : AnyObject]) {
        let id: String

        if let userId = memberJSON["user_id"] as? String {
            id = userId
        } else {
            id = String.init(describing: memberJSON["user_id"]!)
        }

        if let index = self.members.index(where: { $0.userId == id }) {
            let member = self.members[index]
            self.members.remove(at: index)
            self.onMemberRemoved?(member)
        }
    }

    internal func setMyUserId(channelData: String) {
        if let channelDataObject = parse(channelData: channelData), let userId = channelDataObject["user_id"] {
            self.myId = String.init(describing: userId)
        }
    }

    fileprivate func parse(channelData: String) -> [String: AnyObject]? {
        let data = (channelData as NSString).data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)

        do {
            if let jsonData = data, let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject] {
                return jsonObject
            } else {
                print("Unable to parse string: \(channelData)")
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        return nil
    }


    open func findMember(userId: String) -> PusherPresenceChannelMember? {
        return self.members.filter({ $0.userId == userId }).first
    }

    open func me() -> PusherPresenceChannelMember? {
        if let id = self.myId {
            return findMember(userId: id)
        } else {
            return nil
        }
    }
}

@objcMembers
@objc public class PusherPresenceChannelMember: NSObject {
    public let userId: String
    public let userInfo: Any?

    public init(userId: String, userInfo: Any? = nil) {
        self.userId = userId
        self.userInfo = userInfo
    }
}
