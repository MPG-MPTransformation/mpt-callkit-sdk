import Flutter
import PortSIPVoIPSDK
import PushKit
import UIKit

// MARK: - PortSIP Data Types
struct PortSIPCallState {
    let sessionId: Int64
    let hasVideo: Bool
    let hasAudio: Bool
    let isIncoming: Bool
    let remoteParty: String?
    let remoteDisplayName: String?
    let state: CallStateType

    enum CallStateType: String {
        case incoming = "INCOMING"
        case trying = "TRYING"
        case connected = "CONNECTED"
        case answered = "ANSWERED"
        case failed = "FAILED"
        case closed = "CLOSED"
    }
}

struct PortSIPVideoState {
    let sessionId: Int64
    let isVideoEnabled: Bool
    let isCameraOn: Bool
    let useFrontCamera: Bool
}

struct PortSIPAudioState {
    let sessionId: Int64
    let isMicrophoneMuted: Bool
    let isSpeakerOn: Bool
}

// MARK: - PortSIP State Notifications
extension Notification.Name {
    static let portSIPCallIncoming = Notification.Name("PortSIPCallIncoming")
    static let portSIPCallAnswered = Notification.Name("PortSIPCallAnswered")
    static let portSIPCallConnected = Notification.Name("PortSIPCallConnected")
    static let portSIPCallClosed = Notification.Name("PortSIPCallClosed")
    static let portSIPCallFailed = Notification.Name("PortSIPCallFailed")
    static let portSIPCallTrying = Notification.Name("PortSIPCallTrying")
    static let portSIPCallUpdated = Notification.Name("PortSIPCallUpdated")
    static let portSIPVideoStateChanged = Notification.Name("PortSIPVideoStateChanged")
    static let portSIPAudioStateChanged = Notification.Name("PortSIPAudioStateChanged")
    static let portSIPCameraStateChanged = Notification.Name("PortSIPCameraStateChanged")
    static let portSIPMicrophoneStateChanged = Notification.Name("PortSIPMicrophoneStateChanged")
    static let portSIPSpeakerStateChanged = Notification.Name("PortSIPSpeakerStateChanged")
}

// MARK: - PortSIP State Manager
class PortSIPStateManager {
    static let shared = PortSIPStateManager()

    private var currentCallState: PortSIPCallState?
    private var currentVideoState: PortSIPVideoState?
    private var currentAudioState: PortSIPAudioState?

    private init() {}

    // MARK: - Call State Management
    func updateCallState(_ state: PortSIPCallState) {
        currentCallState = state

        let userInfo: [String: Any] = [
            "sessionId": state.sessionId,
            "hasVideo": state.hasVideo,
            "hasAudio": state.hasAudio,
            "isIncoming": state.isIncoming,
            "remoteParty": state.remoteParty ?? "",
            "remoteDisplayName": state.remoteDisplayName ?? "",
            "state": state.state.rawValue,
        ]

        NSLog(
            "PortSIPStateManager: Broadcasting call state - \(state.state.rawValue) for session \(state.sessionId)"
        )

        switch state.state {
        case .incoming:
            NotificationCenter.default.post(
                name: .portSIPCallIncoming, object: nil, userInfo: userInfo)
        case .trying:
            NotificationCenter.default.post(
                name: .portSIPCallTrying, object: nil, userInfo: userInfo)
        case .answered:
            NotificationCenter.default.post(
                name: .portSIPCallAnswered, object: nil, userInfo: userInfo)
        case .connected:
            NotificationCenter.default.post(
                name: .portSIPCallConnected, object: nil, userInfo: userInfo)
        case .failed:
            NotificationCenter.default.post(
                name: .portSIPCallFailed, object: nil, userInfo: userInfo)
        case .closed:
            NotificationCenter.default.post(
                name: .portSIPCallClosed, object: nil, userInfo: userInfo)
        }
    }

    // MARK: - Video State Management
    func updateVideoState(_ state: PortSIPVideoState) {
        currentVideoState = state

        let userInfo: [String: Any] = [
            "sessionId": state.sessionId,
            "isVideoEnabled": state.isVideoEnabled,
            "isCameraOn": state.isCameraOn,
            "useFrontCamera": state.useFrontCamera,
        ]

        NSLog(
            "PortSIPStateManager: Broadcasting video state - enabled: \(state.isVideoEnabled), camera: \(state.isCameraOn)"
        )

        NotificationCenter.default.post(
            name: .portSIPVideoStateChanged, object: nil, userInfo: userInfo)
        NotificationCenter.default.post(
            name: .portSIPCameraStateChanged, object: nil, userInfo: userInfo)
    }

    // MARK: - Audio State Management
    func updateAudioState(_ state: PortSIPAudioState) {
        currentAudioState = state

        let userInfo: [String: Any] = [
            "sessionId": state.sessionId,
            "isMicrophoneMuted": state.isMicrophoneMuted,
            "isSpeakerOn": state.isSpeakerOn,
        ]

        NSLog(
            "PortSIPStateManager: Broadcasting audio state - mic muted: \(state.isMicrophoneMuted), speaker: \(state.isSpeakerOn)"
        )

        NotificationCenter.default.post(
            name: .portSIPAudioStateChanged, object: nil, userInfo: userInfo)
        NotificationCenter.default.post(
            name: .portSIPMicrophoneStateChanged, object: nil, userInfo: userInfo)
        NotificationCenter.default.post(
            name: .portSIPSpeakerStateChanged, object: nil, userInfo: userInfo)
    }

    // MARK: - State Getters
    func getCurrentCallState() -> PortSIPCallState? {
        return currentCallState
    }

    func getCurrentVideoState() -> PortSIPVideoState? {
        return currentVideoState
    }

    func getCurrentAudioState() -> PortSIPAudioState? {
        return currentAudioState
    }

    // MARK: - Clear State
    func clearCallState() {
        currentCallState = nil
        currentVideoState = nil
        currentAudioState = nil
        NSLog("PortSIPStateManager: Call state cleared")
    }
}

