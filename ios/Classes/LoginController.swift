import UIKit
import PortSIPVoIPSDK
private func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

enum LOGIN_STATUS: Int {
    case LOGIN_STATUS_OFFLINE,
         LOGIN_STATUS_LOGIN,
         LOGIN_STATUS_ONLINE,
         LOGIN_STATUS_FAILUE
}

class LoginViewController {
    
    private var portSIPSDK: PortSIPSDK!
    private var sipInitialized = false
    var sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_OFFLINE
    
    var autoRegisterRetryTimes: Int = 0
    var autoRegisterTimer: Timer?
    var srtpItems: [String] = ["NONE", "FORCE", "PREFER"]
    var transPortItems: [String] = ["UDP", "TLS", "TCP"]
    
    init(portSIPSDK: PortSIPSDK!) {
        self.portSIPSDK = portSIPSDK
        self.sipInitialized = false
        self.sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_OFFLINE
        self.autoRegisterRetryTimes = 0
    }
    
    
    func onLine(username: String, displayName: String, authName: String, password: String, userDomain: String, sipServer: String, sipServerPort: Int32, transportType: Int, srtpType: Int, enableDebugLog: Bool)  {
        
//        if sipInitialized {
//            offLine()
//        }
        
        let transport = TRANSPORT_TCP
        //        switch userData["transport"] {
        //        case "UDP":
        //            transport = TRANSPORT_UDP
        //        case "TLS":
        //            transport = TRANSPORT_TLS
        //        case "TCP":
        //            transport = TRANSPORT_TCP
        //        default:
        //            break
        //        }
        
        let srtp = SRTP_POLICY_NONE
        //        switch userData["srtp"] {
        //        case "FORCE":
        //            srtp = SRTP_POLICY_FORCE
        //        case "PREFER":
        //            srtp = SRTP_POLICY_PREFER
        //        default:
        //            srtp = SRTP_POLICY_NONE
        //        }
        
        let localPort = 10000 + arc4random() % 2000
        let loaclIPaddress = "0.0.0.0"
        let appDelegate = MptCallkitPlugin.shared
        
        let logPath: String
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first{
            logPath = documentsDirectory.path
        } else {
            logPath = ""
        }
        
        print("Initialize SDk with enableDebugLog \(enableDebugLog) - logPath \(logPath)")
        
        let ret = portSIPSDK.initialize(transport, localIP: loaclIPaddress, localSIPPort: Int32(localPort), loglevel: enableDebugLog ? PORTSIP_LOG_DEBUG : PORTSIP_LOG_NONE, logPath: enableDebugLog ? logPath : "", maxLine: 8, agent: "PortSIP SDK for IOS", audioDeviceLayer: 0, videoDeviceLayer: 0, tlsCertificatesRootPath: "", tlsCipherList: "", verifyTLSCertificate: false, dnsServers: "")
        
        if ret != 0 {
            print("Initialize failure ErrorCode = \(ret)")
            return
        }
        let retUser = portSIPSDK.setUser(username, displayName:displayName, authName: authName, password: password, userDomain: userDomain, sipServer: sipServer, sipServerPort: sipServerPort, stunServer: "", stunServerPort: 0, outboundServer: "", outboundServerPort: 0)
        
        if retUser != 0 {
            print("Set user failure ErrorCode = \(retUser)")
            return
        }
        
        _ = portSIPSDK.setLicenseKey("PORTSIP_TEST_LICENSE")
        
        portSIPSDK.addAudioCodec(AUDIOCODEC_OPUS)
        portSIPSDK.addAudioCodec(AUDIOCODEC_G729)
        portSIPSDK.addAudioCodec(AUDIOCODEC_PCMA)
        portSIPSDK.addAudioCodec(AUDIOCODEC_PCMU)
        
        // portSIPSDK.addAudioCodec(AUDIOCODEC_GSM);
        // portSIPSDK.addAudioCodec(AUDIOCODEC_ILBC);
        // portSIPSDK.addAudioCodec(AUDIOCODEC_AMR);
        // portSIPSDK.addAudioCodec(AUDIOCODEC_SPEEX);
        // portSIPSDK.addAudioCodec(AUDIOCODEC_SPEEXWB);
        portSIPSDK.addAudioCodec(AUDIOCODEC_DTMF)
        
        portSIPSDK.addVideoCodec(VIDEO_CODEC_H264)
        portSIPSDK.addVideoCodec(VIDEO_CODEC_VP8);
        portSIPSDK.addVideoCodec(VIDEO_CODEC_VP9);
        
        // portSIPSDK.setVideoBitrate(-1, bitrateKbps: 512) // Higher bitrate for better quality
        portSIPSDK.setVideoBitrate(-1, bitrateKbps: 2048) // Higher bitrate for better quality
        portSIPSDK.setVideoFrameRate(-1, frameRate: 30) // Higher frame rate for smoother video
        // portSIPSDK.setVideoResolution(1280, height: 720) // 1080P resolution
        portSIPSDK.setVideoResolution(1920, height: 1080) // 1080P resolution
        portSIPSDK.setAudioSamples(20, maxPtime: 60) // ptime 20
        
        // 1 - FrontCamra 0 - BackCamra
        portSIPSDK.setVideoDeviceId(1)
        
        // enable video RTCP nack
        portSIPSDK.setVideoNackStatus(true)
    
        // enable srtp
        portSIPSDK.setSrtpPolicy(srtp)
        portSIPSDK.setInstanceId(UIDevice.current.identifierForVendor?.uuidString)
        
        let portSipPlugin = MptCallkitPlugin.shared
        
        portSipPlugin.addPushSupportWithPortPBX(portSipPlugin._enablePushNotification!)
        sipInitialized = true
        sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_LOGIN
        
        portSIPSDK.registerServer(90, retryTimes: 0)
        var sipURL: String
        if sipServerPort == 5063 {
            sipURL = "sip:\(username):\(userDomain)"
        } else {
            sipURL = "sip:\(username):\(userDomain):\(String(describing: sipServerPort))"
        }
        
        appDelegate.sipURL = sipURL
        print("Registration initiated...")
    }
    
