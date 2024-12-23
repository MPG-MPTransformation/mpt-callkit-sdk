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
    
    
    func onLine(username: String, displayName: String, authName: String, password: String, userDomain: String, sipServer: String, sipServerPort: Int32, transportType: Int, srtpType: Int)  {
        
        if sipInitialized {
            print("You already registered, go offline first!")
            return
        }
        
        let transport = TRANSPORT_UDP
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
        
        let ret = portSIPSDK.initialize(transport, localIP: loaclIPaddress, localSIPPort: Int32(localPort), loglevel: PORTSIP_LOG_NONE, logPath: "", maxLine: 8, agent: "PortSIP SDK for IOS", audioDeviceLayer: 0, videoDeviceLayer: 0, tlsCertificatesRootPath: "", tlsCipherList: "", verifyTLSCertificate: false, dnsServers: "")
        
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
        
        portSIPSDK.setVideoBitrate(-1, bitrateKbps: 512) // video send bitrate,500kbps
        portSIPSDK.setVideoFrameRate(-1, frameRate: 20)
        portSIPSDK.setVideoResolution(480, height: 640)
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
        if sipServerPort == 5060 {
            sipURL = "sip:\(username):\(userDomain)"
        } else {
            sipURL = "sip:\(username):\(userDomain):\(String(describing: sipServerPort))"
        }
        
        appDelegate.sipURL = sipURL
        print("Registration initiated...")
    }
    
    func offLine() {
        if sipInitialized {
            portSIPSDK.unRegisterServer(90)
            portSIPSDK.unInitialize()
            sipInitialized = false
            sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_OFFLINE
        }
        print("Offline and Unregistered")
    }
    
    func refreshRegister() {
        switch sipRegistrationStatus {
        case .LOGIN_STATUS_OFFLINE:
            break
        case .LOGIN_STATUS_LOGIN:
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
            print("Unregistered when in background")
            sipRegistrationStatus = .LOGIN_STATUS_FAILUE
        }
        refreshRegister()
    }
    
    func onRegisterSuccess(statusText: String) {
        print("Registration success: \(statusText)")
        sipRegistrationStatus = .LOGIN_STATUS_ONLINE
        autoRegisterRetryTimes = 0
    }
    
    func onRegisterFailure(statusCode: CInt, statusText: String) {
        print("Registration failure: \(statusText)")
        
        sipRegistrationStatus = .LOGIN_STATUS_FAILUE
        
        if statusCode != 401, statusCode != 403, statusCode != 404 {
            var interval = TimeInterval(autoRegisterRetryTimes * 2 + 1)
            interval = min(interval, 60)
            autoRegisterRetryTimes += 1
            
        }
    }
}
