//
//  PortCxProvider.swift
//  SipSample
//
//  Created by portsip on 17/2/22.
//  Copyright © 2017 portsip. All rights reserved.
//

import CallKit
import UIKit
import AVFAudio
import PortSIPVoIPSDK

@available(iOS 10.0, *)
class PortCxProvider: NSObject, CXProviderDelegate {
    var cxprovider: CXProvider!
    var callManager: CallManager!
    var callController: CXCallController!
    private static var instance: PortCxProvider = PortCxProvider()

    class var shareInstance: PortCxProvider {
        PortCxProvider.instance
    }

    override init() {
        super.init()
        configurationCallProvider()
    }

    func configurationCallProvider() {
        let infoDic = Bundle.main.infoDictionary!
        let localizedName = infoDic["CFBundleName"] as! String

        let providerConfiguration = CXProviderConfiguration(localizedName: localizedName)
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 2
        providerConfiguration.supportedHandleTypes = [.phoneNumber]
        if let iconMaskImage = UIImage(named: "IconMask") {
            providerConfiguration.iconTemplateImageData = iconMaskImage.pngData()
        }

        cxprovider = CXProvider(configuration: providerConfiguration)

        cxprovider.setDelegate(self, queue: DispatchQueue.main)

        callController = CXCallController()
    }

    func reportOutgoingCall(callUUID: UUID, startDate: Date) -> (UUID) {
        cxprovider.reportOutgoingCall(with: callUUID, connectedAt: startDate)
        return callUUID
    }

//    #pragma mark - CXProviderDelegate

    func providerDidReset(_: CXProvider) {
        //callManager.stopAudio()
        NSLog("Provider did reset")

        callManager.clear()
    }

    func provider(_: CXProvider, perform action: CXPlayDTMFCallAction) {
        NSLog(" CXPlayDTMFCallAction \(action.callUUID) \(action.digits)")

        var dtmf: Int32 = 0
        switch action.digits {
        case "0":
            dtmf = 0
        case "1":
            dtmf = 1
        case "2":
            dtmf = 2
        case "3":
            dtmf = 3
        case "4":
            dtmf = 4
        case "5":
            dtmf = 5
        case "6":
            dtmf = 6
        case "7":
            dtmf = 7
        case "8":
            dtmf = 8
        case "9":
            dtmf = 9
        case "*":
            dtmf = 10
        case "#":
            dtmf = 11
        default:
            return
        }
        callManager.sendDTMF(uuid: action.callUUID, dtmf: dtmf)
        action.fulfill()
    }

    func provider(_: CXProvider, timedOutPerforming _: CXAction) {}

    func provider(_: CXProvider, perform action: CXSetGroupCallAction) {
        guard callManager.findCallByUUID(uuid: action.callUUID) != nil else {
            action.fail()
            return
        }

        if action.callUUIDToGroupWith != nil {
            callManager.joinToConference(uuid: action.callUUID)
            action.fulfill()
        } else {
            callManager.removeFromConference(uuid: action.callUUID)
            action.fulfill()
        }

        action.fulfill()
    }

    func performAnswerCall(uuid: UUID, completion completionHandler: @escaping (_ success: Bool) -> Void) {
        let session = callManager.findCallByUUID(uuid: uuid)
        NSLog("performAnswerCall session = \(session)")

        if session != nil {
            if session!.session.sessionId <= INVALID_SESSION_ID {
                NSLog("performAnswerCall sessionId <= INVALID_SESSION_ID")
                // Haven't received INVITE CALL
                session?.session.callKitAnswered = true
                session?.session.callKitCompletionCallback = completionHandler
            } else {
                NSLog("performAnswerCall sessionId > INVALID_SESSION_ID")
                if (callManager.answerCallWithUUID(uuid: uuid, isVideo: session?.session.videoState ?? false) == 0) {
                    NSLog("performAnswerCall answerCallWithUUID success")
                    completionHandler(true)
                } else {
                    NSLog("performAnswerCall answerCallWithUUID failed")
                    completionHandler(false)
                }
            }
        } else {
            NSLog("Session not found")

            completionHandler(false)
        }
    }

    func provider(_: CXProvider, perform action: CXAnswerCallAction) {
        NSLog("CXAnswerCallAction start ...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.callManager.configureAudioSession()
            NSLog("CXAnswerCallAction configureAudioSession ...")
            strongSelf.performAnswerCall(uuid: action.callUUID) { success in
                if success {
                    action.fulfill()
                    NSLog("performAnswerCallAction success")
                } else {
                    action.fail()
                    NSLog("performAnswerCallAction fail")
                }
            }
        }
        // [action fulfill];
        
    }

    func provider(_: CXProvider, perform action: CXStartCallAction) {
        NSLog("performStartCallAction uuid = \(action.callUUID)")
        callManager.configureAudioSession()
        let sessionid = callManager.makeCallWithUUID(callee: action.handle.value, displayName: action.handle.value, videoCall: action.isVideo, uuid: action.callUUID)
        NSLog("performStartCallAction sessionid: \(sessionid)")
        if sessionid >= 0 {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_: CXProvider, perform action: CXEndCallAction) {
        if callManager.callkitIsShowing {
            callManager.callkitIsShowing = false
        }
        let result = callManager.findCallByUUID(uuid: action.callUUID)
        if result != nil {
            callManager.hungUpCall(uuid: action.callUUID)
        }

        action.fulfill()
    }

    func provider(_: CXProvider, perform action: CXSetHeldCallAction) {
        let result = callManager.findCallByUUID(uuid: action.callUUID)
        if result != nil {
            callManager.holdCall(uuid: action.callUUID, onHold: action.isOnHold)
        }

        action.fulfill()
    }

    func provider(_: CXProvider, perform action: CXSetMutedCallAction) {
        let result = callManager.findCallByUUID(uuid: action.callUUID)
        if result != nil {
            callManager.muteCall(action.isMuted, uuid: action.callUUID)
        }
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        callManager.startAudio(audioSession: audioSession)
    }


    func provider(_: CXProvider, didDeactivate audioSession: AVAudioSession) {
        callManager.stopAudio(audioSession: audioSession)
    }
}