    func offLine() {
        var unReg : Int32 = 1
        
        if sipInitialized {
            // Hủy bỏ cuộc gọi đang diễn ra nếu có
            if let activeSessionId = MptCallkitPlugin.shared.activeSessionid,
               let callManager = MptCallkitPlugin.shared._callManager {
                if let currentCall = callManager.findCallBySessionID(activeSessionId) {
                    callManager.hungUpCall(uuid: currentCall.session.uuid)
                }
            }
            
            // Unregister và cleanup
            unReg = portSIPSDK.unRegisterServer(90)
            portSIPSDK.unInitialize()
            sipInitialized = false
            sipRegistrationStatus = .LOGIN_STATUS_OFFLINE
            if (unReg == 0){
                print("Unregister success")
                MptCallkitPlugin.shared.methodChannel?.invokeMethod("onlineStatus", arguments: false)
            }
            print("SIP Unregistered and Offline")
        }

        print("Offline and Unregistered - unRegister: \(unReg)")
    }
    
    func refreshRegister() {
        
        print("refreshRegister: \(sipRegistrationStatus)")
        switch sipRegistrationStatus {
        case .LOGIN_STATUS_OFFLINE:
            //Not register
            break
        case .LOGIN_STATUS_LOGIN:
            portSIPSDK.refreshRegistration(0)
            break
        case .LOGIN_STATUS_ONLINE:
            portSIPSDK.refreshRegistration(0)
            print("Refresh Registration...")
        case .LOGIN_STATUS_FAILUE:
            portSIPSDK.unRegisterServer(90)
            portSIPSDK.unInitialize()
            sipInitialized = false
            MptCallkitPlugin.shared.methodChannel?.invokeMethod("onHangOut", arguments: true)
        }
    }
    
    func unRegister() {
        if sipRegistrationStatus == .LOGIN_STATUS_LOGIN || sipRegistrationStatus == .LOGIN_STATUS_ONLINE {
            portSIPSDK.unRegisterServer(90)
            print("unRegister when background")
            sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_FAILUE
        }
         refreshRegister()
    }
    
    func onRegisterSuccess(statusText: String) {
        print("Registration success: \(statusText)")
        sipRegistrationStatus = .LOGIN_STATUS_ONLINE
        MptCallkitPlugin.shared.methodChannel?.invokeMethod("onlineStatus", arguments: true)
        autoRegisterRetryTimes = 0
    }
    
    func onRegisterFailure(statusCode: CInt, statusText: String) {
        print("Registration failure: \(statusText)")
        
        sipRegistrationStatus = .LOGIN_STATUS_FAILUE
        MptCallkitPlugin.shared.methodChannel?.invokeMethod("onlineStatus", arguments: false)
        
        if statusCode != 401, statusCode != 403, statusCode != 404 {
            var interval = TimeInterval(autoRegisterRetryTimes * 2 + 1)
            interval = min(interval, 60)
            autoRegisterRetryTimes += 1
        }
    }
}
