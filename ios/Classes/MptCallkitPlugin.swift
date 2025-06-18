import PushKit
import UIKit
import Flutter
import PortSIPVoIPSDK


public class MptCallkitPlugin: FlutterAppDelegate, FlutterPlugin, PKPushRegistryDelegate, CallManagerDelegate, PortSIPEventDelegate {
   public func onSendOutOfDialogMessageSuccess(_ messageId: Int, fromDisplayName: String!, from: String!, toDisplayName: String!, to: String!, sipMessage: String!) {
       NSLog("onSendOutOfDialogMessageSuccess messageId: \(messageId)")
   }
  
   public static let shared = MptCallkitPlugin()
   var methodChannel: FlutterMethodChannel?
   
   // public method để set APNs push token
   public func setAPNsPushToken(_ token: String) {
       _APNsPushToken = token as NSString
   }
   
   public static func register(with registrar: FlutterPluginRegistrar) {
       let channel = FlutterMethodChannel(name: "mpt_callkit", binaryMessenger: registrar.messenger())
       let instance = shared
       instance.methodChannel = channel
       registrar.addMethodCallDelegate(instance, channel: channel)

       let factory = FLNativeViewFactory(messenger: registrar.messenger(), videoViewController: instance.videoViewController)
       registrar.register(factory, withId: "VideoView")

       let localFactory = LocalViewFactory(messenger: registrar.messenger(), localViewController: instance.localViewController)
       registrar.register(localFactory, withId: "LocalView")
       
       let remoteFactory = RemoteViewFactory(messenger: registrar.messenger(), remoteViewController: instance.remoteViewController)
       registrar.register(remoteFactory, withId: "RemoteView")
   }
  
   var sipRegistered: Bool!
   var portSIPSDK: PortSIPSDK!
   var mSoundService: SoundService!
   var internetReach: Reachability!
   var _callManager: CallManager!
   var videoManager: VideoManager!
   var videoViewController: VideoViewController!
   var localViewController: LocalViewController!
   var remoteViewController: RemoteViewController!
  
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
  
