//
//  CallManager.swift
//  SipSample
//
//  Created by portsip on 17/2/22.
//  Copyright © 2017 portsip. All rights reserved.
//

import CallKit
import UIKit
import PortSIPVoIPSDK
import Foundation

protocol CallManagerDelegate: NSObjectProtocol {
    func onIncomingCallWithoutCallKit(_ sessionId: CLong, existsVideo: Bool, remoteParty: String, remoteDisplayName: String)
    func onAnsweredCall(sessionId: CLong)
    func onCloseCall(sessionId: CLong)
    func onMuteCall(sessionId: CLong, muted: Bool)
    func onHoldCall(sessionId: CLong, onHold: Bool)

    func onNewOutgoingCall(sessionid: CLong)
}

class CallManager: NSObject {
    weak var delegate: CallManagerDelegate?

    var isHideCallkit: Bool = false
    var _enableCallKit: Bool = false
    var enableCallKit: Bool {
        set {
            if _enableCallKit != newValue {
                _enableCallKit = newValue
                _portSIPSDK.enableCallKit(_enableCallKit)
            }
        }
        get {
            return _enableCallKit
        }
    }
    
    var isConference: Bool = false
    var _playDTMFTone: Bool = true

    var sessionArray: [Session] = []
    var _portSIPSDK: PortSIPSDK!
    var _playDTMFMethod: DTMF_METHOD!
    var _conferenceGroupID: UUID!

    // MARK: - Socket readiness for answering calls
    // If true, answering a call will wait until the socket is ready (connected/connecting)
    var waitSocketBeforeAnswer: Bool = true
    private var isSocketReady: Bool = false
    private var isCallIncoming: Bool = false
    private var isForeground: Bool = false
    private var pendingAnswerBlocks: [() -> Void] = []

    init(portsipSdk: PortSIPSDK) {
        _portSIPSDK = portsipSdk

        _playDTMFTone = true
        _playDTMFMethod = DTMF_RFC2833
        _conferenceGroupID = nil

        for _ in 0 ..< MAX_LINES {
            sessionArray.append(Session())
        }

        _enableCallKit = false
        _portSIPSDK.enableCallKit(false)

        _portSIPSDK.enableCallKit(_enableCallKit)
    }

    func checkAndAnswerPendingCalls() -> Bool {
        print("CallManager - checkAndAnswerPendingCalls")
        if isForeground && isSocketReady && isCallIncoming && !pendingAnswerBlocks.isEmpty {
            print("CallManager - checkAndAnswerPendingCalls - answer call immediately")
            let tasks = pendingAnswerBlocks
            pendingAnswerBlocks.removeAll()
            tasks.forEach { $0() }
            return true
        }
        return false
    }

    // Update socket readiness status from Flutter side
    func updateSocketReady(_ ready: Bool) {
        isSocketReady = ready
        print("CallManager - updateSocketReady \(ready)")
        _ = checkAndAnswerPendingCalls()
    }

    func setCallIncoming(_ incall: Bool) {
        isCallIncoming = incall
        print("CallManager - setCallIncoming \(incall)")
        _ = checkAndAnswerPendingCalls()
    }

    func setForeground(_ foreground: Bool) -> Bool {
        isForeground = foreground
        print("CallManager - setForeground \(foreground)")
        return checkAndAnswerPendingCalls()
    }

    func setPlayDTMFMethod(dtmfMethod: DTMF_METHOD, playDTMFTone: Bool) {
        _playDTMFTone = playDTMFTone
        _playDTMFMethod = dtmfMethod
    }