public class MptCallkitPlugin: FlutterAppDelegate, FlutterPlugin, PKPushRegistryDelegate,
    CallManagerDelegate, PortSIPEventDelegate
{
    public func onSendOutOfDialogMessageSuccess(
        _ messageId: Int, fromDisplayName: String!, from: String!, toDisplayName: String!,
        to: String!, sipMessage: String!
    ) {
        NSLog("onSendOutOfDialogMessageSuccess messageId: \(messageId)")
    }

    public static let shared = MptCallkitPlugin()
    var methodChannel: FlutterMethodChannel?

    // public method để set APNs push token
    public func setAPNsPushToken(_ token: String) {
        _APNsPushToken = token as NSString
    }

    public func cleanupOnTerminate() {
        // Hang up call if exist call
        if activeSessionid > 0 {
            portSIPSDK.hangUp(activeSessionid)
        }

        portSIPSDK.unRegisterServer(90)
        Thread.sleep(forTimeInterval: 1.0)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "mpt_callkit", binaryMessenger: registrar.messenger())
        let instance = shared
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // REMOVED: No shared view controller instances
        let localFactory = LocalViewFactory(messenger: registrar.messenger())
        registrar.register(localFactory, withId: "LocalView")

        let remoteFactory = RemoteViewFactory(messenger: registrar.messenger())
        registrar.register(remoteFactory, withId: "RemoteView")
    }

    var sipRegistered: Bool!
    var portSIPSDK: PortSIPSDK!
    var mSoundService: SoundService!
    var internetReach: Reachability!
    var _callManager: CallManager!
    var videoManager: VideoManager!

    var sipURL: String?
    var isConference: Bool!
    var conferenceId: Int32!
    var loginViewController: LoginViewController!
    var _activeLine: Int!
    var activeSessionid: CLong!
    var lineSessions: [CLong] = []
    var phone: String = ""
    var displayName: String = ""
    var isVideoCall: Bool = false
    var isRemoteVideoReceived: Bool = false

    var _VoIPPushToken: NSString!
    var _APNsPushToken: NSString!
    var _backtaskIdentifier: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

    var currentSessionid: String = ""
    var xSessionId: String = ""
    var xSessionIdRecv: String = ""
    var currentUsername: String = ""  // Lưu username hiện tại
    var currentRemoteName: String = ""
    var currentLocalizedCallerName: String = ""  // Lưu localizedCallerName
    var currentUUID: UUID? = UUID()

    var _enablePushNotification: Bool?

    var _enableForceBackground: Bool?

    var mUseFrontCamera: Bool = true

    enum CallState: String {
        case INCOMING = "INCOMING"
        case TRYING = "TRYING"
        case CONNECTED = "CONNECTED"
        case IN_CONFERENCE = "IN_CONFERENCE"
        case ANSWERED = "ANSWERED"
        case FAILED = "FAILED"
        case CLOSED = "CLOSED"
    }

    func findSession(sessionid: CLong) -> (Int) {
        for i in 0..<MAX_LINES {
            if lineSessions[i] == sessionid {
                print("findSession, SessionId = \(sessionid)")
                return i
            }
        }
        print("Can't find session, Not exist this SessionId = \(sessionid)")
        return -1
    }

    func findIdleLine() -> (Int) {
        for i in 0..<MAX_LINES {
            if lineSessions[i] == CLong(INVALID_SESSION_ID) {
                return i
            }
        }
        print("No idle line available. All lines are in use.")
        return -1
    }

    func freeLine(sessionid: CLong) {
        for i in 0..<MAX_LINES {
            if lineSessions[i] == sessionid {
                lineSessions[i] = CLong(INVALID_SESSION_ID)
                return
            }
        }
        print("Can't Free Line, Not exist this SessionId = \(sessionid)")
    }

    override init() {
        super.init()
        portSIPSDK = PortSIPSDK()
        portSIPSDK.delegate = self
        mSoundService = SoundService()
        // change "CallKit" to true if wanna use iOS CallKit
        UserDefaults.standard.register(defaults: ["CallKit": true])
        UserDefaults.standard.register(defaults: ["PushNotification": true])
        UserDefaults.standard.register(defaults: ["ForceBackground": false])

        let enableCallKit = UserDefaults.standard.bool(forKey: "CallKit")
        _enablePushNotification = UserDefaults.standard.bool(forKey: "PushNotification")
        _enableForceBackground = UserDefaults.standard.bool(forKey: "ForceBackground")
        
        // Load localizedCallerName from UserDefaults
        currentLocalizedCallerName = loadLocalizedCallerName()
        currentRemoteName = currentLocalizedCallerName

        let cxProvider = PortCxProvider.shareInstance
        _callManager = CallManager(portsipSdk: portSIPSDK)
        _callManager.delegate = self
        _callManager.enableCallKit = enableCallKit
        cxProvider.callManager = _callManager

        _activeLine = 0
        activeSessionid = CLong(INVALID_SESSION_ID)
        for _ in 0..<MAX_LINES {
            lineSessions.append(CLong(INVALID_SESSION_ID))
        }

        sipRegistered = false
        isConference = false

        loginViewController = LoginViewController(portSIPSDK: portSIPSDK)

        videoManager = VideoManager(portSIPSDK: portSIPSDK)

        internetReach = Reachability.forInternetConnection()
        startNotifierNetwork()

        _ = UNUserNotificationCenter.current()
        let mainQueue = DispatchQueue.main
        let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
        // voip push
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [PKPushType.voIP]

        // im push
        let notifiCenter = UNUserNotificationCenter.current()
        notifiCenter.delegate = self
        notifiCenter.requestAuthorization(options: [.alert, .sound, .badge]) { accepted, _ in

            if !accepted {
                print("Permission granted: \(accepted)")
            }
        }
        setupNotificationHandling()
        // setupViewLifecycleObservers() // REMOVED - Views manage themselves
    }

    private func setupViewLifecycleObservers() {}
    
    // MARK: - UserDefaults Methods for LocalizedCallerName
    
    /**
     * Save localizedCallerName to UserDefaults (similar to shared_preferences)
     */
    private func saveLocalizedCallerName(_ name: String) {
        UserDefaults.standard.set(name, forKey: "LocalizedCallerName")
        UserDefaults.standard.synchronize()
        NSLog("Saved localizedCallerName to UserDefaults: \(name)")
    }
    
    /**
     * Load localizedCallerName from UserDefaults
     */
    private func loadLocalizedCallerName() -> String {
        let savedName = UserDefaults.standard.string(forKey: "LocalizedCallerName") ?? ""
        NSLog("Loaded localizedCallerName from UserDefaults: \(savedName)")
        return savedName
    }

    @objc private func handleLocalViewCreated() {
        // REMOVED - Plugin doesn't need to track view creation
    }

    @objc private func handleRemoteViewCreated() {
        // REMOVED - Plugin doesn't need to track view creation
    }

    @objc private func handleLocalViewDestroyed() {
        // REMOVED - Plugin doesn't need to track view destruction
    }

    @objc private func handleRemoteViewDestroyed() {
        // REMOVED - Plugin doesn't need to track view destruction
    }

    // 🔥 NEW: Handle view ready notifications
    @objc private func handleLocalViewReady() {
        // REMOVED - Plugin doesn't need to handle view ready events
    }

    @objc private func handleRemoteViewReady() {
        // REMOVED - Plugin doesn't need to handle view ready events
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSLog("MptCallkitPlugin - deinit")
    }

    private func setupNotificationHandling() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Request permission for notifications
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notifications permission: \(error)")
            } else {
                print("Notifications permission granted: \(granted)")
            }
        }

        // Register for remote notifications
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    // --

    // MARK: - APNs message PUSH

    @available(iOS 10.0, *)
    public override func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        // This method will handle foreground notifications
        print("Received notification in foreground: \(notification.request.content.userInfo)")
        completionHandler([.alert, .sound])
    }

    @available(iOS 10.0, *)
    public override func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // This method will handle background notifications or tapped notifications
        print("Received notification response: \(response.notification.request.content.userInfo)")
        completionHandler()
    }

    // 8.0 < iOS < 10.0
    private func application(
        application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject: AnyObject],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if application.applicationState == UIApplication.State.active {
            print("Foreground Notification:\(userInfo)")
        } else {
            print("Background Notification:\(userInfo)")
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        completionHandler(.newData)
    }

    // MARK: - VoIP PUSH

    func addPushSupportWithPortPBX(_ enablePush: Bool) {
        print("addPushSupportWithPortPBX:{\(enablePush)}")
        print("addPushSupportWithPortPBX:{\(_VoIPPushToken)}")
        print("addPushSupportWithPortPBX:{\(_APNsPushToken)}")
        if _VoIPPushToken == nil || _APNsPushToken == nil {
            return
        }
        // This VoIP Push is only work with PortPBX(https://www.portsip.com/portsip-pbx/)
        // if you want work with other PBX, please contact your PBX Provider

        let bundleIdentifier: String = Bundle.main.bundleIdentifier!
        portSIPSDK.clearAddedSipMessageHeaders()
        let token = NSString(format: "%@|%@", _VoIPPushToken, _APNsPushToken)
        if enablePush {
            let pushMessage: String =
                NSString(
                    format:
                        "device-os=ios;device-uid=%@;allow-call-push=true;allow-message-push=true;app-id=%@",
                    token, bundleIdentifier) as String

            print("Enable pushMessage:{\(pushMessage)}")

            portSIPSDK.addSipMessageHeader(
                -1, methodName: "REGISTER", msgType: 1, headerName: "X-Push",
                headerValue: pushMessage)
        } else {
            let pushMessage: String =
                NSString(
                    format:
                        "device-os=ios;device-uid=%@;allow-call-push=false;allow-message-push=false;app-id=%@",
                    token, bundleIdentifier) as String

            print("Disable pushMessage:{\(pushMessage)}")

            portSIPSDK.addSipMessageHeader(
                -1, methodName: "REGISTER", msgType: 1, headerName: "X-Push",
                headerValue: pushMessage)
        }
    }

    func updatePushStatusToSipServer() {
        // This VoIP Push is only work with
        // PortPBX(https://www.portsip.com/portsip-pbx/)
        // if you want work with other PBX, please contact your PBX Provider

        addPushSupportWithPortPBX(_enablePushNotification!)
        loginViewController.refreshRegister()
    }

    func processPushMessageFromPortPBX(
        _ dictionaryPayload: [AnyHashable: Any], completion: @escaping () -> Void
    ) {
        /* dictionaryPayload JSON Format
         Payload: {
         "message_id" = "96854b5d-9d0b-4644-af6d-8d97798d9c5b";
         "msg_content" = "Received a call.";
         "msg_title" = "Received a new call";
         "msg_type" = "call";// im message is "im"
         "X-Push-Id" = "pvqxCpo-j485AYo9J1cP5A..";
         "send_from" = "102";
         "send_to" = "sip:105@portsip.com";
         }
         */

        // 🔥 CRITICAL: Set timeout protection to ensure completion is called within 10 seconds
        var hasCompleted = false
        let timeout = DispatchWorkItem {
            if !hasCompleted {
                hasCompleted = true
                print(
                    "⚠️ VoIP push processing timeout - calling completion to avoid app termination")
                completion()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: timeout)

        // Wrap completion to ensure it's only called once
        let safeCompletion = {
            timeout.cancel()
            if !hasCompleted {
                hasCompleted = true
                completion()
            }
        }

        do {
            let parsedObject = dictionaryPayload
            var isVideoCall = false
            let msgType = parsedObject["msg_type"] as? String
            if (msgType?.count ?? 0) > 0 {
                if msgType == "video" {
                    isVideoCall = true
                } else if msgType == "audio" {
                    isVideoCall = false
                }
            }

            var uuid: UUID?
            let pushId: Any? = dictionaryPayload["X-Push-Id"]

            if let pushIdStr = pushId as? String {
                uuid = UUID(uuidString: pushIdStr)
                self.currentUUID = uuid
            }

            // 🔥 FIX: If UUID parsing fails, generate a new UUID instead of returning
            if uuid == nil {
                print("⚠️ Failed to parse UUID from X-Push-Id, generating new UUID")
                uuid = UUID()
                self.currentUUID = uuid
            }

            let sendFrom = parsedObject["send_from"] as? String ?? "Unknown"
            let sendTo = parsedObject["send_to"] as? String ?? "Unknown"

            print(
                "📞 Processing VoIP push - From: \(sendFrom), IsVideo: \(isVideoCall), UUID: \(uuid!)"
            )

            if !_callManager.enableCallKit {
                // If not enable Call Kit, show the local Notification
                print("📱 CallKit disabled - showing local notification")
                postNotification(
                    title: "SIPSample",
                    body: "You receive a new call From:\(sendFrom) To:\(sendTo)",
                    sound: UNNotificationSound.default, trigger: nil)
                safeCompletion()
            } else {
                // 🔥 FIX: Create session FIRST, then report to CallKit
                print("📱 CallKit enabled - creating session then reporting to CallKit")

                // Create session first (required for CallKit reporting)
                _callManager.incomingCall(
                    sessionid: -1, existsVideo: isVideoCall, remoteParty: self.currentRemoteName,
                    callUUID: uuid!, completionHandle: {})

                if #available(iOS 10.0, *) {
                    // Add timeout protection for CallKit reporting
                    var hasReported = false
                    let callKitTimeout = DispatchWorkItem {
                        if !hasReported {
                            hasReported = true
                            print("⚠️ CallKit reporting timeout - calling completion")
                            safeCompletion()
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: callKitTimeout)
                    
                    _callManager.isHideCallkit = false

                    // Report incoming call to CallKit (session must exist first)
                    _callManager.reportInComingCall(
                        uuid: uuid!, hasVideo: true, from: self.currentRemoteName
                    ) { error in
                        callKitTimeout.cancel()
                        if !hasReported {
                            hasReported = true
                            if let error = error {
                                print("❌ Error reporting incoming call to CallKit: \(error)")
                            } else {
                                print("✅ Successfully reported incoming call to CallKit")
                            }

                            safeCompletion()
                        }
                    }
                } else {
                    // For iOS < 10.0, fallback to non-CallKit
                    print("📱 iOS < 10.0 - using non-CallKit flow")
                    safeCompletion()
                }

                loginViewController.refreshRegister()
                beginBackgroundRegister()
            }
        } catch {
            print("❌ Error processing VoIP push: \(error)")
            safeCompletion()
        }
    }

    public func pushRegistry(
        _: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for _: PKPushType
    ) {
        var deviceTokenString = String()
        let bytes = [UInt8](pushCredentials.token)
        for item in bytes {
            deviceTokenString += String(format: "%02x", item & 0x0000_00FF)
        }

        _VoIPPushToken = NSString(string: deviceTokenString)

        print("didUpdatePushCredentials token=", deviceTokenString)

        updatePushStatusToSipServer()
    }

    public func pushRegistry(
        _: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for _: PKPushType
    ) {
        print("didReceiveIncomingPushWith:payload=", payload.dictionaryPayload)
        if sipRegistered,
            UIApplication.shared.applicationState == .active || _callManager.getConnectCallNum() > 0
        {  // ignore push message when app is active
            print(
                "didReceiveIncomingPushWith:ignore push message when ApplicationStateActive or have active call. "
            )

            return
        }

        processPushMessageFromPortPBX(payload.dictionaryPayload, completion: {})
    }

    public func pushRegistry(
        _: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for _: PKPushType,
        completion: @escaping () -> Void
    ) {
        print("🔔 didReceiveIncomingPushWith:payload=", payload.dictionaryPayload)
        print(
            "🔔 App state: \(UIApplication.shared.applicationState.rawValue), SIP registered: \(sipRegistered), Active calls: \(_callManager.getConnectCallNum())"
        )

        if sipRegistered,
            UIApplication.shared.applicationState == .active || _callManager.getConnectCallNum() > 0
        {  // ignore push message when app is active
            print("🔔 Ignoring push - app is active or has active calls")

            // 🔥 FIX: Always call completion handler to avoid iOS killing the app
            completion()
            return
        }

        print("🔔 Processing VoIP push notification")
        processPushMessageFromPortPBX(payload.dictionaryPayload, completion: completion)
    }

    func beginBackgroundRegister() {
        _backtaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.endBackgroundRegister()

        })

        if #available(iOS 10.0, *) {
            Timer.scheduledTimer(
                withTimeInterval: 5.0, repeats: false,
                block: { _ in

                    self.endBackgroundRegister()
                })
        } else {
            // Fallback on earlier versions

            //          Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(endBackgroundRegister), userInfo: nil, repeats: true)
        }
    }

    func endBackgroundRegister() {
        if _backtaskIdentifier != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(_backtaskIdentifier)
            _backtaskIdentifier = UIBackgroundTaskIdentifier.invalid
            NSLog("endBackgroundRegister")
        }
    }

    func postNotification(
        title: String, body: String, sound: UNNotificationSound?, trigger: UNNotificationTrigger?
    ) {
        // Configure the notification's payload.
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound

        let request = UNNotificationRequest(
            identifier: "FiveSecond", content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.add(request) { (error: Error?) in
            if error != nil {
                // Handle any errors
            }
        }
    }

    public override func application(
        _: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("application(_: UIApplication")
        var deviceTokenString = String()
        let bytes = [UInt8](deviceToken)
        for item in bytes {
            deviceTokenString += String(format: "%02x", item & 0x0000_00FF)
        }

        _APNsPushToken = NSString(string: deviceTokenString)
        updatePushStatusToSipServer()
    }

    private func registerAppNotificationSettings(
        launchOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) {}

    @objc func reachabilityChanged(_: Notification) {
        let netStatus = internetReach.currentReachabilityStatus()

        switch netStatus {
        case NotReachable:
            NSLog("reachabilityChanged:kNotReachable")
        case ReachableViaWWAN:
            loginViewController.refreshRegister()
            NSLog("reachabilityChanged:kReachableViaWWAN")
        case ReachableViaWiFi:
            loginViewController.refreshRegister()
            NSLog("reachabilityChanged:kReachableViaWiFi")
        default:
            break
        }

    }

    func startNotifierNetwork() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(reachabilityChanged),
            name: NSNotification.Name.reachabilityChanged, object: nil)

        internetReach.startNotifier()
    }

    func stopNotifierNetwork() {
        internetReach.stopNotifier()

        NotificationCenter.default.removeObserver(
            self, name: NSNotification.Name.reachabilityChanged, object: nil)
    }

    // MARK: - UIApplicationDelegate

    public func didEnterBackground() {
        if _callManager.getConnectCallNum() > 0 {
            return
        }
        NSLog("applicationDidEnterBackground")
        if _enableForceBackground! {
            // Disable to save battery, or when you don't need incoming calls while APP is in background.
            portSIPSDK.startKeepAwake()
        } else {
            loginViewController.unRegister()

            beginBackgroundRegister()
        }
        NSLog("applicationDidEnterBackground End")
    }

    public func willEnterForeground() {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        if _enableForceBackground! {
            portSIPSDK.stopKeepAwake()
        } else {
            loginViewController.refreshRegister()
        }
    }

    public override func applicationWillTerminate(_: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        print("applicationWillTerminate")
        if _enablePushNotification! {
            portSIPSDK.unRegisterServer(90)

            Thread.sleep(forTimeInterval: 1.0)

            print("applicationWillTerminate")
        }
    }

    // PortSIPEventDelegate

    // Call Event
    public func onInviteIncoming(
        _ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!,
        callee: String!, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool,
        existsVideo: Bool, sipMessage: String!
    ) {
        NSLog(
            "onInviteIncoming - sessionId: \(sessionId) - callerDisplayName: \(String(describing: callerDisplayName)) - caller: \(String(describing: caller)) - calleeDisplayName: \(String(describing: calleeDisplayName)) - callee: \(String(describing: callee)) - audioCodecs: \(String(describing: audioCodecs)) - videoCodecs: \(String(describing: videoCodecs)) - existsAudio: \(existsAudio) - existsVideo: \(existsVideo) - sipMessage: \(String(describing: sipMessage))"
        )
        self.activeSessionid = sessionId
        let num = _callManager.getConnectCallNum()
        let index = findIdleLine()
        if num >= MAX_LINES || index < 0 {
            portSIPSDK.rejectCall(sessionId, code: 486)
            return
        }
        let remoteParty = caller
        let remoteDisplayName = callerDisplayName

        if _enablePushNotification! {

            let pushId = portSIPSDK.getSipMessageHeaderValue(sipMessage, headerName: "X-Push-Id")
            if pushId != nil {
                self.currentUUID = UUID(uuidString: pushId!)
            }
        }
        if self.currentUUID == nil {
            self.currentUUID = UUID()
        }
        lineSessions[index] = sessionId

        _callManager.incomingCall(
            sessionid: sessionId, existsVideo: existsVideo, remoteParty: self.currentRemoteName,
            callUUID: self.currentUUID!, completionHandle: {})

        // Send PortSIPStateManager notification immediately for incoming call
        let callState = PortSIPCallState(
            sessionId: Int64(sessionId),
            hasVideo: existsVideo,
            hasAudio: true,
            isIncoming: true,
            remoteParty: remoteParty,
            remoteDisplayName: remoteDisplayName,
            state: .incoming
        )
        PortSIPStateManager.shared.updateCallState(callState)

        // 🔥 SIMPLE: Always send video state for local video display regardless of call type
        NSLog("onInviteIncoming - Always sending video state for local video display")
        let videoState = PortSIPVideoState(
            sessionId: Int64(sessionId),
            isVideoEnabled: true,  // Always enabled for local video
            isCameraOn: true,
            useFrontCamera: mUseFrontCamera
        )
        PortSIPStateManager.shared.updateVideoState(videoState)

        self.currentSessionid = portSIPSDK.getSipMessageHeaderValue(
            sipMessage, headerName: "X-Session-Id")

        methodChannel?.invokeMethod("curr_sessionId", arguments: self.currentSessionid)
        methodChannel?.invokeMethod("isRemoteVideoReceived", arguments: false)
        self.isRemoteVideoReceived = false

        // Auto answer call
        if portSIPSDK.getSipMessageHeaderValue(sipMessage, headerName: "Answer-Mode")
            == "Auto;require"
        {
            print("onInviteIncoming - Outgoing call API")
            if _callManager.enableCallKit {
                if #available(iOS 10.0, *) {
                    _callManager.isHideCallkit = false
                    _callManager.reportOutgoingCall(
                        number: self.currentRemoteName, uuid: self.currentUUID!, video: existsVideo)
                }
            } else {
                //               _callManager.delegate?.onIncomingCallWithoutCallKit(sessionId, existsVideo: existsVideo, remoteParty: remoteParty!, remoteDisplayName: remoteDisplayName!)
            }
            self.xSessionId = portSIPSDK.getSipMessageHeaderValue(
                sipMessage, headerName: "X-Session-Id")
            methodChannel?.invokeMethod("callType", arguments: "OUTGOING_CALL")
            answerCall(isAutoAnswer: true)
        } else {
            print("onInviteIncoming - Incoming call API")
            if _callManager.enableCallKit {
//                if #available(iOS 10.0, *) {
//                    _callManager.reportInComingCall(
//                        uuid: self.currentUUID!, hasVideo: true, from: self.currentRemoteName
//                    )
//                }
                
                if UIApplication.shared.applicationState != .active {
                    _callManager.isHideCallkit = false
                                    if #available(iOS 10.0, *) {
                                        _callManager.reportInComingCall(
                                            uuid: self.currentUUID!, hasVideo: true, from: self.currentRemoteName
                                        )
                                    }
                } else {
                    mSoundService.playRingTone()
                    _callManager.isHideCallkit = true
                }
            } else {
                _callManager.delegate?.onIncomingCallWithoutCallKit(
                    sessionId, existsVideo: existsVideo, remoteParty: remoteParty!,
                    remoteDisplayName: remoteDisplayName!)
            }
            self.xSessionId = ""
            methodChannel?.invokeMethod("callType", arguments: "INCOMING_CALL")
        }

        // Setting speakers for sound output (The system default behavior)
        setLoudspeakerStatus(true)
    }

    public func onInviteTrying(_ sessionId: Int) {
        NSLog("onInviteTrying...")
        sendCallStateToFlutter(.TRYING)
        let index = findSession(sessionid: sessionId)
        // Gửi trạng thái về Flutter
        if index == -1 {
            return
        }
    }

    public func onInviteSessionProgress(
        _ sessionId: Int, audioCodecs: String!, videoCodecs: String!, existsEarlyMedia: Bool,
        existsAudio: Bool, existsVideo: Bool, sipMessage: String!
    ) {
        NSLog("onInviteSessionProgress...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }

        if existsEarlyMedia {
            // Checking does this call has video
            if existsVideo {}

            if existsAudio {
            }
        }

        let result = _callManager.findCallBySessionID(sessionId)

        result!.session.existEarlyMedia = existsEarlyMedia

    }

    public func onInviteRinging(
        _ sessionId: Int, statusText: String!, statusCode: Int32, sipMessage: String!
    ) {
        NSLog("onInviteRinging...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }
        let result = _callManager.findCallBySessionID(sessionId)
        if !result!.session.existEarlyMedia {
            mSoundService.playRingBackTone()
        }
    }

    public func onInviteAnswered(
        _ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!,
        callee: String!, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool,
        existsVideo: Bool, sipMessage: String!
    ) {
        NSLog("🔍 onInviteAnswered... sessionId: \(sessionId), existsVideo: \(existsVideo)")
        guard let result = _callManager.findCallBySessionID(sessionId) else {
            NSLog("❌ onInviteAnswered - Not exist this SessionId = \(sessionId)")
            return
        }

        // 🔍 LOG: Session state BEFORE setting
        NSLog("🔍 onInviteAnswered - BEFORE:")
        NSLog("🔍   sessionId: \(sessionId)")
        NSLog("🔍   result.session.sessionId: \(result.session.sessionId)")
        NSLog("🔍   result.session.videoState: \(result.session.videoState)")
        NSLog("🔍   result.session.videoMuted: \(result.session.videoMuted)")
        NSLog("🔍   result.session.sessionState: \(result.session.sessionState)")

        result.session.sessionState = true
        result.session.videoState = existsVideo
        result.session.videoMuted = !existsVideo

        // 🔍 LOG: Session state AFTER setting
        NSLog("🔍 onInviteAnswered - AFTER:")
        NSLog("🔍   result.session.videoState: \(result.session.videoState)")
        NSLog("🔍   result.session.videoMuted: \(result.session.videoMuted)")
        NSLog("🔍   result.session.sessionState: \(result.session.sessionState)")

        // 🔥 ANDROID PATTERN: Send single unified state notification
        if let result = _callManager.findCallBySessionID(sessionId) {
            // Set camera if it's a video call
            if existsVideo {
                NSLog("Setting camera for video call")
                setCamera(useFrontCamera: mUseFrontCamera)
            }

            // Send unified video state notification with accurate data
            let videoState = PortSIPVideoState(
                sessionId: Int64(sessionId),
                isVideoEnabled: result.session.videoState,
                isCameraOn: result.session.videoState && !result.session.videoMuted,
                useFrontCamera: mUseFrontCamera
            )
            PortSIPStateManager.shared.updateVideoState(videoState)

            NSLog(
                "⭐️ onInviteAnswered - Sent unified video state: enabled=\(result.session.videoState), camera=\(!result.session.videoMuted)"
            )

            // 🔥 Send call state notification with correct sessionId and video info
            let callState = PortSIPCallState(
                sessionId: Int64(sessionId),
                hasVideo: result.session.videoState,
                hasAudio: true,
                isIncoming: !result.session.recvCallState,
                remoteParty: caller,
                remoteDisplayName: callerDisplayName,
                state: .answered
            )
            PortSIPStateManager.shared.updateCallState(callState)
            NSLog(
                "⭐️ onInviteAnswered - Sent call state: ANSWERED with hasVideo=\(result.session.videoState)"
            )
        }

        if result.session.isReferCall {
            result.session.isReferCall = false
            result.session.originCallSessionId = -1
        }

        if isConference == true {
            _callManager.joinToConference(sessionid: sessionId)
        }
        mSoundService.stopRingBackTone()
        mSoundService.stopRingTone()

        // Legacy Flutter state (keep for compatibility)
        sendCallStateToFlutter(.ANSWERED)
    }

    public func onInviteFailure(
        _ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!,
        callee: String!, reason: String!, code: Int32, sipMessage: String!
    ) {
        NSLog(
            "onInviteFailure - sessionId: \(sessionId) - callerDisplayName: \(String(describing: callerDisplayName)) - caller: \(String(describing: caller)) - calleeDisplayName: \(String(describing: calleeDisplayName)) - callee: \(String(describing: callee)) - reason: \(String(describing: reason)) - code: \(code) - sipMessage: \(String(describing: sipMessage))"
        )

        if sessionId == INVALID_SESSION_ID {
            NSLog("This is an invalidate session from \(caller!).reason=\(reason!)")
            return
        }
        guard let result = _callManager.findCallBySessionID(sessionId) else {
            return
        }

        let tempreaon = NSString(utf8String: reason)

        print("Failed to call on line \(findSession(sessionid: sessionId)),\(tempreaon!),\(code)")

        if result.session.isReferCall {
            let originSession = _callManager.findCallByOrignalSessionID(
                sessionID: result.session.originCallSessionId)

            if originSession != nil {
                print(
                    "Call failure on line \(findSession(sessionid: sessionId)) , \(String(describing: tempreaon)) , \(code)"
                )

                portSIPSDK.unHold(originSession!.session.sessionId)
                originSession!.session.holdState = false

                _activeLine = findSession(sessionid: sessionId)
            }
        }

        if activeSessionid == sessionId {
            activeSessionid = CLong(INVALID_SESSION_ID)
        }

        _callManager.removeCall(call: result.session)

        mSoundService.stopRingTone()
        mSoundService.stopRingBackTone()
        // setLoudspeakerStatus(true)
        // REMOVED: No direct view calls in Android pattern
        // videoViewController.onClearState()
        //    loginViewController.offLine()

        // REMOVED: Views handle themselves via state notifications
        // remoteViewController.onClearState()
        // localViewController.onClearState()
        //    loginViewController.unRegister()

        // Gửi trạng thái về Flutter
        sendCallStateToFlutter(.FAILED)
        methodChannel?.invokeMethod("callType", arguments: "ENDED")
        methodChannel?.invokeMethod("isRemoteVideoReceived", arguments: false)
        self.isRemoteVideoReceived = false
    }

    public func onInviteUpdated(
        _ sessionId: Int, audioCodecs: String!, videoCodecs: String!, screenCodecs: String!,
        existsAudio: Bool, existsVideo: Bool, existsScreen: Bool, sipMessage: String!
    ) {
        guard let result = _callManager.findCallBySessionID(sessionId) else {
            print("onInviteUpdated... not found sessionId: \(sessionId)")
            return
        }

        // 🔍 LOG: Session state BEFORE processing
        NSLog(
            "onInviteUpdated - sessionId: \(sessionId), audioCodecs: \(audioCodecs ?? ""), videoCodecs: \(videoCodecs ?? ""), screenCodecs: \(screenCodecs ?? ""), existsAudio: \(existsAudio), existsVideo: \(existsVideo), existsScreen: \(existsScreen), sipMessage: \(sipMessage ?? "")"
        )

        if existsVideo {
            let strCallBack = portSIPSDK.enableVideoStreamCallback(
                sessionId, callbackMode: DIRECTION_RECV)
            print("enableVideoStreamCallback result: \(strCallBack)")
            
            if (_callManager.isHideCallkit){} else {
                _callManager.reportUpdateCall(
                    uuid: self.currentUUID!, hasVideo: true, from: self.currentRemoteName)
            }


        }

        // 🔍 LOG: Check condition
        let condition1 = result.session.videoState
        let condition2 = !existsVideo
        let condition3 = (videoCodecs?.isEmpty ?? true)
        NSLog(
            "onInviteUpdated - CHECK CONDITIONS: session.videoState - \(condition1), !existsVideo - \(condition2), videoCodecs.isEmpty - \(condition3)"
        )

        if result.session.videoState && !existsVideo && (videoCodecs?.isEmpty ?? true) {
            NSLog("onInviteUpdated - ENTERING RE-SEND LOGIC!")
            let sendVideoRes = portSIPSDK.sendVideo(result.session.sessionId, sendState: true)
            NSLog("onInviteUpdated - re-sendVideo: \(sendVideoRes)")

            let updateRes = portSIPSDK.updateCall(
                result.session.sessionId, enableAudio: true, enableVideo: true)
            NSLog("onInviteUpdated - re-updateCall: \(updateRes)")
        } else {
            NSLog("onInviteUpdated - CONDITIONS NOT MET, skipping re-send logic")
        }

        // 🔍 LOG: Session state BEFORE override
        NSLog("onInviteUpdated - BEFORE OVERRIDE: ")
        NSLog("result.session.videoState: \(result.session.videoState)")
        NSLog("result.session.videoMuted: \(result.session.videoMuted)")

        // Cập nhật trạng thái video
        result.session.videoState = existsVideo
        result.session.videoMuted = !existsVideo
        result.session.screenShare = existsScreen

        // 🔍 LOG: Session state AFTER override
        NSLog(
            "🔍 onInviteUpdated - AFTER OVERRIDE - result.session.videoState: \(result.session.videoState) - result.session.videoMuted: \(result.session.videoMuted)"
        )

        // 🔥 ANDROID PATTERN: Send state notification instead of direct call
        let videoState = PortSIPVideoState(
            sessionId: Int64(sessionId),
            isVideoEnabled: existsVideo,
            isCameraOn: existsVideo && !result.session.videoMuted,
            useFrontCamera: mUseFrontCamera
        )
        PortSIPStateManager.shared.updateVideoState(videoState)

        NSLog("onInviteUpdated - COMPLETE: The call has been updated on line \(result.index)")
    }

    public func onInviteConnected(_ sessionId: Int) {
        NSLog("onInviteConnected - sessionId: \(sessionId)")
        guard let result = _callManager.findCallBySessionID(sessionId) else {
            return
        }

        print("The call is connected on line \(findSession(sessionid: sessionId))")
        // REMOVED: mUseFrontCamera = true  // ❌ Don't force reset camera setting
        
        self.activeSessionid = sessionId

        // 🔥 ANDROID PATTERN: Send state notification instead of direct call
        if result.session.videoState {
            NSLog("⭐️ Call is connected with video - sending state notification")
            let videoState = PortSIPVideoState(
                sessionId: Int64(sessionId),
                isVideoEnabled: true,
                isCameraOn: !result.session.videoMuted,
                useFrontCamera: mUseFrontCamera
            )
            PortSIPStateManager.shared.updateVideoState(videoState)
        }

        // Gửi trạng thái về Flutter
        sendCallStateToFlutter(.CONNECTED)
    }

    public func onInviteBeginingForward(_ forwardTo: String) {
        NSLog("onInviteBeginingForward...")
        print("Call has been forward to:\(forwardTo)")
    }

    public func onInviteClosed(_ sessionId: Int, sipMessage: String) {
        NSLog("onInviteClosed - sessionId: \(sessionId), sipMessage: \(sipMessage)")
        let result = _callManager.findCallBySessionID(sessionId)
        if result != nil {
            _callManager.endCall(sessionid: sessionId)
        }
        _ = mSoundService.stopRingTone()
        _ = mSoundService.stopRingBackTone()

        if activeSessionid == sessionId {
            activeSessionid = CLong(INVALID_SESSION_ID)
        }

        //       // Gửi trạng thái về Flutter
        //       sendCallStateToFlutter(.CLOSED)
        methodChannel?.invokeMethod("callType", arguments: "ENDED")
        methodChannel?.invokeMethod("isRemoteVideoReceived", arguments: false)
        self.isRemoteVideoReceived = false
    }

    public func onDialogStateUpdated(
        _ BLFMonitoredUri: String!, blfDialogState BLFDialogState: String!,
        blfDialogId BLFDialogId: String!, blfDialogDirection BLFDialogDirection: String!
    ) {

        NSLog(
            "The user \(BLFMonitoredUri!) dialog state is updated:\(BLFDialogState!), dialog id: \(BLFDialogId!), direction: \(BLFDialogDirection!) "
        )
    }

    public func onRemoteHold(_ sessionId: Int) {
        NSLog("onRemoteHold...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }
    }

    public func onRemoteUnHold(
        _ sessionId: Int, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool,
        existsVideo: Bool
    ) {
        NSLog("onRemoteUnHold...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }
    }

    // Transfer Event
    public func onReceivedRefer(
        _ sessionId: Int, referId: Int, to: String!, from: String!, referSipMessage: String!
    ) {

        NSLog("onReceivedRefer...")
        guard _callManager.findCallBySessionID(sessionId) != nil else {
            portSIPSDK.rejectRefer(referId)
            return
        }

        let index = findIdleLine()
        if index < 0 {
            // Not found the idle line, reject refer.
            portSIPSDK.rejectRefer(referId)
            return
        }

        // auto accept refer
        let referSessionId = portSIPSDK.acceptRefer(referId, referSignaling: referSipMessage)
        if referSessionId <= 0 {
        } else {
            _callManager.endCall(sessionid: sessionId)

            let session = Session()
            session.sessionId = referSessionId
            session.videoState = true
            session.recvCallState = true

            let newIndex = _callManager.addCall(call: session)
            lineSessions[index] = referSessionId

            session.sessionState = true
            session.isReferCall = true
            session.originCallSessionId = sessionId

        }
    }

    public func onReferAccepted(_ sessionId: Int) {
        NSLog("onReferAccepted...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }

    }

    public func onReferRejected(_ sessionId: Int, reason: String!, code: Int32) {
        NSLog("onReferRejected...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }

    }

    public func onTransferTrying(_ sessionId: Int) {
        NSLog("onTransferTrying...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }
    }

    public func onTransferRinging(_ sessionId: Int) {
        NSLog("onTransferRinging...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }
    }

    public func onACTVTransferSuccess(_ sessionId: Int) {
        NSLog("onACTVTransferSuccess...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }

        // Transfer has success, hangup call.
        portSIPSDK.hangUp(sessionId)
        // Gửi trạng thái về Flutter
        sendCallStateToFlutter(.CLOSED)
    }

    public func onACTVTransferFailure(_ sessionId: Int, reason: String!, code: Int32) {
        NSLog("onACTVTransferFailure...")
        if sessionId == -1 {
            return
        }

    }

    // Signaling Event

    public func onReceivedSignaling(_ sessionId: Int, message: String!) {
        NSLog("onReceivedSignaling...")
        // This event will be fired when the SDK received a SIP message
        // you can use signaling to access the SIP message.
    }

    public func onSendingSignaling(_ sessionId: Int, message: String!) {
        NSLog("onSendingSignaling...")
        // This event will be fired when the SDK sent a SIP message
        // you can use signaling to access the SIP message.
    }

    public func onWaitingVoiceMessage(
        _ messageAccount: String!, urgentNewMessageCount: Int32, urgentOldMessageCount: Int32,
        newMessageCount: Int32, oldMessageCount: Int32
    ) {
        NSLog("onWaitingVoiceMessage...")

    }

    public func onWaitingFaxMessage(
        _ messageAccount: String!, urgentNewMessageCount: Int32, urgentOldMessageCount: Int32,
        newMessageCount: Int32, oldMessageCount: Int32
    ) {
        NSLog("onWaitingFaxMessage...")
    }

    public func onRecvDtmfTone(_ sessionId: Int, tone: Int32) {
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }
    }

    public func onRecvOptions(_ optionsMessage: String!) {

        NSLog("Received an OPTIONS message:\(optionsMessage!)")
    }

    public func onRecvInfo(_ infoMessage: String!) {

        NSLog("Received an INFO message:\(infoMessage!)")
    }

    public func onRecvNotifyOfSubscription(
        _ subscribeId: Int, notifyMessage: String!, messageData: UnsafeMutablePointer<UInt8>!,
        messageDataLength: Int32
    ) {
        NSLog("Received an Notify message")
    }

    // Instant Message/Presence Event

    public func onPresenceRecvSubscribe(
        _ subscribeId: Int, fromDisplayName: String!, from: String!, subject: String!
    ) {
        NSLog("onPresenceRecvSubscribe...")
    }
    public func onPresenceOnline(_ fromDisplayName: String!, from: String!, stateText: String!) {
        NSLog("onPresenceOnline...")
    }

    public func onPresenceOffline(_ fromDisplayName: String!, from: String!) {
        NSLog("onPresenceOffline...")
    }

    public func onRecvMessage(
        _ sessionId: Int, mimeType: String!, subMimeType: String!,
        messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32
    ) {
        NSLog("onRecvMessage...")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }

        if mimeType == "text", subMimeType == "plain" {
            let recvMessage =
                String(
                    data: Data(bytes: messageData, count: Int(messageDataLength)), encoding: .utf8)
                ?? ""
            NSLog("onRecvMessage... Received message: \(recvMessage)")

            // Gửi tin nhắn về Flutter
            methodChannel?.invokeMethod("recvCallMessage", arguments: recvMessage)
        } else if mimeType == "application", subMimeType == "vnd.3gpp.sms" {
            // The messageData is binary data
            let recvMessage =
                String(
                    data: Data(bytes: messageData, count: Int(messageDataLength)), encoding: .utf8)
                ?? ""
            NSLog("onRecvMessage... Received 3GPP SMS: \(recvMessage)")
            methodChannel?.invokeMethod("recvCallMessage", arguments: recvMessage)
        } else if mimeType == "application", subMimeType == "vnd.3gpp2.sms" {
            // The messageData is binary data
            let recvMessage =
                String(
                    data: Data(bytes: messageData, count: Int(messageDataLength)), encoding: .utf8)
                ?? ""
            NSLog("onRecvMessage... Received 3GPP2 SMS: \(recvMessage)")
            methodChannel?.invokeMethod("recvCallMessage", arguments: recvMessage)
        }
    }

    public func onRTPPacketCallback(
        _ sessionId: Int, mediaType: Int32, direction: DIRECTION_MODE,
        rtpPacket RTPPacket: UnsafeMutablePointer<UInt8>!, packetSize: Int32
    ) {
        NSLog("onRTPPacketCallback...")
    }

    public func onRecvOutOfDialogMessage(
        _ fromDisplayName: String!, from: String!, toDisplayName: String!, to: String!,
        mimeType: String!, subMimeType: String!, messageData: UnsafeMutablePointer<UInt8>!,
        messageDataLength: Int32, sipMessage: String!
    ) {
        NSLog("onRecvOutOfDialogMessage...")

        if mimeType == "text", subMimeType == "plain" {
            let strMessageData =
                String(
                    data: Data(bytes: messageData, count: Int(messageDataLength)), encoding: .utf8)
                ?? ""
            NSLog("Received out of dialog message: \(strMessageData)")
        } else if mimeType == "application", subMimeType == "vnd.3gpp.sms" {
            // The messageData is binary data
            NSLog("Received 3GPP SMS binary data")
        } else if mimeType == "application", subMimeType == "vnd.3gpp2.sms" {
            // The messageData is binary data
            NSLog("Received 3GPP2 SMS binary data")
        }
    }

    public func onSendOutOfDialogMessageFailure(
        _ messageId: Int, fromDisplayName: String!, from: String!, toDisplayName: String!,
        to: String!, reason: String!, code: Int32, sipMessage: String!
    ) {
        NSLog(
            "onSendOutOfDialogMessageFailure messageId: \(messageId), reason: \(String(describing: reason)), code: \(code)"
        )
    }

    public func onSendMessageFailure(
        _ sessionId: Int, messageId: Int, reason: String!, code: Int32, sipMessage: String!
    ) {
        NSLog("onSendMessageFailure...")
    }

    public func onSendMessageSuccess(_ sessionId: Int, messageId: Int, sipMessage: String!) {
        NSLog("onSendMessageSuccess...")
    }

    public func onPlayFileFinished(_ sessionId: Int, fileName: String!) {
        NSLog("PlayFileFinished fileName \(fileName!)")
    }
    public func onStatistics(_ sessionId: Int, stat: String!) {
        NSLog("onStatistics stat: \(stat!)")
    }

    public func onSubscriptionFailure(_ subscribeId: Int, statusCode: Int32) {
        NSLog("SubscriptionFailure subscribeId \(subscribeId) statusCode: \(statusCode)")
    }

    public func onSubscriptionTerminated(_ subscribeId: Int) {
        NSLog("SubscriptionFailure subscribeId \(subscribeId)")
    }

    public func onAudioRawCallback(
        _: Int, audioCallbackMode _: Int32, data _: UnsafeMutablePointer<UInt8>!,
        dataLength _: Int32, samplingFreqHz _: Int32
    ) {
        /* !!! IMPORTANT !!!
        
         Don't call any PortSIP SDK API functions in here directly. If you want to call the PortSIP API functions or
         other code which will spend long time, you should post a message to main thread(main window) or other thread,
         let the thread to call SDK API functions or other code.
         */
    }

    public func onVideoRawCallback(
        _: Int, videoCallbackMode _: Int32, width _: Int32, height _: Int32,
        data: UnsafeMutablePointer<UInt8>!, dataLength: Int32
    ) -> Int32 {
        /* !!! IMPORTANT !!!
        
         Don't call any PortSIP SDK API functions in here directly. If you want to call the PortSIP API functions or
         other code which will spend long time, you should post a message to main thread(main window) or other thread,
         let the thread to call SDK API functions or other code.
         */
        //       let frameData = Data(bytes: data, count: Int(dataLength))
        //
        //       // Print the first few bytes of the raw video data (hexadecimal representation)
        //       print("Raw video data (first 16 bytes):", frameData.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))

        if self.isRemoteVideoReceived == false {
            // Print some additional information
            print("Total data length: \(dataLength) bytes")

            methodChannel?.invokeMethod("isRemoteVideoReceived", arguments: true)
            self.isRemoteVideoReceived = true
        }

        // Return 0 to indicate no further processing is done here
        return 0
    }

    func pressNumpadButton(_ dtmf: Int32) {
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            _callManager.playDtmf(sessionid: activeSessionid, tone: Int(dtmf))
        }
    }

    func makeCall(_ callee: String, videoCall: Bool) -> (CLong) {
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            return CLong(INVALID_SESSION_ID)
        }

        let sessionId = _callManager.makeCall(
            callee: callee, displayName: displayName, videoCall: videoCall)

        if sessionId >= 0 {
            activeSessionid = sessionId
            print("makeCall------------------ \(String(describing: activeSessionid))")
            return activeSessionid
        } else {
            return sessionId
        }
    }

    func updateCall() {
        let result = portSIPSDK.updateCall(
            activeSessionid, enableAudio: true, enableVideo: isVideoCall)
        print("update Call result: \(result) \n")
    }

    func hangUpCall() {
        NSLog("hangUpCall")
        methodChannel?.invokeMethod("isRemoteVideoReceived", arguments: false)
        self.isRemoteVideoReceived = false
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            _ = mSoundService.stopRingTone()
            _ = mSoundService.stopRingBackTone()
            _callManager.endCall(sessionid: activeSessionid)

        }
    }

    func holdCall() {
        NSLog("holdCall")
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            _callManager.holdCall(sessionid: activeSessionid, onHold: true)
            //           let holdRes = portSIPSDK.hold(activeSessionid)
            //           NSLog("holdCall - valid sessionId - holdCall: \(holdRes)")
        } else {
            NSLog("holdCall - invalid sessionId")
        }

        if isConference == true {
            _callManager.holdAllCall(onHold: true)
            NSLog("holdCall - inConference - holdAllCall")
        }
    }

    func unholdCall() {
        NSLog("unholdCall")
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            _callManager.holdCall(sessionid: activeSessionid, onHold: false)
            //          let unHoldRes = portSIPSDK.unHold(activeSessionid)
            //           NSLog("unholdCall - valid sessionId - unHoldCall: \(unHoldRes)")
        } else {
            NSLog("unholdCall - invalid sessionId")
        }

        if isConference == true {
            _callManager.holdAllCall(onHold: false)
        }
    }

    func referCall(_ referTo: String) {
        NSLog("referCall")
        let result = _callManager.findCallBySessionID(activeSessionid)
        if result == nil || !result!.session.sessionState {
            return
        }

        let ret = portSIPSDK.refer(activeSessionid, referTo: referTo)
        if ret != 0 {
        }
    }

    func muteMicrophone(_ mute: Bool) {
        NSLog("muteMicrophone")
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            portSIPSDK.muteSession(
                activeSessionid, muteIncomingAudio: false, muteOutgoingAudio: mute,
                muteIncomingVideo: false, muteOutgoingVideo: false)

            let sessionInfo = getCurrentSessionInfo()
            sendCustomMessage(
                callSessionId: sessionInfo.0, userExtension: sessionInfo.1,
                type: "update_media_state", payloadKey: "microphone", payloadValue: !mute)  // !mute vì microphone state là ngược lại với mute state
        }
        sendMicrophoneStateToFlutter(mute)
    }

    func setLoudspeakerStatus(_ enable: Bool) {
        do {
            portSIPSDK.setLoudspeakerStatus(enable)
            methodChannel?.invokeMethod(
                "currentAudioDevice", arguments: enable ? "SPEAKER_PHONE" : "EARPIECE")
            NSLog("Speaker status changed to: \(enable ? "SPEAKER_PHONE" : "EARPIECE")")
        } catch {
            NSLog("Error setting speaker status")
        }
    }

    func didSelectLine(_ activedline: Int) {

        if !sipRegistered || _activeLine == activedline {
            return
        }

        if !isConference {
            _callManager.holdCall(sessionid: activeSessionid, onHold: true)
        }
        _activeLine = activedline

        activeSessionid = lineSessions[_activeLine]

        if !isConference && activeSessionid != CLong(INVALID_SESSION_ID) {
            _callManager.holdCall(sessionid: activeSessionid, onHold: false)
        }
    }

    func switchSessionLine() {

    }

    public func playRingBackTone() {
        mSoundService.playRingBackTone()
    }

    //    #pragma mark - CallManager delegate

    func onIncomingCallWithoutCallKit(
        _ sessionId: CLong, existsVideo: Bool, remoteParty: String, remoteDisplayName: String
    ) {
        NSLog("onIncomingCallWithoutCallKit")
        guard _callManager.findCallBySessionID(sessionId) != nil else {
            return
        }

        // Send PortSIPStateManager notification for incoming call
        let callState = PortSIPCallState(
            sessionId: Int64(sessionId),
            hasVideo: existsVideo,
            hasAudio: true,
            isIncoming: true,
            remoteParty: remoteParty,
            remoteDisplayName: remoteDisplayName,
            state: .incoming
        )
        PortSIPStateManager.shared.updateCallState(callState)

        // 🔥 SIMPLE: Always send video state for local video display regardless of call type
        NSLog("onIncomingCallWithoutCallKit - Always sending video state for local video display")
        let videoState = PortSIPVideoState(
            sessionId: Int64(sessionId),
            isVideoEnabled: true,  // Always enabled for local video
            isCameraOn: true,
            useFrontCamera: mUseFrontCamera
        )
        PortSIPStateManager.shared.updateVideoState(videoState)

        // Legacy Flutter state (keep for compatibility)
        sendCallStateToFlutter(.INCOMING)

        // Nếu ứng dụng ở trạng thái nền, có thể hiển thị thông báo hệ thống đơn giản
        if UIApplication.shared.applicationState == .background {
            var stringAlert: String
            if existsVideo {
                stringAlert = "Cuộc gọi video từ \(remoteParty)"
            } else {
                stringAlert = "Cuộc gọi từ \(remoteParty)"
            }

            postNotification(
                title: "Cuộc gọi đến", body: stringAlert, sound: UNNotificationSound.default,
                trigger: nil)
        }

        // Phát âm thanh chuông mà không hiển thị UI
        _ = mSoundService.playRingTone()

        // KHÔNG hiển thị bất kỳ alert hoặc UI native nào
        // Gửi thêm thông tin chi tiết về cuộc gọi để Flutter có thể hiển thị UI riêng
        let callInfo: [String: Any] = [
            "sessionId": sessionId,
            "hasVideo": existsVideo,
            "remoteParty": remoteParty,
            "remoteDisplayName": remoteDisplayName,
        ]
        methodChannel?.invokeMethod("incomingCall", arguments: callInfo)
    }

    func onNewOutgoingCall(sessionid: CLong) {
        NSLog("onNewOutgoingCall")
        lineSessions[_activeLine] = sessionid
    }

    func onAnsweredCall(sessionId: CLong) {
        NSLog("onAnsweredCall... sessionId: \(sessionId)")
        let result = _callManager.findCallBySessionID(sessionId)

        if result != nil {
            NSLog("Found call session, videoState: \(result!.session.videoState)")

            // Send call state notification - LocalViewController will always show local video regardless of hasVideo
            let callState = PortSIPCallState(
                sessionId: Int64(sessionId),
                hasVideo: result!.session.videoState,
                hasAudio: true,
                isIncoming: !result!.session.recvCallState,
                remoteParty: nil,
                remoteDisplayName: nil,
                state: .answered
            )
            PortSIPStateManager.shared.updateCallState(callState)

            // 🔥 SIMPLE: Always send video state for local video display
            NSLog("onAnsweredCall() - Always sending video state for local video display")
            let videoState = PortSIPVideoState(
                sessionId: Int64(sessionId),
                isVideoEnabled: true,  // Always enabled for local video
                isCameraOn: true,
                useFrontCamera: mUseFrontCamera
            )
            PortSIPStateManager.shared.updateVideoState(videoState)

            // Set camera for local video
            setCamera(useFrontCamera: mUseFrontCamera)

            let line = findSession(sessionid: sessionId)
            if line >= 0 {
                didSelectLine(line)
            }
            
            let sessionInfo = getCurrentSessionInfo()
            sendCustomMessage(
                callSessionId: sessionInfo.0, userExtension: sessionInfo.1,
                type: "call_state", payloadKey: "answered", payloadValue: true)
        }

        _ = mSoundService.stopRingTone()
        _ = mSoundService.stopRingBackTone()

        if activeSessionid == CLong(INVALID_SESSION_ID) {
            activeSessionid = sessionId
        }
    }

    func onCloseCall(sessionId: CLong) {
        NSLog("onCloseCall")
        freeLine(sessionid: sessionId)

        let result = _callManager.findCallBySessionID(sessionId)
        if result != nil {
            _callManager.removeCall(call: result!.session)
        }
        if sessionId == activeSessionid {
            activeSessionid = CLong(INVALID_SESSION_ID)
        }

        sendCallStateToFlutter(.CLOSED)

        _ = mSoundService.stopRingTone()
        _ = mSoundService.stopRingBackTone()

        // if _callManager.getConnectCallNum() == 0 {
        //     setLoudspeakerStatus(true)
        // }
    }

    func onMuteCall(sessionId: CLong, muted _: Bool) {
        NSLog("onMuteCall")
        let result = _callManager.findCallBySessionID(sessionId)
        if result != nil {
            print("onMuteCall")
        }
    }

    func onHoldCall(sessionId: CLong, onHold: Bool) {
        NSLog("onHoldCall")
        let result = _callManager.findCallBySessionID(sessionId)
        if result != nil, sessionId == activeSessionid {
            if onHold {
                portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
                portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: nil)
            } else {
                if !isConference {
                }
            }
        }
    }

    func createConference(_ conferenceVideoWindow: PortSIPVideoRenderView) {
        print("\(conferenceVideoWindow)")
        if _callManager.createConference(
            conferenceVideoWindow: conferenceVideoWindow, videoWidth: 352, videoHeight: 288,
            displayLocalVideoInConference: true)
        {
            isConference = true
        }
    }

    func setConferenceVideoWindow(conferenceVideoWindow: PortSIPVideoRenderView) {
        portSIPSDK.setConferenceVideoWindow(conferenceVideoWindow)
    }

    func destoryConference(_: UIView) {
        _callManager.destoryConference()
        let result = _callManager.findCallBySessionID(activeSessionid)
        if result != nil && result!.session.holdState {
            _callManager.holdCall(sessionid: result!.session.sessionId, onHold: false)
        }
        isConference = false
    }

    public override func applicationDidBecomeActive(_ application: UIApplication) {
        debugPrint("applicationDidBecomeActive")
    }

    public override func applicationWillResignActive(_ application: UIApplication) {
        debugPrint("applicationWillResignActive")
    }

    func openAppSettings() {
        if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(appSettingsURL) {
                UIApplication.shared.open(appSettingsURL, options: [:], completionHandler: nil)
            }
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("Method called: \(call.method)")
        print("Arguments: \(String(describing: call.arguments))")
        switch call.method {
        case "openAppSetting":
            openAppSettings()
            result(true)
        case "appKilled":
            print("appKilled called!")
            self.loginViewController.offLine()
            _callManager.endCall(sessionid: activeSessionid)
            result(true)
        case "requestPermission":
            AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                if videoGranted {
                    AVAudioSession.sharedInstance().requestRecordPermission { audioGranted in
                        result(audioGranted)
                    }
                } else {
                    result(false)
                }
            }
        case "Login":
            if let args = call.arguments as? [String: Any],
                let username = args["username"] as? String,
                let displayName = args["displayName"] as? String,
                let localizedCallerName = args["localizedCallerName"] as? String,
                let authName = args["authName"] as? String,
                let password = args["password"] as? String,
                let userDomain = args["userDomain"] as? String,
                let sipServer = args["sipServer"] as? String,
                let enableDebugLog = args["enableDebugLog"] as? Bool,
                let sipServerPort = args["sipServerPort"] as? Int32
            {

                // Lưu username hiện tại
                currentUsername = username

                // Lưu localizedCallerName vào UserDefaults và biến hiện tại
                currentLocalizedCallerName = localizedCallerName
                saveLocalizedCallerName(localizedCallerName)
                
                // save hard-code current remote name
                self.currentRemoteName = localizedCallerName

                // Register to SIP server
                loginViewController.onLine(
                    username: username,
                    displayName: displayName,
                    authName: authName,
                    password: password,
                    userDomain: userDomain,
                    sipServer: sipServer,
                    sipServerPort: sipServerPort,
                    transportType: 0,
                    srtpType: 0,
                    enableDebugLog: enableDebugLog
                )

                result(true)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing or invalid arguments for login",
                        details: nil))
            }
        case "call":
            if let args = call.arguments as? [String: Any],
                let phoneNumber = args["phoneNumber"] as? String,
                let isVideoCall = args["isVideoCall"] as? Bool
            {

                // Kiểm tra trạng thái đăng ký trước khi thực hiện cuộc gọi
                if loginViewController.sipRegistrationStatus == .LOGIN_STATUS_ONLINE {
                    // Sử dụng hàm makeCall có sẵn trong plugin
                    let sessionId = makeCall(phoneNumber, videoCall: isVideoCall)
                    result(sessionId > 0)
                } else {
                    result(
                        FlutterError(
                            code: "NOT_REGISTERED",
                            message: "SIP registration required before making calls",
                            details: nil))
                }
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing or invalid arguments for call",
                        details: nil))
            }
        case "Offline":
            if let args = call.arguments as? [String: Any],
                let disablePushNoti = args["disablePushNoti"] as? Bool
            {
                addPushSupportWithPortPBX(!disablePushNoti)
            }

            self.loginViewController.offLine()
            result(true)
        case "hangup":
            hangUpCall()
            result(true)
        case "hold":
            holdCall()
            result(true)
        case "unhold":
            unholdCall()
            result(true)
        case "mute":
            muteMicrophone(true)
            result(true)
        case "unmute":
            muteMicrophone(false)
            result(true)
        case "cameraOn":
            toggleCamera(true)
            result(true)
        case "cameraOff":
            toggleCamera(false)
            result(true)
        case "answer":
            answerCall(isAutoAnswer: false)
            result(true)
        case "reject":
            hangUpCall()
        case "transfer":
            if let args = call.arguments as? [String: Any],
                let destination = args["destination"] as? String
            {
                referCall(destination)
                result(true)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT", message: "Destination is required for transfer",
                        details: nil))
            }
        case "switchCamera":
            let switchResult = switchCamera()
            result(switchResult)
        case "setSpeaker":
            if let args = call.arguments as? [String: Any] {
                if let state = args["state"] as? String {
                    if state == "SPEAKER_PHONE" {
                        setLoudspeakerStatus(true)
                        result(true)
                    } else if state == "EARPIECE" {
                        setLoudspeakerStatus(false)
                        result(true)
                    } else {
                        NSLog("[setSpeaker] Invalid state: %@", state)
                        result(
                            FlutterError(
                                code: "INVALID_ARGUMENTS",
                                message: "Invalid state for setSpeaker: \(state)", details: nil))
                    }
                } else {
                    NSLog("[setSpeaker] Missing or invalid 'state' argument")
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENTS",
                            message: "Missing or invalid arguments for setSpeaker", details: nil))
                }
            } else {
                NSLog("[setSpeaker] Missing arguments dictionary")
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing or invalid arguments for setSpeaker", details: nil))
            }
        case "reInvite":
            if let args = call.arguments as? [String: Any],
                let sessionId = args["sessionId"] as? String
            {
                reInvite(sessionId)
                xSessionIdRecv = sessionId
                result(true)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing or invalid arguments for reInvite",
                        details: nil))
            }
        case "updateVideoCall":
            if let args = call.arguments as? [String: Any],
                let isVideo = args["isVideo"] as? Bool
            {
                // Check if we have an active session
                if activeSessionid <= CLong(INVALID_SESSION_ID) {
                    NSLog("❌ updateVideoCall - Cannot reinvite - no active session")
                    result(false)
                    return
                }

                guard let sessionResult = _callManager.findCallBySessionID(activeSessionid) else {
                    NSLog("❌ updateVideoCall - Cannot find session with ID: \(activeSessionid)")
                    result(false)
                    return
                }

                // 🔍 LOG: Session state BEFORE update
                NSLog("🔍 updateVideoCall - BEFORE:")
                NSLog("🔍   sessionId: \(sessionResult.session.sessionId)")
                NSLog("🔍   videoState: \(sessionResult.session.videoState)")
                NSLog("🔍   videoMuted: \(sessionResult.session.videoMuted)")
                NSLog("🔍   sessionState: \(sessionResult.session.sessionState)")
                NSLog("🔍   activeSessionid: \(activeSessionid)")

                // Update video state
                sessionResult.session.videoState = true

                // 🔍 LOG: Session state AFTER manual update
                NSLog("🔍 updateVideoCall - AFTER setting videoState=true:")
                NSLog("🔍   videoState: \(sessionResult.session.videoState)")
                NSLog("🔍   videoMuted: \(sessionResult.session.videoMuted)")

                // Send video from camera
                //                setCamera(useFrontCamera: mUseFrontCamera)
                let sendVideoRes = portSIPSDK.sendVideo(
                    sessionResult.session.sessionId, sendState: isVideo)
                NSLog("🔍 updateVideoCall - sendVideo(\(isVideo)): \(sendVideoRes)")

                // Update call to add video stream
                let updateRes = portSIPSDK.updateCall(
                    sessionResult.session.sessionId, enableAudio: true, enableVideo: isVideo)
                NSLog("🔍 updateVideoCall - updateCall(audio=true, video=\(isVideo)): \(updateRes)")

                // 🔥 SIMPLE: Just send notification, let views handle themselves
                let videoState = PortSIPVideoState(
                    sessionId: Int64(sessionResult.session.sessionId),
                    isVideoEnabled: isVideo,
                    isCameraOn: isVideo,
                    useFrontCamera: mUseFrontCamera
                )
                PortSIPStateManager.shared.updateVideoState(videoState)

                result(updateRes == 0)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing or invalid arguments for updateVideoCall", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onRegisterSuccess(_ statusText: String!, statusCode: Int32, sipMessage: String!) {
        NSLog(
            "onRegisterSuccess Status: \(String(describing: statusText)), Message: \(String(describing: sipMessage))"
        )
        sipRegistered = true
        methodChannel?.invokeMethod("onlineStatus", arguments: true)
        methodChannel?.invokeMethod("registrationStateStream", arguments: true)
        NSLog("onRegisterSuccess")
    }

    public func onRegisterFailure(_ statusText: String!, statusCode: Int32, sipMessage: String!) {
        NSLog(
            "onRegisterFailure Status: \(String(describing: statusText)), Message: \(String(describing: sipMessage))"
        )
        sipRegistered = false
        methodChannel?.invokeMethod("onlineStatus", arguments: false)
        methodChannel?.invokeMethod("registrationStateStream", arguments: false)
        //    loginViewController.unRegister()
        NSLog("onRegisterFailure")
    }

    // Thêm phương thức mới để xử lý camera
    func toggleCamera(_ enable: Bool) {
        NSLog("toggleCamera: \(enable)")
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            let result = _callManager.findCallBySessionID(activeSessionid)
            if result != nil {
                if enable {
                    // Bật camera
                    portSIPSDK.sendVideo(activeSessionid, sendState: true)
                    result!.session.videoMuted = false  // Camera unmuted
                    print("Camera turned on")
                } else {
                    // Tắt camera - chỉ mute camera chứ không disable video hoàn toàn
                    portSIPSDK.sendVideo(activeSessionid, sendState: false)
                    result!.session.videoMuted = true  // Camera muted
                    print("Camera turned off")
                }

                // QUAN TRỌNG: Vẫn giữ videoState = true để views không bị ẩn
                // Chỉ thay đổi videoMuted state
                result!.session.videoState = true

                // Cập nhật state manager với thông tin chính xác
                let videoState = PortSIPVideoState(
                    sessionId: Int64(activeSessionid),
                    isVideoEnabled: true,  // Video vẫn enabled
                    isCameraOn: enable,  // Chỉ camera state thay đổi
                    useFrontCamera: mUseFrontCamera
                )
                PortSIPStateManager.shared.updateVideoState(videoState)

                // Gửi tin nhắn với format mới
                let sessionInfo = getCurrentSessionInfo()
                sendCustomMessage(
                    callSessionId: sessionInfo.0, userExtension: sessionInfo.1,
                    type: "update_media_state", payloadKey: "camera", payloadValue: enable)

                sendCameraStateToFlutter(enable)
            }
        }
    }

    // Thêm phương thức để trả lời cuộc gọi
    func answerCall(isAutoAnswer: Bool) {
        NSLog("🔍 answerCall - START")
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            _ = mSoundService.stopRingTone()
            _ = mSoundService.stopRingBackTone()
            let result = _callManager.findCallBySessionID(activeSessionid)
            if result != nil {
                // 🔍 LOG: Session state BEFORE answer
                NSLog("🔍 answerCall - BEFORE answer:")
                NSLog("🔍   activeSessionid: \(activeSessionid)")
                NSLog("🔍   result.session.sessionId: \(result!.session.sessionId)")
                NSLog("🔍   result.session.videoState: \(result!.session.videoState)")
                NSLog("🔍   result.session.videoMuted: \(result!.session.videoMuted)")
                NSLog("🔍   result.session.sessionState: \(result!.session.sessionState)")

                let answerRes = _callManager.answerCall(
                    sessionId: activeSessionid, isVideo: result?.session.videoState ?? false)

                if answerRes == true {
                    //Notice to remote
                    if !isAutoAnswer {
//                        let sessionInfo = getCurrentSessionInfo()
//                        sendCustomMessage(
//                            callSessionId: sessionInfo.0, userExtension: sessionInfo.1,
//                            type: "call_state", payloadKey: "answered", payloadValue: true)
                    }

                    NSLog(
                        "🔍 answerCall() - SDK answer success, waiting for onInviteAnswered() callback"
                    )
                    //                    reInvite(xSessionIdRecv)
                } else {
                    NSLog(
                        "❌ answerCall - Answer call failed with error code: \(String(describing: answerRes))"
                    )
                }

                NSLog(
                    "🔍 answerCall() - Waiting for onInviteAnswered() to send proper state notifications"
                )

                NSLog("🔍 answerCall - Call answered")
            } else {
                NSLog("❌ answerCall - Cannot find session for activeSessionid: \(activeSessionid)")
            }
        } else {
            NSLog("❌ answerCall - No active session - \(activeSessionid)")
        }
    }

    // Thêm phương thức để từ chối cuộc gọi
    func rejectCall() {
        NSLog("rejectCall")
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            let result = _callManager.findCallBySessionID(activeSessionid)
            if result != nil && !result!.session.sessionState {
                portSIPSDK.rejectCall(activeSessionid, code: 486)
                _callManager.removeCall(call: result!.session)
                print("Call rejected")
            }
        }
    }

    func sendCallStateToFlutter(_ state: CallState) {
        // Gửi trạng thái cơ bản
        print("sendCallStateToFlutter: \(state)")
        methodChannel?.invokeMethod("callState", arguments: state.rawValue)

        // Cập nhật state manager thay vì gọi trực tiếp UI
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            if let result = _callManager.findCallBySessionID(activeSessionid) {
                let callDetails: [String: Any] = [
                    "sessionId": activeSessionid,
                    "hasVideo": result.session.videoState,
                    "state": state.rawValue,
                ]
                methodChannel?.invokeMethod("callDetails", arguments: callDetails)

                // Cập nhật state manager
                let portSIPState = PortSIPCallState(
                    sessionId: Int64(activeSessionid),
                    hasVideo: result.session.videoState,
                    hasAudio: true,  // Mặc định là có audio
                    isIncoming: !result.session.recvCallState,
                    remoteParty: nil,  // Có thể thêm thông tin này nếu cần
                    remoteDisplayName: nil,
                    state: mapToPortSIPCallStateType(state)
                )
                PortSIPStateManager.shared.updateCallState(portSIPState)
            }
        }
    }

    // Helper method để map CallState sang PortSIPCallState.CallStateType
    private func mapToPortSIPCallStateType(_ state: CallState) -> PortSIPCallState.CallStateType {
        switch state {
        case .INCOMING:
            return .incoming
        case .TRYING:
            return .trying
        case .CONNECTED:
            return .connected
        case .ANSWERED:
            return .answered
        case .FAILED:
            return .failed
        case .CLOSED:
            return .closed
        default:
            return .closed
        }
    }

    // Gửi trạng thái camera
    func sendCameraStateToFlutter(_ isOn: Bool) {
        methodChannel?.invokeMethod("cameraState", arguments: isOn)

        // Cập nhật state manager - Video vẫn enabled, chỉ camera state thay đổi
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            let videoState = PortSIPVideoState(
                sessionId: Int64(activeSessionid),
                isVideoEnabled: true,  // Video luôn enabled để views không bị ẩn
                isCameraOn: isOn,  // Chỉ camera state thay đổi
                useFrontCamera: mUseFrontCamera
            )
            PortSIPStateManager.shared.updateVideoState(videoState)
        }
    }

    // Gửi trạng thái microphone
    func sendMicrophoneStateToFlutter(_ isMuted: Bool) {
        methodChannel?.invokeMethod("microphoneState", arguments: isMuted)

        // Cập nhật state manager
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            let audioState = PortSIPAudioState(
                sessionId: Int64(activeSessionid),
                isMicrophoneMuted: isMuted,
                isSpeakerOn: true  // Có thể cần track trạng thái speaker riêng
            )
            PortSIPStateManager.shared.updateAudioState(audioState)
        }
    }

    // REMOVED: No shared view controller instances in Android pattern

    func switchCamera() -> Bool {
        NSLog("switchCamera() called")

        // Safety check: ensure there's an active session
        guard activeSessionid != CLong(INVALID_SESSION_ID) else {
            NSLog("switchCamera() failed - no active session")
            return false
        }

        // Safety check: ensure it's a video call
        guard let result = _callManager.findCallBySessionID(activeSessionid),
            result.session.videoState
        else {
            NSLog("switchCamera() failed - not a video call or session not found")
            return false
        }

        // Safety check: ensure SDK is initialized
        guard let sdk = portSIPSDK else {
            NSLog("switchCamera() failed - portSIPSDK is nil")
            return false
        }

        // 🔥 ANDROID PATTERN: Just update SIP and send state notification
        let newUseFrontCamera = !mUseFrontCamera
        setCamera(useFrontCamera: newUseFrontCamera)
        mUseFrontCamera = newUseFrontCamera

        // Send state notification - views will handle themselves
        let videoState = PortSIPVideoState(
            sessionId: Int64(activeSessionid),
            isVideoEnabled: true,
            isCameraOn: true,
            useFrontCamera: newUseFrontCamera
        )
        PortSIPStateManager.shared.updateVideoState(videoState)

        NSLog(
            "SDK-iOS: Camera switched to \(newUseFrontCamera ? "front" : "back") via state notification"
        )
        return true
    }

    // REMOVED: No direct view controller calls in Android pattern

    public func setCamera(useFrontCamera: Bool) {
        if useFrontCamera {
            print("SDK-iOS: Setting front camera (ID 1)")
            portSIPSDK.setVideoDeviceId(1)
        } else {
            print("SDK-iOS: Setting back camera (ID 0)")
            portSIPSDK.setVideoDeviceId(0)
        }
    }

    func reInvite(_ sessionId: String) {
        NSLog("reInvite with sessionId: \(sessionId)")

        // Check if we have an active session
        if activeSessionid <= CLong(INVALID_SESSION_ID) {
            NSLog("Cannot reinvite - no active session")
            return
        }

        guard let sessionResult = _callManager.findCallBySessionID(activeSessionid) else {
            NSLog("Cannot find session with ID: \(activeSessionid)")
            return
        }

        // Get the SIP message from active session
        NSLog("SIP message X-Session-Id: \(self.xSessionId)")

        // Compare with the provided sessionId
        if self.xSessionId == sessionId {
            // Update video state
            sessionResult.session.videoState = true

            // Send video from camera
            setCamera(useFrontCamera: mUseFrontCamera)
            let sendVideoRes = portSIPSDK.sendVideo(
                sessionResult.session.sessionId, sendState: true)
            NSLog("reinviteSession - sendVideo(): \(sendVideoRes)")

            // Update call to add video stream
            let updateRes = portSIPSDK.updateCall(
                sessionResult.session.sessionId, enableAudio: true, enableVideo: true)
            NSLog("reinviteSession - updateCall(): \(updateRes)")

            // 🔥 ANDROID PATTERN: Send state notification instead of direct calls
            let videoState = PortSIPVideoState(
                sessionId: Int64(sessionResult.session.sessionId),
                isVideoEnabled: true,
                isCameraOn: true,
                useFrontCamera: mUseFrontCamera
            )
            PortSIPStateManager.shared.updateVideoState(videoState)

            NSLog("Successfully updated call with video for session: \(sessionId)")
        } else {
            NSLog("SessionId not match. SIP message ID: \(self.xSessionId), Request: \(sessionId)")
        }
    }

    // MARK: - Custom Message Methods

    /**
     * Gửi tin nhắn với format JSON mới
     */
    func sendCustomMessage(
        callSessionId: String, userExtension: String, type: String, payloadKey: String,
        payloadValue: Any
    ) {
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            do {
                // Tạo payload object
                let payload: [String: Any] = [payloadKey: payloadValue]

                // Tạo message object
                let message: [String: Any] = [
                    "sessionId": callSessionId,
                    "extension": userExtension,
                    "type": type,
                    "payload": payload,
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

                NSLog("SDK-iOS: Sending custom message: \(jsonString)")

                let messageData = jsonString.data(using: .utf8)!
                let resSendMsg = portSIPSDK.sendMessage(
                    activeSessionid,
                    mimeType: "text",
                    subMimeType: "plain",
                    message: messageData,
                    messageLength: Int32(messageData.count))
                NSLog("SDK-iOS: Send custom message result: \(resSendMsg)")
            } catch {
                NSLog("SDK-iOS: Error creating custom message: \(error.localizedDescription)")
            }
        }
    }

    /**
     * Helper method để lấy session ID và extension hiện tại
     */
    private func getCurrentSessionInfo() -> (String, String) {
        let sessionId = !currentSessionid.isEmpty ? currentSessionid : "empty_X_Session_Id"
        let userExtension = !currentUsername.isEmpty ? currentUsername : "unknown"
        return (sessionId, userExtension)
    }

}
