//
//  Session.m
//  SIPSample
//
//  Created by Joe Lepple on 5/1/15.
//  Copyright (c) 2015 PortSIP Solutions, Inc. All rights reserved.
//
import PortSIPVoIPSDK

let LINE_BASE = 0
let MAX_LINES = 8

class Session {
    var sessionId: Int
    var holdState: Bool
    var sessionState: Bool
    var conferenceState: Bool
    var recvCallState: Bool
    var isReferCall: Bool
    var originCallSessionId: Int
    var existEarlyMedia: Bool
    private var _videoMuted: Bool
    var videoState: Bool {
        get {
            return !_videoMuted
        }
        set {
            _videoMuted = !newValue
        }
    }
    var videoMuted: Bool {
        get {
            return _videoMuted
        }
        set {
            _videoMuted = newValue
        }
    }
    var screenShare: Bool
    var uuid: UUID
    var groupUUID: UUID?
    var status: String
    var outgoing: Bool
    var callKitAnswered: Bool
    var callKitCompletionCallback: ((Bool) -> Void)?
    var hasAdd: Bool

    init() {
        sessionId = Int(INVALID_SESSION_ID)
        holdState = false
        sessionState = false
        conferenceState = false
        recvCallState = false
        isReferCall = false
        originCallSessionId = Int(INVALID_SESSION_ID)
        existEarlyMedia = false
        _videoMuted = false
        screenShare = false;
        outgoing = false
        uuid = UUID()
        groupUUID = nil
        status = ""
        hasAdd = false
        callKitAnswered = false
        callKitCompletionCallback = nil
    }

    func reset() {
        sessionId = Int(INVALID_SESSION_ID)
        holdState = false
        sessionState = false
        conferenceState = false
        recvCallState = false
        isReferCall = false
        originCallSessionId = Int(INVALID_SESSION_ID)
        existEarlyMedia = false
        _videoMuted = false
        outgoing = false
        uuid = UUID()
        groupUUID = nil
        status = ""
        screenShare = false;
        hasAdd = false
        callKitAnswered = false
        callKitCompletionCallback = nil
    }
}