   var _VoIPPushToken: NSString!
   var _APNsPushToken: NSString!
   var _backtaskIdentifier: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    
  var currentSessionid: String = ""
    var xSessionId: String = ""
  
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
       for i in 0 ..< MAX_LINES {
           if lineSessions[i] == sessionid {
               print("findSession, SessionId = \(sessionid)")
               return i
           }
       }
       print("Can't find session, Not exist this SessionId = \(sessionid)")
       return -1
   }
  
   func findIdleLine() -> (Int) {
       for i in 0 ..< MAX_LINES {
           if lineSessions[i] == CLong(INVALID_SESSION_ID) {
               return i
           }
       }
       print("No idle line available. All lines are in use.")
       return -1
   }
  
   func freeLine(sessionid: CLong) {
       for i in 0 ..< MAX_LINES {
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
       UserDefaults.standard.register(defaults: ["CallKit": false])
       UserDefaults.standard.register(defaults: ["PushNotification": true])
       UserDefaults.standard.register(defaults: ["ForceBackground": true])
      
       let enableCallKit = UserDefaults.standard.bool(forKey: "CallKit")
       _enablePushNotification = UserDefaults.standard.bool(forKey: "PushNotification")
       _enableForceBackground = UserDefaults.standard.bool(forKey: "ForceBackground")
      
       let cxProvider = PortCxProvider.shareInstance
       _callManager = CallManager(portsipSdk: portSIPSDK)
       _callManager.delegate = self
       _callManager.enableCallKit = enableCallKit
       cxProvider.callManager = _callManager
      
      
       _activeLine = 0
       activeSessionid = CLong(INVALID_SESSION_ID)
       for _ in 0 ..< MAX_LINES {
           lineSessions.append(CLong(INVALID_SESSION_ID))
       }
      
       sipRegistered = false
       isConference = false
  
       videoViewController = VideoViewController()
       localViewController = LocalViewController()
       remoteViewController = RemoteViewController()
       loginViewController = LoginViewController(portSIPSDK: portSIPSDK)
       videoViewController.portSIPSDK = portSIPSDK
       localViewController.portSIPSDK = portSIPSDK
       remoteViewController.portSIPSDK = portSIPSDK
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
   public override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
       // This method will handle foreground notifications
       print("Received notification in foreground: \(notification.request.content.userInfo)")
       completionHandler([.alert, .sound])
   }
  
   @available(iOS 10.0, *)
   public override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
       // This method will handle background notifications or tapped notifications
       print("Received notification response: \(response.notification.request.content.userInfo)")
       completionHandler()
   }
  
   // 8.0 < iOS < 10.0
   private func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject: AnyObject], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
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
           let pushMessage: String = NSString(format: "device-os=ios;device-uid=%@;allow-call-push=true;allow-message-push=true;app-id=%@", token, bundleIdentifier) as String
          
           print("Enable pushMessage:{\(pushMessage)}")
          
           portSIPSDK.addSipMessageHeader(-1, methodName: "REGISTER", msgType: 1, headerName: "X-Push", headerValue: pushMessage)
       } else {
           let pushMessage: String = NSString(format: "device-os=ios;device-uid=%@;allow-call-push=false;allow-message-push=false;app-id=%@", token, bundleIdentifier) as String
          
           print("Disable pushMessage:{\(pushMessage)}")
          
           portSIPSDK.addSipMessageHeader(-1, methodName: "REGISTER", msgType: 1, headerName: "X-Push", headerValue: pushMessage)
       }
   }
  
   func updatePushStatusToSipServer() {
       // This VoIP Push is only work with
       // PortPBX(https://www.portsip.com/portsip-pbx/)
       // if you want work with other PBX, please contact your PBX Provider
      
       addPushSupportWithPortPBX(_enablePushNotification!)
       loginViewController.refreshRegister()
   }
  
   func processPushMessageFromPortPBX(_ dictionaryPayload: [AnyHashable: Any], completion: () -> Void) {
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
      
       let parsedObject = dictionaryPayload
       var isVideoCall = false
       let msgType = parsedObject["msg_type"] as? String
       if (msgType?.count ?? 0) > 0 {
           if msgType == "video" {
               isVideoCall = true
           } else if msgType == "aduio" {
               isVideoCall = false
           }
       }
      
       var uuid: UUID?
       let pushId = dictionaryPayload["X-Push-Id"]
      
       if pushId != nil {
           let uuidStr = pushId as! String
           uuid = UUID(uuidString: uuidStr)
       }
       if uuid == nil {
           return
       }
      
       let sendFrom = parsedObject["send_from"]
       let sendTo = parsedObject["send_to"]
      
       if !_callManager.enableCallKit {
           // If not enable Call Kit, show the local Notification
           postNotification(title: "SIPSample", body: "You receive a new call From:\(String(describing: sendFrom)) To:\(String(describing: sendTo))", sound: UNNotificationSound.default, trigger:nil)
       } else {
           _callManager.incomingCall(sessionid: -1, existsVideo: isVideoCall, remoteParty: sendFrom as! String,
                                     remoteDisplayName: sendFrom as! String, callUUID: uuid!, completionHandle: completion)
           loginViewController.refreshRegister()
           beginBackgroundRegister()
       }
   }
  
   public func pushRegistry(_: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for _: PKPushType) {
       var deviceTokenString = String()
       let bytes = [UInt8](pushCredentials.token)
       for item in bytes {
           deviceTokenString += String(format: "%02x", item & 0x0000_00FF)
       }
      
       _VoIPPushToken = NSString(string: deviceTokenString)
      
       print("didUpdatePushCredentials token=", deviceTokenString)
      
       updatePushStatusToSipServer()
   }
  
   public func pushRegistry(_: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for _: PKPushType) {
       print("didReceiveIncomingPushWith:payload=", payload.dictionaryPayload)
       if sipRegistered,
          UIApplication.shared.applicationState == .active || _callManager.getConnectCallNum() > 0 { // ignore push message when app is active
           print("didReceiveIncomingPushWith:ignore push message when ApplicationStateActive or have active call. ")
          
           return
       }
      
       processPushMessageFromPortPBX(payload.dictionaryPayload, completion: {})
   }
  
   public func pushRegistry(_: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for _: PKPushType, completion: @escaping () -> Void) {
       print("didReceiveIncomingPushWith:payload=", payload.dictionaryPayload)
       if sipRegistered,
          UIApplication.shared.applicationState == .active || _callManager.getConnectCallNum() > 0 { // ignore push message when app is active
           print("didReceiveIncomingPushWith:ignore push message when ApplicationStateActive or have active call. ")
          
           return
       }
      
       processPushMessageFromPortPBX(payload.dictionaryPayload, completion: completion)
   }
  
   func beginBackgroundRegister() {
       _backtaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
           self.endBackgroundRegister()
          
       })
      
       if #available(iOS 10.0, *) {
           Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { _ in
              
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
  
   func postNotification(title:String,body:String, sound:UNNotificationSound?, trigger: UNNotificationTrigger?){
       // Configure the notification's payload.
       let content = UNMutableNotificationContent()
       content.title = title
       content.body = body
       content.sound = sound
      
       let request = UNNotificationRequest(identifier: "FiveSecond", content: content, trigger: trigger)
       let center = UNUserNotificationCenter.current()
       center.add(request) { (error : Error?) in
           if error != nil {
               // Handle any errors
           }
       }
   }
  
   public override func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
       print("application(_: UIApplication")
       var deviceTokenString = String()
       let bytes = [UInt8](deviceToken)
       for item in bytes {
           deviceTokenString += String(format: "%02x", item & 0x0000_00FF)
       }
      
       _APNsPushToken = NSString(string: deviceTokenString)
       updatePushStatusToSipServer()
   }
  
   private func registerAppNotificationSettings(launchOptions _: [UIApplication.LaunchOptionsKey: Any]?) {}
  
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
       NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged), name: NSNotification.Name.reachabilityChanged, object: nil)


       internetReach.startNotifier()
   }


   func stopNotifierNetwork() {
       internetReach.stopNotifier()


       NotificationCenter.default.removeObserver(self, name: NSNotification.Name.reachabilityChanged, object: nil)
   }
  
   // MARK: - UIApplicationDelegate
  
   public override func applicationDidEnterBackground(_: UIApplication) {
       // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
       // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
      
       if(_callManager.getConnectCallNum()>0){
           return;
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
  
   public override func applicationWillEnterForeground(_: UIApplication) {
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
           portSIPSDK.unRegisterServer(90);
          
           Thread.sleep(forTimeInterval: 1.0)
          
           print("applicationWillTerminate")
       }
   }
  
   // PortSIPEventDelegate
  
   // Call Event
   public func onInviteIncoming(_ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!, callee: String!, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool, existsVideo: Bool, sipMessage: String!) {
       NSLog("onInviteIncoming...")
       self.activeSessionid = sessionId
//       portSIPSDK.answerCall(sessionId, videoCall: true)
       let num = _callManager.getConnectCallNum()
       let index = findIdleLine()
       if num >= MAX_LINES || index < 0 {
           portSIPSDK.rejectCall(sessionId, code: 486)
           return
       }
       let remoteParty = caller
       let remoteDisplayName = callerDisplayName
      
       var uuid: UUID?
       if _enablePushNotification! {
          
           let pushId = portSIPSDK.getSipMessageHeaderValue(sipMessage, headerName: "X-Push-Id")
           if pushId != nil {
               uuid = UUID(uuidString: pushId!)
           }
       }
       if uuid == nil {
           uuid = UUID()
       }
       lineSessions[index] = sessionId
      
       _callManager.incomingCall(sessionid: sessionId, existsVideo: existsVideo, remoteParty: remoteParty!, remoteDisplayName: remoteDisplayName!, callUUID: uuid!, completionHandle: {})
      
       self.currentSessionid = portSIPSDK.getSipMessageHeaderValue(sipMessage, headerName: "X-Session-Id")

       methodChannel?.invokeMethod("curr_sessionId", arguments: self.currentSessionid)
       
       // Auto answer call
       if portSIPSDK.getSipMessageHeaderValue(sipMessage, headerName: "Answer-Mode") == "Auto;require" {
            print("onInviteIncoming - Outgoing call API")
            answerCall()
            self.xSessionId = portSIPSDK.getSipMessageHeaderValue(sipMessage, headerName: "X-Session-Id")
            methodChannel?.invokeMethod("callType", arguments: "OUTGOING_CALL")
       }
       else{
            print("onInviteIncoming - Incoming call API")
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
  
   public func onInviteSessionProgress(_ sessionId: Int, audioCodecs: String!, videoCodecs: String!, existsEarlyMedia: Bool, existsAudio: Bool, existsVideo: Bool, sipMessage: String!) {
       NSLog("onInviteSessionProgress...")
       let index = findSession(sessionid: sessionId)
       if index == -1 {
           return
       }
      
       if existsEarlyMedia {
           // Checking does this call has video
           if existsVideo {
               // This incoming call has video
               // If more than one codecs using, then they are separated with "#",
               // for example: "g.729#GSM#AMR", "H264#H263", you have to parse them by yourself.
           }
          
           if existsAudio {
               // If more than one codecs using, then they are separated with "#",
               // for example: "g.729#GSM#AMR", "H264#H263", you have to parse them by yourself.
           }
       }
      
       let result = _callManager.findCallBySessionID(sessionId)
      
       result!.session.existEarlyMedia = existsEarlyMedia
      
   }
  
   public func onInviteRinging(_ sessionId: Int, statusText: String!, statusCode: Int32, sipMessage: String!) {
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
  
   public func onInviteAnswered(_ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!, callee: String!, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool, existsVideo: Bool, sipMessage: String!) {
       NSLog("onInviteAnswered... sessionId: \(sessionId), existsVideo: \(existsVideo)")
       guard let result = _callManager.findCallBySessionID(sessionId) else {
           NSLog("Not exist this SessionId = \(sessionId)")
           return
       }
       
       result.session.sessionState = true
       result.session.videoState = existsVideo
       result.session.videoMuted = !existsVideo
       
       if existsVideo {
           // Đảm bảo camera được thiết lập đúng
           NSLog("Setting camera and initializing video views")
           setCamera(useFrontCamera: mUseFrontCamera)
           
           // Khởi tạo rõ ràng từng view controller
           NSLog("Initializing video controllers")
           videoViewController.onStartVideo(sessionId)
           
           // Đảm bảo local video được khởi tạo và hiển thị
           localViewController.initializeLocalVideo()
           localViewController.updateVideoVisibility(isVisible: true)
           
           // Đảm bảo remote video được khởi tạo và hiển thị
           remoteViewController.onStartVideo(sessionId)
           remoteViewController.updateVideoVisibility(isVisible: true)
           
           // Buộc hiển thị video
           NSLog("⭐️ Call is answered with video - forcing video display")
           forceShowVideo()
       }
       
       // Cập nhật trạng thái video
       updateVideo(sessionId: sessionId)
       
       if result.session.isReferCall {
           result.session.isReferCall = false
           result.session.originCallSessionId = -1
       }
       
       if isConference == true {
           _callManager.joinToConference(sessionid: sessionId)
       }
       mSoundService.stopRingBackTone()
       mSoundService.stopRingTone()
       
       // Gửi trạng thái về Flutter
       sendCallStateToFlutter(.ANSWERED)
   }
  
   public func onInviteFailure(_ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!, callee: String!, reason: String!, code: Int32, sipMessage: String!) {
       NSLog("onInviteFailure...")
       if(sessionId==INVALID_SESSION_ID){
           NSLog("This is an invalidate session from \(caller!).reason=\(reason!)");
           return
       }
       guard let result = _callManager.findCallBySessionID(sessionId) else {
           return
       }


       let tempreaon = NSString(utf8String: reason)


       print("Failed to call on line \(findSession(sessionid: sessionId)),\(tempreaon!),\(code)")


       if result.session.isReferCall {
           let originSession = _callManager.findCallByOrignalSessionID(sessionID: result.session.originCallSessionId)

           if originSession != nil {
               print("Call failure on line \(findSession(sessionid: sessionId)) , \(String(describing: tempreaon)) , \(code)")

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
       videoViewController.onClearState()
    //    loginViewController.offLine()
        
//       remoteViewController.onClearState()
//       localViewController.onClearState()
    //    loginViewController.unRegister()
      
       // Gửi trạng thái về Flutter
       sendCallStateToFlutter(.FAILED)
       methodChannel?.invokeMethod("callType", arguments: "ENDED")
   }
  
    public func onInviteUpdated(_ sessionId: Int, audioCodecs: String!, videoCodecs: String!, screenCodecs: String!, existsAudio: Bool, existsVideo: Bool, existsScreen: Bool, sipMessage: String!) {
       guard let result = _callManager.findCallBySessionID(sessionId) else {
           print("onInviteUpdated... not found sessionId: \(sessionId)")
           return
       }
        
        NSLog("onInviteUpdated... sessionId: \(sessionId) session_videoState: \(result.session.videoState) existsVideo: \(existsVideo) videoCodecs: \(videoCodecs ?? "")")
        
        if (result.session.videoState && !existsVideo && videoCodecs.isEmpty){
            let sendVideoRes = portSIPSDK.sendVideo(result.session.sessionId, sendState: true)
            print("onInviteUpdate... re-sendVideo: \(sendVideoRes)")
            
            let updateRes = portSIPSDK.updateCall(result.session.sessionId, enableAudio: true, enableVideo: true)
            print("onInviteUpdate... re-updateCall: \(updateRes)")
        }
       
       // Cập nhật trạng thái video
       result.session.videoState = existsVideo
       result.session.videoMuted = !existsVideo
       result.session.screenShare = existsScreen
       // Cập nhật giao diện
       updateVideo(sessionId: sessionId)
       
       print("The call has been updated on line \(result.index)")
   }

   public func onInviteConnected(_ sessionId: Int) {
       NSLog("onInviteConnected... sessionId: \(sessionId)")
       guard let result = _callManager.findCallBySessionID(sessionId) else {
           return
       }

       print("The call is connected on line \(findSession(sessionid: sessionId))")
       mUseFrontCamera = true
       
       // Buộc hiển thị video nếu cuộc gọi là video call
       if result.session.videoState {
           NSLog("⭐️ Call is connected with video - forcing video display")
           forceShowVideo()
       }
      
       // Gửi trạng thái về Flutter
       sendCallStateToFlutter(.CONNECTED)
   }
  
   public func onInviteBeginingForward(_ forwardTo: String) {
       NSLog("onInviteBeginingForward...")
       print("Call has been forward to:\(forwardTo)")
   }
  
   public func onInviteClosed(_ sessionId: Int, sipMessage: String) {
       NSLog("onInviteClosed...")
       let result = _callManager.findCallBySessionID(sessionId)
       if result != nil {
           _callManager.endCall(sessionid: sessionId)
       }
       _ = mSoundService.stopRingTone()
       _ = mSoundService.stopRingBackTone()
      
       if activeSessionid == sessionId {
           activeSessionid = CLong(INVALID_SESSION_ID)
       }
       videoViewController.onClearState()
       //    loginViewController.offLine()

//       localViewController.onClearState()
//       remoteViewController.onClearState()
    //    loginViewController.unRegister()
      
       // Gửi trạng thái về Flutter
       sendCallStateToFlutter(.CLOSED)
       methodChannel?.invokeMethod("callType", arguments: "ENDED")
   }
  
   public func onDialogStateUpdated(_ BLFMonitoredUri: String!, blfDialogState BLFDialogState: String!, blfDialogId BLFDialogId: String!, blfDialogDirection BLFDialogDirection: String!) {
      
       NSLog("The user \(BLFMonitoredUri!) dialog state is updated:\(BLFDialogState!), dialog id: \(BLFDialogId!), direction: \(BLFDialogDirection!) ")
   }
  
   public func onRemoteHold(_ sessionId: Int) {
       NSLog("onRemoteHold...")
       let index = findSession(sessionid: sessionId)
       if index == -1 {
           return
       }
   }
  
   public func onRemoteUnHold(_ sessionId: Int, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool, existsVideo: Bool) {
       NSLog("onRemoteUnHold...")
       let index = findSession(sessionid: sessionId)
       if index == -1 {
           return
       }
   }

   // Transfer Event
   public func onReceivedRefer(_ sessionId: Int, referId: Int, to: String!, from: String!, referSipMessage: String!) {
      
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
       /* if you want to reject Refer
        [mPortSIPSDK rejectRefer:referId);
        [numpadViewController setStatusText("Rejected the the refer.");
        */
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
  
   public func onWaitingVoiceMessage(_ messageAccount: String!, urgentNewMessageCount: Int32, urgentOldMessageCount: Int32, newMessageCount: Int32, oldMessageCount: Int32) {
       NSLog("onWaitingVoiceMessage...")
      
   }
  
   public func onWaitingFaxMessage(_ messageAccount: String!, urgentNewMessageCount: Int32, urgentOldMessageCount: Int32, newMessageCount: Int32, oldMessageCount: Int32) {
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
  
   public func onRecvNotifyOfSubscription(_ subscribeId: Int, notifyMessage: String!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32) {
       NSLog("Received an Notify message")
   }
  
   // Instant Message/Presence Event
  
   public func onPresenceRecvSubscribe(_ subscribeId: Int, fromDisplayName: String!, from: String!, subject: String!) {
       NSLog("onPresenceRecvSubscribe...")
   }
   public func onPresenceOnline(_ fromDisplayName: String!, from: String!, stateText: String!) {
       NSLog("onPresenceOnline...")
   }
  
   public func onPresenceOffline(_ fromDisplayName: String!, from: String!) {
       NSLog("onPresenceOffline...")
   }
  
   public func onRecvMessage(_ sessionId: Int, mimeType: String!, subMimeType: String!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32) {
       NSLog("onRecvMessage...")
       let index = findSession(sessionid: sessionId)
       if index == -1 {
           return
       }
      
      
       if mimeType == "text", subMimeType == "plain" {
           let recvMessage = String(cString: messageData)
                   } else if mimeType == "application", subMimeType == "vnd.3gpp.sms" {
           // The messageData is binary data
       } else if mimeType == "application", subMimeType == "vnd.3gpp2.sms" {
           // The messageData is binary data
       }
   }
  
   public func onRTPPacketCallback(_ sessionId: Int, mediaType: Int32, direction: DIRECTION_MODE, rtpPacket RTPPacket: UnsafeMutablePointer<UInt8>!, packetSize: Int32) {
       NSLog("onRTPPacketCallback...")
   }
  
   public func onRecvOutOfDialogMessage(_ fromDisplayName: String!, from: String!, toDisplayName: String!, to: String!, mimeType: String!, subMimeType: String!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32, sipMessage: String!) {
       NSLog("onRecvOutOfDialogMessage...")
      
       if mimeType == "text", subMimeType == "plain" {
           let strMessageData = String(cString: messageData)
           NSLog("Received out of dialog message: \(strMessageData)")
       } else if mimeType == "application", subMimeType == "vnd.3gpp.sms" {
           // The messageData is binary data
           NSLog("Received 3GPP SMS binary data")
       } else if mimeType == "application", subMimeType == "vnd.3gpp2.sms" {
           // The messageData is binary data
           NSLog("Received 3GPP2 SMS binary data")
       }
   }
  
   public func onSendOutOfDialogMessageFailure(_ messageId: Int, fromDisplayName: String!, from: String!, toDisplayName: String!, to: String!, reason: String!, code: Int32, sipMessage: String!) {
       NSLog("onSendOutOfDialogMessageFailure messageId: \(messageId), reason: \(String(describing: reason)), code: \(code)")
   }
  
   public func onSendMessageFailure(_ sessionId: Int, messageId: Int, reason: String!, code: Int32, sipMessage: String!) {
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
  
  
   public func onAudioRawCallback(_: Int, audioCallbackMode _: Int32, data _: UnsafeMutablePointer<UInt8>!, dataLength _: Int32, samplingFreqHz _: Int32) {
       /* !!! IMPORTANT !!!
       
        Don't call any PortSIP SDK API functions in here directly. If you want to call the PortSIP API functions or
        other code which will spend long time, you should post a message to main thread(main window) or other thread,
        let the thread to call SDK API functions or other code.
        */
   }
  
   public func onVideoRawCallback(_: Int, videoCallbackMode _: Int32, width _: Int32, height _: Int32, data: UnsafeMutablePointer<UInt8>!, dataLength: Int32) -> Int32 {
       /* !!! IMPORTANT !!!
       
        Don't call any PortSIP SDK API functions in here directly. If you want to call the PortSIP API functions or
        other code which will spend long time, you should post a message to main thread(main window) or other thread,
        let the thread to call SDK API functions or other code.
        */
       let frameData = Data(bytes: data, count: Int(dataLength))
      
       // Print the first few bytes of the raw video data (hexadecimal representation)
       print("Raw video data (first 16 bytes):", frameData.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))
      
       // Print some additional information
       print("Total data length: \(dataLength) bytes")
      
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
      
       let sessionId = _callManager.makeCall(callee: callee, displayName: displayName, videoCall: videoCall)
      
       if sessionId >= 0 {
           activeSessionid = sessionId
           print("makeCall------------------ \(String(describing: activeSessionid))")
           return activeSessionid
       } else {
           return sessionId
       }
   }
  
   func updateCall() {
       let result = portSIPSDK.updateCall(activeSessionid, enableAudio: true, enableVideo: isVideoCall)
       print("update Call result: \(result) \n")
   }
  
   func hungUpCall() {
       NSLog("hungUpCall")
       if activeSessionid != CLong(INVALID_SESSION_ID) {
           mSoundService.stopRingTone()
           mSoundService.stopRingBackTone()
           _callManager.endCall(sessionid: activeSessionid)
          
           sendCallStateToFlutter(.CLOSED)
       }
   }
  
   func holdCall() {
       NSLog("holdCall")
       if activeSessionid != CLong(INVALID_SESSION_ID) {
//           _callManager.holdCall(sessionid: activeSessionid, onHold: true)
           let holdRes = portSIPSDK.hold(activeSessionid)
           NSLog("holdCall - valid sessionId - holdCall: \(holdRes)")
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
//           _callManager.holdCall(sessionid: activeSessionid, onHold: false)
          let unHoldRes = portSIPSDK.unHold(activeSessionid)
           NSLog("unholdCall - valid sessionId - unHoldCall: \(unHoldRes)")
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
           portSIPSDK.muteSession(activeSessionid, muteIncomingAudio: false, muteOutgoingAudio: mute, muteIncomingVideo: false, muteOutgoingVideo: false)
       }
       sendMicrophoneStateToFlutter(mute)
   }
  
   func setLoudspeakerStatus(_ enable: Bool) {
       do {
           portSIPSDK.setLoudspeakerStatus(enable)
           methodChannel?.invokeMethod("currentAudioDevice", arguments: enable ? "SPEAKER_PHONE" : "EARPIECE")
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
  
   //    #pragma mark - CallManager delegate
  
   func onIncomingCallWithoutCallKit(_ sessionId: CLong, existsVideo: Bool, remoteParty: String, remoteDisplayName: String) {
       NSLog("onIncomingCallWithoutCallKit")
       guard _callManager.findCallBySessionID(sessionId) != nil else {
           return
       }
      
       // Thay đổi phần này: Không hiển thị cảnh báo hoặc UI native, chỉ gửi thông báo đến Flutter
       // Gửi trạng thái về Flutter
       sendCallStateToFlutter(.INCOMING)
      
       // Nếu ứng dụng ở trạng thái nền, có thể hiển thị thông báo hệ thống đơn giản
       if UIApplication.shared.applicationState == .background {
           var stringAlert: String
           if(existsVideo) {
               stringAlert = "Cuộc gọi video từ \(remoteParty)"
           } else {
               stringAlert = "Cuộc gọi từ \(remoteParty)"
           }
          
           postNotification(title: "Cuộc gọi đến", body: stringAlert, sound: UNNotificationSound.default, trigger: nil)
       }
      
       // Phát âm thanh chuông mà không hiển thị UI
       _ = mSoundService.playRingTone()
      
       // KHÔNG hiển thị bất kỳ alert hoặc UI native nào
       // Gửi thêm thông tin chi tiết về cuộc gọi để Flutter có thể hiển thị UI riêng
       let callInfo: [String: Any] = [
           "sessionId": sessionId,
           "hasVideo": existsVideo,
           "remoteParty": remoteParty,
           "remoteDisplayName": remoteDisplayName
       ]
       methodChannel?.invokeMethod("incomingCall", arguments: callInfo)
   }
  
   func onNewOutgoingCall(sessionid: CLong) {
       NSLog("onNewOutgoingCall")
       lineSessions[_activeLine] = sessionid
       videoViewController.initVideoViews()
//       localViewController.initVideoViews()
//       remoteViewController.initVideoViews()
       
    //    if isVideoCall {
    //        videoViewController.onStartVideo(sessionid)
    //        localViewController.onStartVideo(sessionid)
    //        remoteViewController.onStartVideo(sessionid)
    //    } else {
    //        videoViewController.onStartVoiceCall(sessionid)
    //        localViewController.onStartVoiceCall(sessionid)
    //        remoteViewController.onStartVoiceCall(sessionid)
    //    }
   }
  
   func onAnsweredCall(sessionId: CLong) {
       NSLog("onAnsweredCall... sessionId: \(sessionId)")
       let result = _callManager.findCallBySessionID(sessionId)
      
       if result != nil {
           NSLog("Found call session, videoState: \(result!.session.videoState)")
           // Kích hoạt hiển thị video dựa vào trạng thái video
           if result!.session.videoState {
               // Khởi tạo rõ ràng từng view controller
               NSLog("Initializing video controllers")
               videoViewController.onStartVideo(Int(sessionId))
               
               // Đảm bảo local video được khởi tạo và hiển thị
               localViewController.initializeLocalVideo()
               localViewController.updateVideoVisibility(isVisible: true)
               
               // Đảm bảo remote video được khởi tạo và hiển thị
               remoteViewController.onStartVideo(Int(sessionId))
               remoteViewController.updateVideoVisibility(isVisible: true)
           } else {
               videoViewController.onStartVoiceCall(Int(sessionId))
               localViewController.updateVideoVisibility(isVisible: false)
               remoteViewController.updateVideoVisibility(isVisible: false)
           }
          
           let line = findSession(sessionid: sessionId)
           if line >= 0 {
               didSelectLine(line)
           }
       }
      
       mSoundService.stopRingTone()
       mSoundService.stopRingBackTone()
      
       if activeSessionid == CLong(INVALID_SESSION_ID) {
           activeSessionid = sessionId
       }
   }
  
  
   func onCloseCall(sessionId: CLong) {
       NSLog("onCloseCall")
       freeLine(sessionid: sessionId)
      
       let result = _callManager.findCallBySessionID(sessionId)
       if result != nil {
        //    if result!.session.videoState {
        //        videoViewController.onStopVideo(sessionId)
        //        localViewController.onStopVideo(sessionId)
        //        remoteViewController.onStopVideo(sessionId)
        //    }
          
           _callManager.removeCall(call: result!.session)
       }
       if sessionId == activeSessionid {
           activeSessionid = CLong(INVALID_SESSION_ID)
       }
      
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
               if(!isConference){
                   portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: videoViewController.viewRemoteVideo)
                   portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: remoteViewController.viewRemoteVideo)
               }
           }
       }
   }
  
   func createConference(_ conferenceVideoWindow: PortSIPVideoRenderView) {
       print("\(conferenceVideoWindow)")
       if _callManager.createConference(conferenceVideoWindow: conferenceVideoWindow, videoWidth: 352, videoHeight: 288, displayLocalVideoInConference: true) {
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
              let authName = args["authName"] as? String,
              let password = args["password"] as? String,
              let userDomain = args["userDomain"] as? String,
              let sipServer = args["sipServer"] as? String,
              let sipServerPort = args["sipServerPort"] as? Int32 {
              
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
                   srtpType: 0
               )
            //    result(loginViewController.sipInitialized)
               result(true)
           } else {
               result(FlutterError(code: "INVALID_ARGUMENTS",
                                 message: "Missing or invalid arguments for login",
                                 details: nil))
           }
       case "call":
           if let args = call.arguments as? [String: Any],
              let phoneNumber = args["phoneNumber"] as? String,
              let isVideoCall = args["isVideoCall"] as? Bool {
              
               // Kiểm tra trạng thái đăng ký trước khi thực hiện cuộc gọi
               if loginViewController.sipRegistrationStatus == .LOGIN_STATUS_ONLINE {
                   // Sử dụng hàm makeCall có sẵn trong plugin
                   let sessionId = makeCall(phoneNumber, videoCall: isVideoCall)
                   result(sessionId > 0)
               } else {
                   result(FlutterError(code: "NOT_REGISTERED",
                                     message: "SIP registration required before making calls",
                                     details: nil))
               }
           } else {
               result(FlutterError(code: "INVALID_ARGUMENTS",
                                 message: "Missing or invalid arguments for call",
                                 details: nil))
           }
       case "Offline":
           self.loginViewController.offLine()
           result(true)
       case "hangup":
           hungUpCall()
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
           answerCall()
           result(true)
       case "reject":
           if activeSessionid != CLong(INVALID_SESSION_ID) {
               let sessionResult = _callManager.findCallBySessionID(activeSessionid)
               if sessionResult != nil && !sessionResult!.session.sessionState {
                   portSIPSDK.rejectCall(activeSessionid, code: 486)
                   _callManager.removeCall(call: sessionResult!.session)
                   mSoundService.stopRingTone()
                   mSoundService.stopRingBackTone()
                   
                   sendCallStateToFlutter(.CLOSED)
                   methodChannel?.invokeMethod("callType", arguments: "ENDED")
                   result(true)
               } else {
                   result(false)
               }
           } else {
               result(false)
           }
       case "transfer":
           if let args = call.arguments as? [String: Any],
           let destination = args["destination"] as? String {
           referCall(destination)
           result(true)
       } else {
           result(FlutterError(code: "INVALID_ARGUMENT", message: "Destination is required for transfer", details: nil))
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
                       result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid state for setSpeaker: \(state)", details: nil))
                   }
               } else {
                   NSLog("[setSpeaker] Missing or invalid 'state' argument")
                   result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid arguments for setSpeaker", details: nil))
               }
           } else {
               NSLog("[setSpeaker] Missing arguments dictionary")
               result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid arguments for setSpeaker", details: nil))
           }
        case "reInvite":
           if let args = call.arguments as? [String: Any],
              let sessionId = args["sessionId"] as? String {
               reInvite(sessionId)
               result(true)
           } else {
               result(FlutterError(code: "INVALID_ARGUMENTS",
                                 message: "Missing or invalid arguments for reInvite",
                                 details: nil))
           }
                case "updateVideoCall":
           if let args = call.arguments as? [String: Any],
              let isVideo = args["isVideo"] as? Bool {
                       // Check if we have an active session
                if activeSessionid <= CLong(INVALID_SESSION_ID) {
                    NSLog("Cannot reinvite - no active session")
                    result(false)
                }
       
                guard let sessionResult = _callManager.findCallBySessionID(activeSessionid) else {
                    NSLog("Cannot find session with ID: \(activeSessionid)")
                    return;
                }
 
                 // Update video state
                sessionResult.session.videoState = true
                
                // Send video from camera
                setCamera(useFrontCamera: mUseFrontCamera)
                let sendVideoRes = portSIPSDK.sendVideo(sessionResult.session.sessionId, sendState: isVideo)
                NSLog("reinviteSession - sendVideo(): \(sendVideoRes)")
                
                // Update call to add video stream
                let updateRes = portSIPSDK.updateCall(sessionResult.session.sessionId, enableAudio: true, enableVideo: isVideo)
                NSLog("reinviteSession - updateCall(): \(updateRes)")
                // Update the video UI
                updateVideo(sessionId: Int(sessionResult.session.sessionId))
                
                // Buộc hiển thị video
                forceShowVideo()
 
               result(true)
           } else {
               result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid arguments for updateVideoCall", details: nil))}
       default:
           result(FlutterMethodNotImplemented)
       }
   }
  
  
   public func onRegisterSuccess(_ statusText: String!, statusCode: Int32, sipMessage: String!) {
       NSLog("Status: \(String(describing: statusText)), Message: \(String(describing: sipMessage))")
       sipRegistered = true
       methodChannel?.invokeMethod("onlineStatus", arguments: true)
       methodChannel?.invokeMethod("onRegisterSuccess", arguments: true)
       NSLog("onRegisterSuccess")
   }
  
   public func onRegisterFailure(_ statusText: String!, statusCode: Int32, sipMessage: String!) {
       NSLog("Status: \(String(describing: statusText)), Message: \(String(describing: sipMessage))")
       sipRegistered = false
       methodChannel?.invokeMethod("onlineStatus", arguments: false)
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
                   result!.session.videoState = true
                   print("Camera turned on")
               } else {
                   // Tắt camera
                   portSIPSDK.sendVideo(activeSessionid, sendState: false)
                   result!.session.videoState = false
                   print("Camera turned off")
               }


               sendCameraStateToFlutter(enable)
           }
       }
   }
  
   // Thêm phương thức để trả lời cuộc gọi
   func answerCall() {
       NSLog("answerCall")
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            let result = _callManager.findCallBySessionID(activeSessionid)
            if result != nil {
             //    _ = _callManager.answerCall(sessionId: activeSessionid, isVideo: result!.session.videoState)
                mSoundService.stopRingTone()
                mSoundService.stopRingBackTone()
                
                portSIPSDK.answerCall(activeSessionid, videoCall: result!.session.videoState)
                sendCallStateToFlutter(.ANSWERED)
                
                // Đảm bảo video được hiển thị nếu là cuộc gọi video
                if result!.session.videoState {
                    NSLog("⭐️ Call answered with video - forcing video display")
                    // Đặt một timer để đảm bảo video được kích hoạt sau khi cuộc gọi được thiết lập
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.forceShowVideo()
                    }
                }
                else{
                    NSLog("⭐️ Call answered with no video - videoState is false")
                }
                
                print("Call answered")
            }
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
       methodChannel?.invokeMethod("callState", arguments: state.rawValue)
       
       // Gửi thêm thông tin chi tiết nếu có cuộc gọi đang hoạt động
       if activeSessionid != CLong(INVALID_SESSION_ID) {
           if let result = _callManager.findCallBySessionID(activeSessionid) {
               let callDetails: [String: Any] = [
                   "sessionId": activeSessionid,
                   "hasVideo": result.session.videoState,
                   "state": state.rawValue
               ]
               methodChannel?.invokeMethod("callDetails", arguments: callDetails)
           }
       }
       
       // Gửi thông báo cho LocalView và RemoteView
   }
  
   // Gửi trạng thái camera
   func sendCameraStateToFlutter(_ isOn: Bool) {
       methodChannel?.invokeMethod("cameraState", arguments: isOn)
   }


   // Gửi trạng thái microphone
   func sendMicrophoneStateToFlutter(_ isOn: Bool) {
       methodChannel?.invokeMethod("microphoneState", arguments: isOn)
   }

   func switchCamera() -> Bool {
       let value = !mUseFrontCamera
       localViewController.mCameraDeviceId = value == true ? 1: 0
        //    setCamera(useFrontCamera: value)
       localViewController.switchCamera()
       mUseFrontCamera = value
       
       // Log để debug
       print("SDK-iOS: Camera switched to \(value ? "front" : "back")")
       return value
   }

   public func setCamera(useFrontCamera: Bool) {
       if useFrontCamera {
           print("SDK-iOS: Setting front camera (ID 1)")
           portSIPSDK.setVideoDeviceId(1)
       } else {
           print("SDK-iOS: Setting back camera (ID 0)")
           portSIPSDK.setVideoDeviceId(0)
       }
   }

   private func initLocalView() {
       // Thiết lập camera dựa vào trạng thái hiện tại
       setCamera(useFrontCamera: mUseFrontCamera)
       
       // ... existing code ...
   }

   // Thêm phương thức để xử lý video
   func updateVideo(sessionId: CLong) {
       NSLog("⭐️ updateVideo... sessionId: \(sessionId)")
       if let result = _callManager.findCallBySessionID(sessionId) {
           NSLog("⭐️ Found session with ID \(sessionId), session state: \(result.session.sessionState), video state: \(result.session.videoState)")
           
           if isConference {
               print("⭐️ Conference mode enabled")
           } else {
               NSLog("⭐️ Normal call mode")
               
               // Kiểm tra nếu sessionId hợp lệ - video LUÔN LUÔN hiển thị khi có cuộc gọi video đang hoạt động
               if sessionId > 0 {
                   NSLog("⭐️ Session is valid (ID > 0)")
                       
                       // Vẫn cập nhật cho VideoViewController để tương thích ngược
                       videoViewController.viewLocalVideo?.isHidden = false
                       videoViewController.viewRemoteVideo?.isHidden = false
                       
                       // Sử dụng phương thức mới để cập nhật visibility
                       localViewController.updateVideoVisibility(isVisible: true)
                       remoteViewController.updateVideoVisibility(isVisible: true)
                       
                       // Đảm bảo video được gửi đi
                       NSLog("⭐️ Enabling send video state")
                       portSIPSDK.sendVideo(sessionId, sendState: true)
                       
                       // Gọi lại các phương thức khởi tạo video nếu cần
                       NSLog("⭐️ Reinitializing video views to ensure they are active")
                       if !localViewController.isVideoInitialized {
                           localViewController.initializeLocalVideo()
                       }
                       remoteViewController.onStartVideo(Int(sessionId))
               } else {
                   NSLog("⭐️ Invalid session ID (\(sessionId)) - hiding all videos")
                   // Không có cuộc gọi đang diễn ra, tắt video
                   localViewController.updateVideoVisibility(isVisible: false)
                   remoteViewController.updateVideoVisibility(isVisible: false)
                   
                   // Vẫn cập nhật cho VideoViewController để tương thích ngược
                   videoViewController.viewLocalVideo?.isHidden = true
                   videoViewController.viewRemoteVideo?.isHidden = true
               }
           }
       } else {
           NSLog("⭐️ Could not find session with ID \(sessionId) - call may have ended")
       }
   }

   // Thêm phương thức mới để buộc hiển thị video
   func forceShowVideo() {
       NSLog("⭐️ Force showing video for active session: \(activeSessionid ?? CLong(INVALID_SESSION_ID))")
       
       if activeSessionid != CLong(INVALID_SESSION_ID) {
           if let result = _callManager.findCallBySessionID(activeSessionid) {
               if result.session.videoState {
                   NSLog("⭐️ Forcing video display for active call")
                   
                   // Đảm bảo camera được thiết lập đúng
                   setCamera(useFrontCamera: mUseFrontCamera)
                   
                   // Hiển thị các video
                   localViewController.updateVideoVisibility(isVisible: true)
                   remoteViewController.updateVideoVisibility(isVisible: true)
                   
                   // Đảm bảo video được gửi đi
                   portSIPSDK.sendVideo(activeSessionid, sendState: true)
               }
           }
       }
   }

   // Thêm phương thức để gửi thông báo
   private func sendNotification(name: String, userInfo: [AnyHashable: Any]? = nil) {
       NotificationCenter.default.post(name: NSNotification.Name(name), object: nil, userInfo: userInfo)
   }
 
   // Cập nhật các phương thức để gửi thông báo khi trạng thái thay đổi
   func toggleVideo(_ enable: Bool) {
       if activeSessionid != CLong(INVALID_SESSION_ID) {
           let result = _callManager.findCallBySessionID(activeSessionid)
           if result != nil {
               result!.session.videoMuted = !enable
               portSIPSDK.muteSession(activeSessionid, 
                                      muteIncomingAudio: false, 
                                      muteOutgoingAudio: false, 
                                      muteIncomingVideo: false, 
                                      muteOutgoingVideo: !enable)
               
               // Gửi thông báo cho LocalView và RemoteView
               sendNotification(name: "VIDEO_MUTE_STATE_CHANGED")
               
               // Gửi trạng thái đến Flutter
               sendCameraStateToFlutter(enable)
           }
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
       if self.xSessionId  == sessionId {
           // Update video state
           sessionResult.session.videoState = true
           
           // Send video from camera
           setCamera(useFrontCamera: mUseFrontCamera)
           let sendVideoRes = portSIPSDK.sendVideo(sessionResult.session.sessionId, sendState: true)
           NSLog("reinviteSession - sendVideo(): \(sendVideoRes)")
           
           // Update call to add video stream
           let updateRes = portSIPSDK.updateCall(sessionResult.session.sessionId, enableAudio: true, enableVideo: true)
           NSLog("reinviteSession - updateCall(): \(updateRes)")
           // Update the video UI
           updateVideo(sessionId: Int(sessionResult.session.sessionId))
           
           // Buộc hiển thị video
           forceShowVideo()
           
           NSLog("Successfully updated call with video for session: \(sessionId)")
       } else {
           NSLog("SessionId not match. SIP message ID: \(self.xSessionId), Request: \(sessionId)")
       }
   }
}