    func reportUpdateCall(uuid: UUID, hasVideo: Bool, from: String) {
        guard findCallByUUID(uuid: uuid) != nil else {
            return
        }
        if #available(iOS 10.0, *) {
            let handle = CXHandle(type: .generic, value: from)
            let update = CXCallUpdate()
            update.remoteHandle = handle
            update.hasVideo = hasVideo
            update.supportsGrouping = true
            update.supportsDTMF = true
            update.supportsUngrouping = true
            update.localizedCallerName = from

            PortCxProvider.shareInstance.cxprovider.reportCall(with: uuid, updated: update)
        }
    }

    func reportOutgoingCall(number: String, uuid: UUID, video: Bool = true) {
        if #available(iOS 10.0, *) {
            
            isHideCallkit = false
            let handle = CXHandle(type: .generic, value: number)

            let startCallAction = CXStartCallAction(call: uuid, handle: handle)

            startCallAction.isVideo = video

            let transaction = CXTransaction()
            transaction.addAction(startCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let err = error {
                    print("Error requesting transaction: \(err)")
                } else {
                    print("Requested transaction successfully")
                }
            }
            if let result = findCallByUUID(uuid: uuid), result.session.sessionState {
                PortCxProvider.shareInstance.cxprovider.reportOutgoingCall(with: uuid, connectedAt: Date())
            }
        }
    }

    @available(iOS 10.0, *)
    func reportInComingCall(uuid: UUID, hasVideo: Bool, from: String, completion: ((Error?) -> Void)? = nil) {
        guard findCallByUUID(uuid: uuid) != nil else {
            return
        }
        
        isHideCallkit = false

        let handle = CXHandle(type: .generic, value: from)
        let update = CXCallUpdate()
        update.remoteHandle = handle
        update.hasVideo = hasVideo
        update.supportsGrouping = true
        update.supportsDTMF = true
        update.supportsUngrouping = true

        PortCxProvider.shareInstance.cxprovider.reportNewIncomingCall(with: uuid, update: update, completion: { error in
            print("ErrorCode: \(String(describing: error))")
            completion?(error)
        })
    }

    func reportAnswerCall(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if #available(iOS 10.0, *) {
            let answerAction = CXAnswerCallAction(call: result.session.uuid)

            let transaction = CXTransaction()
            transaction.addAction(answerAction)
            let callController = CXCallController()
            callController.request(transaction) { [weak self] error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                    result.session.callKitCompletionCallback?(false)
                } else {
                    print("Requested transaction successfully")
                    // We don't call the completion callback here because it will be called
                    // after the actual answer operation is completed in answerCallWithUUID
                }
            }
        }
    }

    func reportEndCall(uuid: UUID) {
        if #available(iOS 10.0, *) {
            guard let result = findCallByUUID(uuid: uuid) else {
                print("reportEndCall: cannot find call by uuid")
                return
            }
            let session = result.session as Session
            let endCallAction = CXEndCallAction(call: session.uuid)
            let transaction = CXTransaction()
            transaction.addAction(endCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportSetHeld(uuid: UUID, onHold: Bool) {
        print("reportSetHeld transaction successfully")
        if #available(iOS 10.0, *) {
            guard let result = findCallByUUID(uuid: uuid) else {
                return
            }

            let setHeldCallAction = CXSetHeldCallAction(call: result.session.uuid, onHold: onHold)
            let transaction = CXTransaction()
            transaction.addAction(setHeldCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportSetMute(uuid: UUID, muted: Bool) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }

        if result.session.sessionState {
            if #available(iOS 10.0, *) {
                let setMutedCallAction = CXSetMutedCallAction(call: result.session.uuid, muted: muted)
                let transaction = CXTransaction()
                transaction.addAction(setMutedCallAction)
                let callController = CXCallController()
                callController.request(transaction) { error in
                    if let error = error {
                        print("Error requesting transaction: \(error)")
                    } else {
                        print("Requested transaction successfully")
                    }
                }
            }
        }
    }

    func reportJoninConference(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if #available(iOS 10.0, *) {
            let setGroupCallAction = CXSetGroupCallAction(call: result.session.uuid, callUUIDToGroupWith: _conferenceGroupID)
            let transaction = CXTransaction()
            transaction.addAction(setGroupCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportRemoveFromConference(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if #available(iOS 10.0, *) {
            let setGroupCallAction = CXSetGroupCallAction(call: result.session.uuid, callUUIDToGroupWith: nil)
            let transaction = CXTransaction()
            transaction.addAction(setGroupCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportPlayDtmf(uuid: UUID, tone: Int) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        var digits: String
        if tone == 10 {
            digits = "*"
        } else if tone == 11 {
            digits = "#"
        } else {
            digits = String(tone)
        }
        if #available(iOS 10.0, *) {
            let dtmfCallAction = CXPlayDTMFCallAction(call: result.session.uuid, digits: digits, type: .singleTone)
            let transaction = CXTransaction()
            transaction.addAction(dtmfCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    //    Call Manager interface
    func makeCall(callee: String, displayName: String, videoCall: Bool) -> (CLong) {
        let num = getConnectCallNum()
        if num > MAX_LINES {
            return (CLong)(INVALID_SESSION_ID)
        }

        let sessionid = makeCallWithUUID(callee: callee, displayName: displayName, videoCall: videoCall, uuid: UUID())
        let result = findCallBySessionID(sessionid)
        if result != nil, _enableCallKit {
            reportOutgoingCall(number: callee, uuid: result!.session.uuid, video: videoCall)
            print("reportOutgoingCall uuid = \(result!.session.uuid))")
        }
        return sessionid
    }

    func incomingCall(sessionid: CLong, existsVideo: Bool, remoteParty: String, callUUID: UUID, completionHandle: @escaping () -> Void) {
        var session: Session
        let result = findCallByUUID(uuid: callUUID)
        if result != nil {
            session = result!.session
            if sessionid > 0 {
                session.sessionId = sessionid
            }
            session.videoState = existsVideo
            if session.callKitAnswered {
                answerCallWithUUID(uuid: session.uuid, isVideo: existsVideo) { success in
                    if success {
                        self.reportUpdateCall(uuid: session.uuid, hasVideo: existsVideo, from: remoteParty)
                    }
                    completionHandle()
                }
            } else {
                completionHandle()
            }
        } else {
            session = Session()
            session.sessionId = sessionid
            session.videoState = existsVideo
            session.uuid = callUUID

            _ = addCall(call: session)
            completionHandle()
        }
    }

    func answerCall(sessionId: CLong, isVideo: Bool, completion: ((Bool) -> Void)? = nil) -> (Int32) {
        guard let result = findCallBySessionID(sessionId) else {
            completion?(false)
            return 2
        }
        if _enableCallKit {
            if isHideCallkit {
                return answerCallWithUUID(uuid: result.session.uuid, isVideo: isVideo, completion: completion)
            } else {
                print("isHideCallkit = false")
                result.session.videoState = isVideo
                result.session.callKitCompletionCallback = completion
                reportAnswerCall(uuid: result.session.uuid)
                return 3
            }
        } else {
            return answerCallWithUUID(uuid: result.session.uuid, isVideo: isVideo, completion: completion)
        }
    }

    func endCall(sessionid: CLong) -> Int32{
        guard let result = findCallBySessionID(sessionid) else {
            return 4
        }
        var statusCode: Int32 = -1
        if _enableCallKit {
            if isHideCallkit {
                statusCode = hungUpCall(uuid: result.session.uuid)
            } else {
                let sesion = result.session as Session
                reportEndCall(uuid: sesion.uuid)
                statusCode = 0 // CallKit operations assume success
            }

        } else {
            statusCode = hungUpCall(uuid: result.session.uuid)
        }
        return statusCode
    }

    func holdCall(sessionid: CLong, onHold: Bool) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }
        if !result.session.sessionState || result.session.holdState == onHold {
            return
        }
        
        if(_enableCallKit){
            reportSetHeld(uuid:result.session.uuid, onHold: onHold)
        }else{
            holdCall(uuid: result.session.uuid, onHold: onHold)
        }
        
    }

    func holdAllCall(onHold: Bool) {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].sessionState,
                sessionArray[i].holdState != onHold {
                holdCall(sessionid: sessionArray[i].sessionId, onHold: onHold)
            }
        }
    }

    func muteCall(sessionid: CLong, muted: Bool) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }
        if !result.session.sessionState {
            return
        }
        if _enableCallKit {
            if isHideCallkit {
                muteCall(muted, uuid: result.session.uuid)
            } else {
                reportSetMute(uuid: result.session.uuid, muted: muted)
            }
        } else {
            muteCall(muted, uuid: result.session.uuid)
        }
    }

    func muteAllCall(muted: Bool) {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].sessionState {
                muteCall(sessionid: sessionArray[i].sessionId, muted: muted)
            }
        }
    }

    func playDtmf(sessionid: CLong, tone: Int) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }

        if !result.session.sessionState {
            return
        }
        sendDTMF(uuid: result.session.uuid, dtmf: Int32(tone))
    }

    func createConference(conferenceVideoWindow: PortSIPVideoRenderView?, videoWidth: Int, videoHeight: Int, displayLocalVideoInConference: Bool) -> (Bool) {
        if isConference {
            return false
        }
        
        // 🔍 DEBUG: Log all sessions before creating conference
        NSLog("🔍 createConference - DEBUG: Checking all sessions:")
        for i in 0 ..< MAX_LINES {
            NSLog("🔍   Line[\(i)]: hasAdd=\(sessionArray[i].hasAdd), sessionId=\(sessionArray[i].sessionId), sessionState=\(sessionArray[i].sessionState), holdState=\(sessionArray[i].holdState)")
        }
        
        var ret = 0
        if conferenceVideoWindow != nil, videoWidth > 0, videoHeight > 0 {
            ret = Int(_portSIPSDK.createVideoConference(conferenceVideoWindow, videoWidth: Int32(videoWidth), videoHeight: Int32(videoHeight), layout: 0))
        } else {
            ret = Int(_portSIPSDK.createAudioConference())
        }

        if ret != 0 {
            isConference = false
            return false
        }

        isConference = true

        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd {
                NSLog("createConference... join: sessionId=\(sessionArray[i].sessionId) - line=\(i)")
                _portSIPSDK.setRemoteVideoWindow(sessionArray[i].sessionId, remoteVideoWindow: nil)
                joinToConference(sessionid: sessionArray[i].sessionId)
            }
        }
        return true
    }

    func joinToConference(sessionid: CLong) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }
        if !result.session.sessionState || !isConference {
            return
        }

        if _enableCallKit {
            if isHideCallkit {
                joinToConference(uuid: result.session.uuid)
                if(result.session.holdState){
                    holdCall(uuid: result.session.uuid, onHold: false);
                }
            } else {
                if(_conferenceGroupID==nil){
                    _conferenceGroupID = result.session.uuid
                }else{
                    var groupWith = findCallByUUID(uuid:_conferenceGroupID)
                    if(groupWith==nil){
                        groupWith =  findAnotherCall(result.session.sessionId)
                    }
                    
                    if(groupWith==nil){
                        _conferenceGroupID = result.session.uuid
                    }else{
                        _conferenceGroupID = groupWith?.session.uuid
                    }
                }
                
                if(_conferenceGroupID == result.session.uuid){
                    joinToConference(uuid: result.session.uuid)
                }else{
                    reportRemoveFromConference(uuid:result.session.uuid);
                    reportJoninConference(uuid:result.session.uuid);
                }
            }
           
        }else{
            joinToConference(uuid: result.session.uuid)
            if(result.session.holdState){
                holdCall(uuid: result.session.uuid, onHold: false);
            }
        }
        
    }

    func removeFromConference(sessionid: CLong) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }

        if !isConference {
            return
        }

        if _enableCallKit {
            if isHideCallkit {
                removeFromConference(uuid: result.session.uuid)
            } else {
                reportRemoveFromConference(uuid: result.session.uuid)
            }
        } else {
            removeFromConference(uuid: result.session.uuid)
        }
    }

    func destoryConference() {
        if isConference {
            for i in 0 ..< MAX_LINES {
                if sessionArray[i].hasAdd {
                    removeFromConference(sessionid: sessionArray[i].sessionId)
                }
            }
        }
        _portSIPSDK.destroyConference()
        _conferenceGroupID = nil
        isConference = false
        print("DestoryConference")
    }
    
    func hangUpAllCalls(){
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].sessionId > INVALID_SESSION_ID {
                let res = _portSIPSDK.hangUp(sessionArray[i].sessionId)
                if res == 0 {
                    NSLog("Hang up on line=\(i) - sessionId=\(sessionArray[i].sessionId)")
                    reportEndCall(uuid: sessionArray[i].uuid)
                    sessionArray[i].sessionId = CLong(INVALID_SESSION_ID)
                } else {
                    NSLog("Hang up on sessionId=\(sessionArray[i].sessionId) failed with status: \(res)")
                }
            }
        }
    }

    //    Call Manager implementation

    func makeCallWithUUID(callee: String, displayName: String?, videoCall: Bool, uuid: UUID) -> (CLong) {
        let result = findCallByUUID(uuid: uuid)
        if result != nil {
            return result!.session.sessionId
        }
        let num = getConnectCallNum()
        if num >= MAX_LINES {
            return (CLong)(INVALID_SESSION_ID)
        }
        let sessionid = _portSIPSDK.call(callee, sendSdp: true, videoCall: videoCall)

        if sessionid <= 0 {
            return sessionid
        }
        if displayName == nil {
            //            displayName = callee
        }
        let session = Session()
        session.uuid = uuid
        session.sessionId = sessionid
        session.originCallSessionId = -1
        session.videoState = videoCall
        session.outgoing = true

        _ = addCall(call: session)
        delegate?.onNewOutgoingCall(sessionid: sessionid)
        return session.sessionId
    }

    func answerCallWithUUID(uuid: UUID, isVideo: Bool, completion: ((Bool) -> Void)? = nil) -> (Int32) {
        let sessionCall = findCallByUUID(uuid: uuid)
        guard sessionCall != nil else {
            completion?(false)
            return 2
        }

        if sessionCall!.session.sessionId <= INVALID_SESSION_ID {
            // Haven't received INVITE CALL
            sessionCall!.session.callKitAnswered = true
            // Store the completion handler to be called when ready
            sessionCall!.session.callKitCompletionCallback = completion
            return 0
        } else {
            // Execute answer once ready
            let performAnswer: () -> Void = { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else {
                        completion?(false)
                        return
                    }
                    let nRet = strongSelf._portSIPSDK.answerCall(sessionCall!.session.sessionId, videoCall: isVideo)
                    if nRet == 0 {
                        sessionCall!.session.sessionState = true
                        sessionCall!.session.videoState = isVideo
                        if strongSelf.isConference {
                            strongSelf.joinToConference(sessionid: sessionCall!.session.sessionId)
                        }
                        strongSelf.delegate?.onAnsweredCall(sessionId: sessionCall!.session.sessionId)
                        print("Answer Call on session \(sessionCall!.session.sessionId)")
                        completion?(true)
                    } else {
                        strongSelf.delegate?.onCloseCall(sessionId: sessionCall!.session.sessionId)
                        print("Answer Call on session \(sessionCall!.session.sessionId) Failed! ret = \(nRet)")
                        completion?(false)
                    }
                }
            }

            // If configured to wait for socket readiness and not yet ready, queue the answer
            if waitSocketBeforeAnswer && (!isSocketReady || !isCallIncoming || !isForeground) && pendingAnswerBlocks.isEmpty{
                pendingAnswerBlocks.append(performAnswer)
                print("Queued answer until socket is ready for session \(sessionCall!.session.sessionId)")
            } else {
                print("Answer call immediately for session \(sessionCall!.session.sessionId) isSocketReady: \(isSocketReady) isCallIncoming: \(isCallIncoming) pendingAnswerBlocks: \(pendingAnswerBlocks.count) waitSocketBeforeAnswer: \(waitSocketBeforeAnswer)")
                performAnswer()
            }
            return 0 // Return immediately since we're handling the answer asynchronously
        }
    }

    func hungUpCall(uuid: UUID) -> Int32{
        guard let result = findCallByUUID(uuid: uuid) else {
            return -1
        }
        
        var hangUpRet: Int32 = -1
        if isConference {
            removeFromConference(sessionid: result.session.sessionId)
        }

        if result.session.sessionState {
            hangUpRet = Int32(_portSIPSDK.hangUp(result.session.sessionId))
            if result.session.videoState {}
            print("Hungup call on session \(result.session.sessionId) with status: \(hangUpRet)")
        } else if result.session.outgoing {
            hangUpRet = Int32(_portSIPSDK.hangUp(result.session.sessionId))
            print("Invite call Failure on session \(result.session.sessionId) with status: \(hangUpRet)")
        } else {
            hangUpRet = Int32(_portSIPSDK.rejectCall(result.session.sessionId, code: 486))
            print("Rejected call on session \(result.session.sessionId) with status: \(hangUpRet)")
        }

        delegate?.onCloseCall(sessionId: result.session.sessionId)
        return hangUpRet
    }

    func holdCall(uuid: UUID, onHold: Bool) {
        guard let result = findCallByUUID(uuid: uuid) else {
            NSLog("CallManager - holdCall - canot find session by uuid: \(uuid)")
            return
        }
        if !result.session.sessionState ||
            result.session.holdState == onHold {
            NSLog("CallManager - holdCall - sessionState: \(result.session.sessionState), holdState: \(result.session.holdState)")
            return
        }

        if onHold {
            _portSIPSDK.hold(result.session.sessionId)
            result.session.holdState = true
            print("Hold call on session: \(result.session.sessionId)")
        } else {
            _portSIPSDK.unHold(result.session.sessionId)
            result.session.holdState = false
            print("UnHold call on session: \(result.session.sessionId)")
        }
        delegate?.onHoldCall(sessionId: result.session.sessionId, onHold: onHold)
    }

    public func muteCall(_ mute: Bool, uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if result.session.sessionState {
            if mute {
                _portSIPSDK.muteSession(result.session.sessionId,
                                        muteIncomingAudio: false,
                                        muteOutgoingAudio: true,
                                        muteIncomingVideo: false,
                                        muteOutgoingVideo: true)
            } else {
                _portSIPSDK.muteSession(result.session.sessionId,
                                        muteIncomingAudio: false,
                                        muteOutgoingAudio: false,
                                        muteIncomingVideo: false,
                                        muteOutgoingVideo: false)
            }
            delegate?.onMuteCall(sessionId: result.session.sessionId, muted: mute)
        }
    }

    public func sendDTMF(uuid: UUID, dtmf: Int32) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }

        if result.session.sessionState {
            _portSIPSDK.sendDtmf(result.session.sessionId, dtmfMethod: _playDTMFMethod, code: dtmf, dtmfDration: 160, playDtmfTone: _playDTMFTone)
        }
    }

    public func joinToConference(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if isConference {
            if result.session.sessionState {
                let joinRes = _portSIPSDK.join(toConference: result.session.sessionId)
                NSLog("joinConference response=\(joinRes)")
                if(result.session.holdState){
                    holdCall(uuid: result.session.uuid, onHold: false);
                }
                _portSIPSDK.setRemoteVideoWindow(result.session.sessionId, remoteVideoWindow: nil)
                _portSIPSDK.setRemoteScreenWindow(result.session.sessionId, remoteScreenWindow: nil)
                _portSIPSDK.sendVideo(result.session.sessionId, sendState: true)
            }
        }
    }

    public func removeFromConference(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }

        if isConference {
            _portSIPSDK.remove(fromConference: result.session.sessionId)
        }
    }

    public func findCallBySessionID(_ sessionID: CLong) -> (session: Session, index: Int)? {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].sessionId == sessionID {
                return (sessionArray[i], i)
            }
        }
        return nil
    }

    public func findAnotherCall(_ sessionID: CLong) -> (session: Session, index: Int)? {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].sessionId != sessionID {
                return (sessionArray[i], i)
            }
        }
        return nil
    }

    public func findCallByOrignalSessionID(sessionID: CLong) -> (session: Session, index: Int)? {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].originCallSessionId == sessionID {
                return (sessionArray[i], i)
            }
        }
        return nil
    }

    public func findCallByUUID(uuid: UUID) -> (session: Session, index: Int)? {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].uuid == uuid {
                return (sessionArray[i], i)
            }
        }
        return nil
    }

    public func addCall(call: Session) -> (Int) {
        NSLog("🟢 addCall - BEFORE: sessionId=\(call.sessionId), uuid=\(call.uuid)")
        for i in 0 ..< MAX_LINES {
            NSLog("🟢   Line[\(i)]: hasAdd=\(sessionArray[i].hasAdd), sessionId=\(sessionArray[i].sessionId)")
        }
        
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd == false {
                sessionArray[i] = call
                sessionArray[i].hasAdd = true
                NSLog("🟢 addCall - SUCCESS: Added sessionId=\(call.sessionId) to line[\(i)]")
                return i
            }
        }
        NSLog("🔴 addCall - FAILED: No available line for sessionId=\(call.sessionId)")
        return -1
    }

    public func removeCall(call: Session) {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i] === call {
                NSLog("🔴 removeCall - Removing session: sessionId=\(sessionArray[i].sessionId), line=\(i)")
                NSLog("🔴   Stack trace: \(Thread.callStackSymbols.joined(separator: "\n"))")
                sessionArray[i].reset()
            }
        }
    }

    public func clear() {
        isSocketReady = false
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd {
                _portSIPSDK.hangUp(sessionArray[i].sessionId)
                sessionArray[i].reset()
            }
        }
    }

    public func getConnectCallNum() -> Int {
        var num: Int = 0
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd {
                num += 1
            }
        }
        return num
    }
    
    func configureAudioSession() {
        _portSIPSDK.configureAudioSession()
        print("_portSIPSDK configureAudioSession")
    }

    func startAudio(audioSession: AVAudioSession) {
        _portSIPSDK.startAudio(audioSession)
        print("_portSIPSDK starxtAudio")
    }

    func stopAudio(audioSession: AVAudioSession) {
        _portSIPSDK.stopAudio(audioSession)
        print("_portSIPSDK stopAudio")
    }
}

// Audio Controller
