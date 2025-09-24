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
    public var sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_OFFLINE
    
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
    
    
    func onLine(username: String, displayName: String, authName: String, password: String, userDomain: String, sipServer: String, sipServerPort: Int32, transportType: Int, srtpType: Int, enableDebugLog: Bool, resolution: String = "720P", bitrate: Int = 1024, frameRate: Int = 30, autoLogin: Bool = false)  {
        
        if sipInitialized {
            return
        }
        
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

        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(displayName, forKey: "displayName")
        UserDefaults.standard.set(authName, forKey: "authName")
        UserDefaults.standard.set(password, forKey: "password")
        UserDefaults.standard.set(userDomain, forKey: "userDomain")
        UserDefaults.standard.set(sipServer, forKey: "sipServer")
        UserDefaults.standard.set(sipServerPort, forKey: "sipServerPort")
        UserDefaults.standard.set(transportType, forKey: "transportType")
        UserDefaults.standard.set(srtpType, forKey: "srtpType")
        UserDefaults.standard.set(localPort, forKey: "localPort")
        UserDefaults.standard.set(enableDebugLog, forKey: "enableDebugLog")
        UserDefaults.standard.set(resolution, forKey: "resolution")
        UserDefaults.standard.set(bitrate, forKey: "bitrate")
        UserDefaults.standard.set(frameRate, forKey: "frameRate")
        UserDefaults.standard.set(autoLogin, forKey: "autoLogin")
        
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
        
        // Apply video params
        portSIPSDK.setVideoBitrate(-1, bitrateKbps: Int32(bitrate))
        portSIPSDK.setVideoFrameRate(-1, frameRate: Int32(frameRate))
        
        var width = 1280
        var height = 720
        switch resolution.uppercased() {
        case "QCIF":
            width = 176; height = 144
        case "CIF":
            width = 352; height = 288
        case "VGA":
            width = 640; height = 480
        case "720P":
            width = 1280; height = 720
        case "1080P":
            width = 1920; height = 1080
        default:
            width = 1280; height = 720
        }
        portSIPSDK.setVideoResolution(Int32(width), height: Int32(height))
        portSIPSDK.setAudioSamples(20, maxPtime: 60)
        
        // 1 - FrontCamra 0 - BackCamra
        portSIPSDK.setVideoDeviceId(1)
        
        // enable video RTCP nack
        portSIPSDK.setVideoNackStatus(true)
    
        // enable srtp
        portSIPSDK.setSrtpPolicy(srtp)
        
        // single instance extension
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
            Thread.sleep(forTimeInterval: 1.0)
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
            break
        case .LOGIN_STATUS_LOGIN:
            break
        case .LOGIN_STATUS_ONLINE:
            portSIPSDK.refreshRegistration(0)
            print("Refresh Registration...")
            break
        case .LOGIN_STATUS_FAILUE:
            portSIPSDK.unRegisterServer(90)
            portSIPSDK.unInitialize()
            sipInitialized = false
            MptCallkitPlugin.shared.methodChannel?.invokeMethod("onlineStatus", arguments: false)
            autoOnline()
            print("Registration failed, re-initiating registration...")
        }
    }

    func autoOnline() {
        print("Auto online with saved credentials")
        guard let username = UserDefaults.standard.string(forKey: "username"),
              let displayName = UserDefaults.standard.string(forKey: "displayName"),
              let authName = UserDefaults.standard.string(forKey: "authName"),
              let password = UserDefaults.standard.string(forKey: "password"),
              let userDomain = UserDefaults.standard.string(forKey: "userDomain"),
              let sipServer = UserDefaults.standard.string(forKey: "sipServer"),
              let autoLogin = UserDefaults.standard.value(forKey: "autoLogin") as? Bool,
              let sipServerPort = UserDefaults.standard.value(forKey: "sipServerPort") as? Int32,
              let transportType = UserDefaults.standard.value(forKey: "transportType") as? Int,
              let srtpType = UserDefaults.standard.value(forKey: "srtpType") as? Int,
              let enableDebugLog = UserDefaults.standard.value(forKey: "enableDebugLog") as? Bool else {
            print("Failed to retrieve saved credentials")
            return
        }
        let resolution = UserDefaults.standard.string(forKey: "resolution") ?? "720P"
        let bitrate = UserDefaults.standard.value(forKey: "bitrate") as? Int ?? 1024
        let frameRate = UserDefaults.standard.value(forKey: "frameRate") as? Int ?? 30

        self.onLine(username: username, displayName: displayName, authName: authName, password: password, userDomain: userDomain, sipServer: sipServer, sipServerPort: sipServerPort, transportType: transportType, srtpType: srtpType, enableDebugLog: enableDebugLog, resolution: resolution, bitrate: bitrate, frameRate: frameRate)
    }
    
    func unRegister() {
        if sipRegistrationStatus == .LOGIN_STATUS_LOGIN || sipRegistrationStatus == .LOGIN_STATUS_ONLINE {
            print("Force unregister SIP")
            portSIPSDK.unRegisterServer(90)
            sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_FAILUE
        }
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
