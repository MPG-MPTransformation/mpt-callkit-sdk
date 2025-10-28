import Flutter
import PortSIPVoIPSDK
import PushKit
import UIKit
import Foundation
import Darwin
import AVFoundation
import CoreVideo
import CoreImage
import MediaPipeTasksVision
import VideoToolbox
import Accelerate
import Accelerate.vImage

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
        case updated = "UPDATED"
        case failed = "FAILED"
        case closed = "CLOSED"
    }
}

struct PortSIPVideoState {
    let sessionId: Int64
    let isVideoEnabled: Bool
    let isCameraOn: Bool
    let useFrontCamera: Bool
    let conference: Bool
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

enum CALLBACK_DIRECTION_MODE : Int
{
    case DIRECTION_NONE = 0      ///<    NOT EXIST.
    case DIRECTION_SEND_RECV = 1 ///<    both received and sent.
    case DIRECTION_SEND = 2      ///<    Only the sent.
    case DIRECTION_RECV = 3      ///<    Only the received .
    case DIRECTION_INACTIVE = 4  ///<    INACTIVE.
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
        case .updated:
            NotificationCenter.default.post(
                name: .portSIPCallUpdated, object: nil, userInfo: userInfo)
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
            "conference": state.conference,
        ]

        NSLog(
            "PortSIPStateManager: Broadcasting video state - enabled: \(state.isVideoEnabled), camera: \(state.isCameraOn), conference: \(state.conference)"
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
        _APNsPushToken = token
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
        MptCallkitPlugin.localFactory = LocalViewFactory(messenger: registrar.messenger())
        registrar.register(MptCallkitPlugin.localFactory!, withId: "LocalView")

        let remoteFactory = RemoteViewFactory(messenger: registrar.messenger())
        registrar.register(remoteFactory, withId: "RemoteView")
    }
    
    private static var localFactory: LocalViewFactory?

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
    var activeSessionidHasVideo: Bool!
    var activeSessionidHasAudio: Bool!
    var lineSessions: [CLong] = []
    var phone: String = ""
    var displayName: String = ""
    var isVideoCall: Bool = false
    var isRemoteVideoReceived: Bool = false

    var _VoIPPushToken: String?
    var _APNsPushToken: String?
    var _backtaskIdentifier: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

    var currentSessionid: String = ""
    var xSessionId: String = ""
    var xSessionIdRecv: String = ""
    var currentUsername: String = ""  // Lưu username hiện tại
    var currentRemoteName: String = ""
    var currentLocalizedCallerName: String = ""  // Lưu localizedCallerName
    var currentUUID: UUID? = UUID()
    var currentTenantId: Int32 = 0
    var currentAgentId: Int32 = 0

    var _enablePushNotification: Bool?

    var _enableForceBackground: Bool?

    var mUseFrontCamera: Bool = true

    private var mediaPipeProcessor: MediaPipeSegmentationProcessor? = nil
    private var frameCounter: Int = 0
    private static var enableBlurBackground: Bool = false
    
    // Background image variables
    private var bgPath: String? = nil
    private var bgBitmap: UIImage? = nil
    
    // MARK: - Camera Resolution Configuration
    
    // Resolution presets for automatic selection (matching Android CameraSource)
    static let RESOLUTION_LOW = 0      // 480x640
    static let RESOLUTION_MEDIUM = 1   // 720x1280
    static let RESOLUTION_HIGH = 2     // 1080x1920
    static let RESOLUTION_AUTO = 3     // Automatic based on device capabilities
    
    // Resolution configuration
    private var resolutionMode = RESOLUTION_AUTO
    private var requestedWidth = 720
    private var requestedHeight = 1280
    
    // Text overlay configuration (matching Android SegmenterProcessor)
    private static var overlayText = "Agent" // Default text matching Android

    enum CallState: String {
        case INCOMING = "INCOMING"
        case TRYING = "TRYING"
        case CONNECTED = "CONNECTED"
        case IN_CONFERENCE = "IN_CONFERENCE"
        case ANSWERED = "ANSWERED"
        case UPDATED = "UPDATED"
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

        // Initialize MediaPipe segmentation processor (iOS 13+ compatible)
        mediaPipeProcessor = MediaPipeSegmentationProcessor()
        print("MediaPipe Segmentation Status: \(mediaPipeProcessor?.getStatusMessage() ?? "Not available")")
        // Initialize resolution system
        updateRequestedResolution()
        
        // Add session error handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureSessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: captureSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureSessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureSessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )
        
        // Add session state monitoring
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureSessionDidStartRunning),
            name: .AVCaptureSessionDidStartRunning,
            object: captureSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureSessionDidStopRunning),
            name: .AVCaptureSessionDidStopRunning,
            object: captureSession
        )
    }

      private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let buffer = imageBuffer else {
            return
        }

        let orientation: UIImage.Orientation = mUseFrontCamera ? .leftMirrored : .right
        guard let image = UIUtilities.createUIImage(from: buffer, orientation: orientation) else {
            return
        }
        // Draw text on the segmented image (matching Android SegmenterProcessor logic)
        let finalImage = drawTextOnImage(image, text: MptCallkitPlugin.overlayText) ?? image
        
        // Set image in localFactory for UI display
        MptCallkitPlugin.localFactory?.setImage(image: finalImage)
        
        // Send to video stream if remote video is received and session is active
        // Apply rotation and flip transformations for correct orientation
      if let result = _callManager.findCallBySessionID(self.activeSessionid) {
          if result.session.videoState, let yuvData = convertUIImageToI420Data(finalImage) {
              let width = Int(finalImage.size.width)
              let height = Int(finalImage.size.height)
//               print("I420 buffer size = \(yuvData.count) bytes, width = \(width), height = \(height), \(yuvData.count) == \(width * height * 3 / 2)")
              // 🔥 Send to PortSIP
              let result = self.portSIPSDK.sendVideoStream(toRemote: self.activeSessionid,
                                                           data: yuvData,
                                                           width: Int32(width),
                                                           height: Int32(height))
//              print("sendVideoStream result: \(result)")
          }
        }
    }


  // MARK: - Private

  private func startSession() {
    weak var weakSelf = self
    sessionQueue.async {
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      
      // Check camera permission before starting session
      guard strongSelf.hasCameraPermission() else {
        print("❌ startSession failed: Camera permission not granted")
        return
      }
      
      // Prevent multiple simultaneous start attempts
      guard !strongSelf.sessionIsStarted else {
        print("⚠️ startSession skipped: Session already starting or started")
        return
      }
      
      // Set up capture session if not already configured
      if strongSelf.captureSession.inputs.isEmpty || strongSelf.captureSession.outputs.isEmpty {
        print("🔄 Setting up capture session...")
        
        // Configure session
        strongSelf.captureSession.beginConfiguration()
        
        // Update resolution and set preset
        strongSelf.updateRequestedResolution()
        let preset = strongSelf.getOptimalSessionPreset()
        if strongSelf.captureSession.canSetSessionPreset(preset) {
          strongSelf.captureSession.sessionPreset = preset
          print("✅ Session preset set to: \(preset)")
        } else {
          print("⚠️ Cannot set session preset to \(preset), using current: \(strongSelf.captureSession.sessionPreset)")
        }
        
        // Set up outputs if missing
        if strongSelf.captureSession.outputs.isEmpty {
          let output = AVCaptureVideoDataOutput()
          output.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
          ]
          output.alwaysDiscardsLateVideoFrames = true
          let outputQueue = DispatchQueue(label: "com.mpt.outputQueue")
          output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
          
          if strongSelf.captureSession.canAddOutput(output) {
            strongSelf.captureSession.addOutput(output)
            print("✅ Added video output to capture session")
          } else {
            print("❌ Failed to add video output")
            strongSelf.captureSession.commitConfiguration()
            return
          }
        }
        
        // Set up inputs if missing
        if strongSelf.captureSession.inputs.isEmpty {
          let cameraPosition: AVCaptureDevice.Position = strongSelf.mUseFrontCamera ? .front : .back
          guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
            print("❌ Failed to get capture device for camera position: \(cameraPosition)")
            strongSelf.captureSession.commitConfiguration()
            return
          }
          
          guard device.isConnected else {
            print("❌ Camera device not available - isConnected: \(device.isConnected)")
            strongSelf.captureSession.commitConfiguration()
            return
          }
          
          // Check isSuspended only on iOS 14+
          if #available(iOS 14.0, *) {
            guard !device.isSuspended else {
              print("❌ Camera device suspended")
              strongSelf.captureSession.commitConfiguration()
              return
            }
          }
          
          do {
            let input = try AVCaptureDeviceInput(device: device)
            if strongSelf.captureSession.canAddInput(input) {
              strongSelf.captureSession.addInput(input)
              print("✅ Added camera input: \(device.localizedName) (position: \(cameraPosition))")
            } else {
              print("❌ Failed to add camera input")
              strongSelf.captureSession.commitConfiguration()
              return
            }
          } catch {
            print("❌ Failed to create capture device input: \(error.localizedDescription)")
            strongSelf.captureSession.commitConfiguration()
            return
          }
        }
        
        strongSelf.captureSession.commitConfiguration()
        print("✅ Capture session configured - inputs: \(strongSelf.captureSession.inputs.count), outputs: \(strongSelf.captureSession.outputs.count)")
        
        // Ensure SIP SDK compatibility
        strongSelf.ensureSIPCompatibility()
      }
      
      if !strongSelf.captureSession.isRunning {
        print("✅ startSession: Starting capture session with \(strongSelf.captureSession.inputs.count) inputs and \(strongSelf.captureSession.outputs.count) outputs")
        
        // Check for camera availability before starting
        guard strongSelf.isCameraDeviceReady() else {
          print("❌ startSession failed: Camera device not ready")
          return
        }
        
        let cameraPosition: AVCaptureDevice.Position = strongSelf.mUseFrontCamera ? .front : .back
        if let currentDevice = strongSelf.captureDevice(forPosition: cameraPosition) {
          print("🔍 Camera device available: \(currentDevice.localizedName)")
        }
        
        print("🔄 Starting capture session...")
        
        // Mark as starting to prevent race conditions
        strongSelf.sessionIsStarted = true
        
        // Use proper error handling for startRunning
        do {
          try strongSelf.captureSession.startRunning()
          print("✅ Capture session started successfully")
          
          // Check session state immediately after starting
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if strongSelf.captureSession.isRunning {
              print("✅ Session confirmed running immediately after start")
            } else {
              print("⚠️ Session stopped immediately after start - likely interrupted")
              if strongSelf.captureSession.isInterrupted {
                print("⚠️ Session is marked as interrupted")
              }
            }
          }
          
        } catch {
          print("❌ Failed to start capture session: \(error.localizedDescription)")
          strongSelf.sessionIsStarted = false
          
          // Retry after a delay on background queue (not main queue)
          DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            print("🔄 Retrying capture session start on background queue...")
            strongSelf.startSession()
          }
          return
        }
      } else {
        print("ℹ️ Capture session already running")
      }
    }
  }

  private func stopSession() {
    weak var weakSelf = self
    sessionQueue.async {
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      
      // Reset the session started flag
      strongSelf.sessionIsStarted = false
      
      if strongSelf.captureSession.isRunning {
        print("🛑 stopSession: Stopping capture session")
        do {
          strongSelf.captureSession.stopRunning()
          print("✅ Capture session stopped successfully")
        } catch {
          print("❌ Failed to stop capture session: \(error.localizedDescription)")
        }
      } else {
        print("ℹ️ stopSession: Session is not running")
      }
    }
  }
  
  @objc private func captureSessionDidStartRunning(_ notification: Notification) {
    print("✅ AVCaptureSessionDidStartRunning notification received")
  }
  
  @objc private func captureSessionDidStopRunning(_ notification: Notification) {
    print("⚠️ AVCaptureSessionDidStopRunning notification received")
    sessionIsStarted = false
  }

  private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    if #available(iOS 10.0, *) {
      let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera],
        mediaType: .video,
        position: .unspecified
      )
      return discoverySession.devices.first { $0.position == position }
    }
    return nil
  }
  
  /// Safely checks if camera permissions are granted
  private func hasCameraPermission() -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    return status == .authorized
  }
  
  /// Safely checks if camera device is available and ready
  private func isCameraDeviceReady() -> Bool {
    let cameraPosition: AVCaptureDevice.Position = mUseFrontCamera ? .front : .back
    guard let device = captureDevice(forPosition: cameraPosition) else {
      return false
    }
    
    guard device.isConnected else {
      return false
    }
    
    // Check isSuspended only on iOS 14+
    if #available(iOS 14.0, *) {
      return !device.isSuspended
    }
    
    return true
  }
  
  /// Ensures SIP SDK doesn't interfere with our capture session
  private func ensureSIPCompatibility() {
    let sendResult = self.portSIPSDK.enableSendVideoStream(toRemote: self.activeSessionid, state: true)
    print("enableSendVideoStream result: \(sendResult)")
//      if sendResult < 0 {
//          updateCall()
//      }
  }
  
  
  // MARK: - Capture Session Error Handling
  
  @objc private func captureSessionRuntimeError(_ notification: Notification) {
    guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
      print("❌ Capture session runtime error (no error details)")
      return
    }
    
    print("❌ Capture session runtime error: \(error.localizedDescription)")
    print("❌ Error code: \(error.code.rawValue)")
    
    // Reset the session started flag since we're handling an error
    sessionIsStarted = false
    
    // Try to restart session if it's a recoverable error
    sessionQueue.async { [weak self] in
      guard let self = self else { return }
      
      // Only restart if session is not running and we have valid inputs/outputs
      if !self.captureSession.isRunning && 
         !self.captureSession.inputs.isEmpty && 
         !self.captureSession.outputs.isEmpty {
        print("🔄 Attempting to restart capture session after error...")
        
        // Use proper error handling
        do {
          try self.captureSession.startRunning()
          print("✅ Successfully restarted capture session after error")
        } catch {
          print("❌ Failed to restart capture session after error: \(error.localizedDescription)")
        }
      } else {
        print("⚠️ Cannot restart session - inputs: \(self.captureSession.inputs.count), outputs: \(self.captureSession.outputs.count), running: \(self.captureSession.isRunning)")
      }
    }
  }
  
  @objc private func captureSessionWasInterrupted(_ notification: Notification) {
    guard let reasonIntegerValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
          let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) else {
      print("⚠️ Capture session was interrupted (unknown reason)")
      return
    }
    
    print("⚠️ Capture session interrupted: \(reason)")
    
    switch reason {
    case .videoDeviceNotAvailableInBackground:
      print("⚠️ Video device not available in background")
    case .audioDeviceInUseByAnotherClient:
      print("⚠️ Audio device in use by another client")
    case .videoDeviceInUseByAnotherClient:
      print("⚠️ Video device in use by another client - this might be PortSIP!")
    case .videoDeviceNotAvailableWithMultipleForegroundApps:
      print("⚠️ Video device not available with multiple foreground apps")
    @unknown default:
      print("⚠️ Unknown interruption reason")
    }
  }
  
  @objc private func captureSessionInterruptionEnded(_ notification: Notification) {
    print("✅ Capture session interruption ended")
    
    // Try to restart the session
    sessionQueue.async { [weak self] in
      guard let self = self else { return }
      
      // Reset the session started flag since interruption ended
      self.sessionIsStarted = false
      
      if !self.captureSession.isRunning && 
         !self.captureSession.inputs.isEmpty && 
         !self.captureSession.outputs.isEmpty {
        print("🔄 Restarting capture session after interruption ended...")
        
        // Use proper error handling
        do {
          try self.captureSession.startRunning()
          print("✅ Successfully restarted capture session after interruption ended")
        } catch {
          print("❌ Failed to restart capture session after interruption ended: \(error.localizedDescription)")
        }
      } else {
        print("⚠️ Cannot restart session after interruption - inputs: \(self.captureSession.inputs.count), outputs: \(self.captureSession.outputs.count), running: \(self.captureSession.isRunning)")
      }
    }
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
        // Ensure both tokens are available
        guard let voipToken = _VoIPPushToken, let apnsToken = _APNsPushToken else {
            return
        }
        
        // Get the app's bundle identifier
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            print("Bundle identifier not found.")
            return
        }
        
        // Clear any previously added SIP message headers
        portSIPSDK.clearAddedSipMessageHeaders()
        
        // Combine both tokens into one string
        let token = "\(voipToken)|\(apnsToken)"
        
        // Determine push permission values based on enablePush flag
        let allowPush = enablePush ? "true" : "false"
        
        // Construct the push message header value
        let pushMessage = "device-os=ios;device-uid=\(token);allow-call-push=\(allowPush);allow-message-push=\(allowPush);app-id=\(bundleIdentifier)"
        
        // Debug output
        if enablePush {
            print("Enable pushMessage: {\(pushMessage)}")
        } else {
            print("Disable pushMessage: {\(pushMessage)}")
        }
        
        // Add the SIP message header for push notification support
        portSIPSDK.addSipMessageHeader(-1, methodName: "REGISTER", msgType: 1, headerName: "X-Push", headerValue: pushMessage)
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
                    sessionid: -1, existsVideo: true, remoteParty: self.currentRemoteName,
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
            }
        } catch {
            print("❌ Error processing VoIP push: \(error)")
            safeCompletion()
        }
    }

    public func pushRegistry(
        _: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for _: PKPushType
    ) {
        // Convert device token data to a hex string
        var deviceTokenString = String()
        let bytes = [UInt8](pushCredentials.token)
        for item in bytes {
            deviceTokenString += String(format: "%02x", item & 0x0000_00FF)
        }
        
        // Update the VoIP push token only if it has changed
        if _VoIPPushToken != deviceTokenString {
            _VoIPPushToken = deviceTokenString
            let settings = UserDefaults.standard
            settings.set(deviceTokenString, forKey: "kVoIPPushToken")
            
            print("_VoIPPushToken updated: \(deviceTokenString)")
            updatePushStatusToSipServer()
        }
    }

    public func pushRegistry(
        _: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for _: PKPushType
    ) {
        print("didReceiveIncomingPushWith:payload=", payload.dictionaryPayload)
        if sipRegistered,
            UIApplication.shared.applicationState == .active || _callManager.getConnectCallNum() > 0 { // ignore push message when app is active
            print("didReceiveIncomingPushWith:ignore push message when ApplicationStateActive or have active call. ")

            return
        }

        processPushMessageFromPortPBX(payload.dictionaryPayload, completion: {
            self.loginViewController.refreshRegister()
            self.beginBackgroundRegister()
        })
    }

    public func pushRegistry(
        _: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for _: PKPushType,
        completion: @escaping () -> Void
    ) {
        print("didReceiveIncomingPushWith:payload=", payload.dictionaryPayload)
        if sipRegistered,
            UIApplication.shared.applicationState == .active || _callManager.getConnectCallNum() > 0 { // ignore push message when app is active
            print("didReceiveIncomingPushWith:ignore push message when ApplicationStateActive or have active call. ")

            return
        }

        processPushMessageFromPortPBX(payload.dictionaryPayload, completion: {
            self.loginViewController.refreshRegister()
            self.beginBackgroundRegister()
            completion()
        })
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
        // Convert deviceToken data to a hex string
        var deviceTokenString = String()
        let bytes = [UInt8](deviceToken)
        for item in bytes {
            deviceTokenString += String(format: "%02x", item & 0x0000_00FF)
        }
        
        // Update the APNs token only if it has changed
        if _APNsPushToken != deviceTokenString {
            _APNsPushToken = deviceTokenString
            let settings = UserDefaults.standard
            settings.set(deviceTokenString, forKey: "kAPNsPushToken")
            
            print("_APNsPushToken updated: \(deviceTokenString)")
            updatePushStatusToSipServer()
        }
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

    private var backtaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var backtaskTimer: DispatchSourceTimer?

    public func didEnterBackground() {
        _callManager.setForeground(false)
        if _callManager.getConnectCallNum() > 0 {
            return
        }
        NSLog("applicationDidEnterBackground")
        stopSession()
        // if _enableForceBackground! {
        //     // Disable to save battery, or when you don't need incoming calls while APP is in background.
        //     portSIPSDK.startKeepAwake()
        // } else {
        // loginViewController.unRegister()

        // beginBackgroundRegister()
        beginBackgroundTaskForRegister()
        

        //     beginBackgroundRegister()
        // }
        // NSLog("applicationDidEnterBackground End")
    }
    
    private func beginBackgroundTaskForRegister() {
            endBackgroundTaskForRegister()

            backtaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
                NSLog("SipEngine beginBackgroundTaskWithExpirationHandler")
                self?.endBackgroundTaskForRegister()
            }

            startBackTaskTimer()
        }

        private func startBackTaskTimer() {
            // Cancel old timer if exists
            backtaskTimer?.cancel()
            backtaskTimer = nil

            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + 5)

            timer.setEventHandler { [weak self] in
                self?.backtaskTimer = nil
                NSLog("SipEngine finishBackgroundTaskForRegister")
                guard let strongSelf = self else {
                    return
                }
//                let result = strongSelf._callManager.findCallBySessionID(strongSelf.activeSessionid)
//                if result == nil || !result!.session.sessionState {
                strongSelf.loginViewController.unRegister()
//                }
            }

            backtaskTimer = timer
            timer.resume()
        }

        private func endBackgroundTaskForRegister() {
            backtaskTimer?.cancel()
            backtaskTimer = nil
            if backtaskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(backtaskIdentifier)
                backtaskIdentifier = .invalid
            }
        }


    public func willEnterForeground() {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        NSLog("applicationDidEnterForeground")
        // if _enableForceBackground! {
        //     portSIPSDK.stopKeepAwake()
        // } else {
        endBackgroundRegister()
        endBackgroundTaskForRegister()
        if !_callManager.setForeground(true) {
            loginViewController.refreshRegister()
        }
        // }
        if let result = _callManager.findCallBySessionID(self.activeSessionid), result.session.videoState {
            let sendResult = self.portSIPSDK.enableSendVideoStream(toRemote: self.activeSessionid, state: true)
            print("enableSendVideoStream result: \(sendResult)")
            startSession()
//            _callManager.configureAudioSession()
        }
    }

    public override func applicationWillTerminate(_: UIApplication) {
        _callManager.setForeground(false)
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
        let sessionInfo = getCurrentSessionInfo()
        sendCustomMessage(callSessionId: sessionInfo.0, userExtension: sessionInfo.1, type: "call_state", payloadKey: "incoming", payloadValue: true)
        sendCallStateToFlutter(.INCOMING)
        self.endBackgroundTaskForRegister()
        self.activeSessionid = sessionId
        self.activeSessionidHasVideo = existsVideo
        self.activeSessionidHasAudio = existsAudio
        let num = _callManager.getConnectCallNum()
        let index = findIdleLine()
        // if num >= MAX_LINES || index < 0 {
        //     portSIPSDK.rejectCall(sessionId, code: 486)
        //     return
        // }
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
            sessionid: sessionId, existsVideo: true, remoteParty: self.currentRemoteName,
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
            useFrontCamera: mUseFrontCamera,
            conference: self.isConference
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
            _callManager.setCallIncoming(true)
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
        NSLog("🔍 onInviteAnswered... sessionId: \(sessionId), existsVideo: \(existsVideo), callerDisplayName: \(callerDisplayName), caller: \(caller), calleeDisplayName: \(calleeDisplayName), callee: \(callee), audioCodecs: \(audioCodecs), videoCodecs: \(videoCodecs), existsAudio: \(existsAudio), existsVideo: \(existsVideo), sipMessage: \(sipMessage)")
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
                useFrontCamera: mUseFrontCamera,
                conference: self.isConference
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
        
        NSLog("onInviteAnswered... isConference=\(String(describing: isConference)), sessionId=\(sessionId)")

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
        setLoudspeakerStatus(true)

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

            let sendResult = self.portSIPSDK.enableSendVideoStream(toRemote: sessionId, state: true)
            print("enableSendVideoStream result: \(sendResult)")
            startSession()
        }
        
        if existsAudio {
            let audioStrCallBack = portSIPSDK.enableAudioStreamCallback(
                sessionId, enable: true, callbackMode: DIRECTION_RECV)
            print("enableVideoStreamCallback result: \(audioStrCallBack)")
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

//             let updateRes = portSIPSDK.updateCall(
//                 result.session.sessionId, enableAudio: true, enableVideo: true)
//             NSLog("onInviteUpdated - re-updateCall: \(updateRes)")
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
            useFrontCamera: mUseFrontCamera,
            conference: self.isConference
        )
        PortSIPStateManager.shared.updateVideoState(videoState)

        // 🔥 NEW: Send call state UPDATED notification
        let callState = PortSIPCallState(
            sessionId: Int64(sessionId),
            hasVideo: existsVideo,
            hasAudio: existsAudio,
            isIncoming: !result.session.recvCallState,
            remoteParty: nil,
            remoteDisplayName: nil,
            state: .updated
        )
        PortSIPStateManager.shared.updateCallState(callState)

        // // Legacy Flutter state (keep for compatibility)
        // sendCallStateToFlutter(.UPDATED)

        NSLog("onInviteUpdated - COMPLETE: The call has been updated on line \(result.index)")
    }

    public func onInviteConnected(_ sessionId: Int) {
        NSLog("onInviteConnected - sessionId: \(sessionId)")
        guard let result = _callManager.findCallBySessionID(sessionId) else {
            return
        }

        print("The call is connected on line \(findSession(sessionid: sessionId))")
        // REMOVED: mUseFrontCamera = true  // ❌ Don't force reset camera setting
        
        let sessionInfo = getCurrentSessionInfo()
//        sendCustomMessage(
//            callSessionId: sessionInfo.0, userExtension: sessionInfo.1,
//            type: "call_state", payloadKey: "answered", payloadValue: true)
        
        setLoudspeakerStatus(true)

        // 🔥 ANDROID PATTERN: Send state notification instead of direct call
        if result.session.videoState {
            NSLog("⭐️ Call is connected with video - sending state notification")
            let videoState = PortSIPVideoState(
                sessionId: Int64(sessionId),
                isVideoEnabled: true,
                isCameraOn: !result.session.videoMuted,
                useFrontCamera: mUseFrontCamera,
                conference: self.isConference
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
        setLoudspeakerStatus(true)

        if activeSessionid == sessionId {
            activeSessionid = CLong(INVALID_SESSION_ID)
        }

        //       // Gửi trạng thái về Flutter
        //       sendCallStateToFlutter(.CLOSED)
        methodChannel?.invokeMethod("callType", arguments: "ENDED")
        methodChannel?.invokeMethod("isRemoteVideoReceived", arguments: false)
        self.isRemoteVideoReceived = false
        self.mUseFrontCamera = true
        _callManager.setCallIncoming(false)
        stopSession()
    }

    public func onDialogStateUpdated(
        _ BLFMonitoredUri: String!, blfDialogState BLFDialogState: String!,
        blfDialogId BLFDialogId: String!, blfDialogDirection BLFDialogDirection: String!
    ) {
        print("onDialogStateUpdated - BLFMonitoredUri: \(BLFMonitoredUri!), BLFDialogState: \(BLFDialogState!), BLFDialogId: \(BLFDialogId!), BLFDialogDirection: \(BLFDialogDirection!)")
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
        NSLog("onRecvMessage... sessionId = \(sessionId), mimeType = \(mimeType) subMimeType = \(subMimeType)")
        let index = findSession(sessionid: sessionId)
        if index == -1 {
            return
        }

        if mimeType == "text", subMimeType == "plain" {
            let recvMessage =
                String(
                    data: Data(bytes: messageData, count: Int(messageDataLength)), encoding: .utf8)
                ?? ""
            NSLog("onRecvMessage... Received plain message: \(recvMessage)")

            // Gửi tin nhắn về Flutter với sessionId
            let messageData: [String: Any] = [
                "sipSessionId": sessionId,
                "message": recvMessage
            ]
            methodChannel?.invokeMethod("recvCallMessage", arguments: messageData)
        } else if mimeType == "application", subMimeType == "vnd.3gpp.sms" {
            // The messageData is binary data
            let recvMessage =
                String(
                    data: Data(bytes: messageData, count: Int(messageDataLength)), encoding: .utf8)
                ?? ""
            NSLog("onRecvMessage... Received 3GPP SMS: \(recvMessage)")
            let messageData: [String: Any] = [
                "sipSessionId": sessionId,
                "message": recvMessage
            ]
            methodChannel?.invokeMethod("recvCallMessage", arguments: messageData)
        } else if mimeType == "application", subMimeType == "vnd.3gpp2.sms" {
            // The messageData is binary data
            let recvMessage =
                String(
                    data: Data(bytes: messageData, count: Int(messageDataLength)), encoding: .utf8)
                ?? ""
            NSLog("onRecvMessage... Received 3GPP2 SMS: \(recvMessage)")
            let messageData: [String: Any] = [
                "sipSessionId": sessionId,
                "message": recvMessage
            ]
            methodChannel?.invokeMethod("recvCallMessage", arguments: messageData)
        } else if mimeType == "application", subMimeType == "json" {
            let recvMessage = 
                String(
                    data: Data(bytes: messageData, count: Int(messageDataLength)), encoding: .utf8)
                ?? ""
            NSLog("onRecvMessage... Received json SMS: \(recvMessage)")
            let messageData: [String: Any] = [
                "sipSessionId": sessionId,
                "message": recvMessage
            ]
            methodChannel?.invokeMethod("recvCallMessage", arguments: messageData)
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
//        print("onAudioRawCallback - dataLength \(dataLength)")
    }

    // Optimized video processing queue
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: "com.mpt.videoSession")
    private var sessionIsStarted = false
    
    public func onVideoRawCallback(
        _: Int, videoCallbackMode : Int32, width : Int32, height : Int32,
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

//        print("Total data length: \(dataLength) bytes")
        if self.isRemoteVideoReceived == false {
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
        NSLog("makeCall... activeSessionid=\(activeSessionid)")
        
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            NSLog("makeCall... Current line is busy \(activeSessionid)")
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

    func hangUpCall() -> Int32 {
        NSLog("hangUpCall")
        methodChannel?.invokeMethod("isRemoteVideoReceived", arguments: false)
        self.isRemoteVideoReceived = false

        var statusCode: Int32 = -1

        if activeSessionid != CLong(INVALID_SESSION_ID) {
            _ = mSoundService.stopRingTone()
            _ = mSoundService.stopRingBackTone()

            // Use CallManager.endCall which returns proper status codes
            statusCode = _callManager.endCall(sessionid: activeSessionid)
            _callManager.setCallIncoming(false)
            stopSession()
            NSLog("hangUpCall - endCall result: \(statusCode)")
        } else {
            statusCode = -2 // No active session
            NSLog("hangUpCall - No active session")
        }

        return statusCode
    }
    
    func hangUpAllCalls(){
        _callManager.hangUpAllCalls()
        self.isConference = false
        
        self.activeSessionid = CLong(INVALID_SESSION_ID)
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
            let setLoudRes = portSIPSDK.setLoudspeakerStatus(enable)
            print("setLoudspeakerStatus status code: \(setLoudRes) - enable: \(enable)")
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
        NSLog("didSelectLine... activeSessionid=\(activeSessionid)")

        if !isConference && activeSessionid != CLong(INVALID_SESSION_ID) {
            _callManager.holdCall(sessionid: activeSessionid, onHold: false)
        }
    }
    
    func autoSelectAvailableLine()-> CLong{
        var selectedLine = -1;
        
        for i in 0..<MAX_LINES {
            if lineSessions[i] == CLong(INVALID_SESSION_ID) {
                selectedLine = i
                print("autoSelectAvailableLine, selectedLine=\(i)")
                break
            }
        }
        
        return selectedLine
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
            useFrontCamera: mUseFrontCamera,
            conference: self.isConference
        )
        PortSIPStateManager.shared.updateVideoState(videoState)

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
            _callManager.configureAudioSession()
            setLoudspeakerStatus(true)
            
            if _callManager.isHideCallkit{
                _callManager.reportOutgoingCall(number: self.currentRemoteName, uuid: self.currentUUID!)
            }

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
                useFrontCamera: mUseFrontCamera,
                conference: self.isConference
            )
            PortSIPStateManager.shared.updateVideoState(videoState)

            // Set camera for local video
            setCamera(useFrontCamera: mUseFrontCamera)

            let line = findSession(sessionid: sessionId)
            if line >= 0 {
                didSelectLine(line)
            }
            
            // Send call state message with multiple fields in payload
            let sessionInfo = getCurrentSessionInfo()
            let agentInfo: [String: Any] = [
                "agentId": self.currentAgentId,
                "tenantId": self.currentTenantId
            ]
            let payload: [String: Any] = [
                "answered": true,
                "agentInfo": agentInfo,
                "existsVideo": self.activeSessionidHasVideo ?? false,
                "existsAudio": self.activeSessionidHasAudio ?? false
            ]
            sendCallStateMsg(
                callSessionId: sessionInfo.0, 
                userExtension: sessionInfo.1, 
                type: "call_state", 
                payload: payload)

            sendCallStateToFlutter(.ANSWERED)
        }

        _ = mSoundService.stopRingTone()
        _ = mSoundService.stopRingBackTone()

        if activeSessionid == CLong(INVALID_SESSION_ID) {
            activeSessionid = sessionId
        }
    }

    func onCloseCall(sessionId: CLong) {
        NSLog("onCloseCall... sessionId=\(sessionId)")
        freeLine(sessionid: sessionId)
        _callManager.setCallIncoming(false)
        stopSession()

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

        if _callManager.getConnectCallNum() == 0 {
            setLoudspeakerStatus(true)
        }
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
            conferenceVideoWindow: conferenceVideoWindow, videoWidth: 480, videoHeight: 720,
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
        case "enableFileLogging":
            guard let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing 'enabled'", details: nil))
                return
            }
            if enabled {
                guard let filePath = args["filePath"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing 'filePath' when enabling", details: nil))
                    return
                }
                if redirectStdoutStderr(toFileAtPath: filePath) {
                    result(true)
                } else {
                    result(FlutterError(code: "LOGGING_ERROR", message: "Failed to redirect stdout/stderr", details: nil))
                }
            } else {
                if restoreStdoutStderr() {
                    result(true)
                } else {
                    result(FlutterError(code: "LOGGING_ERROR", message: "Failed to restore stdout/stderr", details: nil))
                }
            }
            return
        case "openAppSetting":
            openAppSettings()
            result(true)
        case "appKilled":
            print("appKilled called!")
            self.loginViewController.offLine()
            let appKilledHangupResult = _callManager.endCall(sessionid: activeSessionid)
            NSLog("appKilled hangup result: \(appKilledHangupResult)")
            result(true)
        case "requestPermission":
            // Check current permission status first
            let currentVideoStatus = AVCaptureDevice.authorizationStatus(for: .video)
            let currentAudioStatus = AVAudioSession.sharedInstance().recordPermission
            
            if currentVideoStatus == .authorized && currentAudioStatus == .granted {
                result(true)
                return
            }
            
            AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                if videoGranted {
                    AVAudioSession.sharedInstance().requestRecordPermission { audioGranted in
                        DispatchQueue.main.async {
                            result(audioGranted)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        result(false)
                    }
                }
            }
        case "initialize":
            if let args = call.arguments as? [String: Any] {
                if let recordLabel = args["recordLabel"] as? String {
                    MptCallkitPlugin.overlayText = recordLabel
                }
                if let enableBlurBackground = args["enableBlurBackground"] as? Bool {
                    MptCallkitPlugin.enableBlurBackground = enableBlurBackground
                }
                if let bgPath = args["bgPath"] as? String {
                    if !bgPath.isEmpty && self.bgPath != bgPath{
                        self.bgPath = bgPath
                        loadBackgroundImage()
                    }
                }
                print("onMethodCall MptCallkitPlugin.enableBlurBackground: \(MptCallkitPlugin.enableBlurBackground), bgPath: \(String(describing: bgPath))")
            }
            result(true)

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
                // video params with defaults
                let resolution = (args["resolution"] as? String) ?? "720P"
                let bitrate = (args["bitrate"] as? Int) ?? 1024
                let frameRate = (args["frameRate"] as? Int) ?? 30
                let recordLabel = (args["recordLabel"] as? String) ?? "Customer"
                let autoLogin = (args["autoLogin"] as? Bool) ?? false
                let enableBlur = (args["enableBlurBackground"] as? Bool) ?? false
                let backgroundPath = (args["bgPath"] as? String) ?? nil
                let agentId = (args["agentId"] as? Int32) ?? -1
                let tenantId = (args["tenantId"] as? Int32) ?? -1

                // Lưu username hiện tại
                currentUsername = username
                self.currentAgentId = agentId
                self.currentTenantId = tenantId
                MptCallkitPlugin.overlayText = recordLabel
                MptCallkitPlugin.enableBlurBackground = enableBlur
                
                if (backgroundPath != nil) {
                    // Set background path and load background image
                    bgPath = backgroundPath
                    loadBackgroundImage()
                }
                
                print("onMethodCall MptCallkitPlugin.overlayText: \(MptCallkitPlugin.overlayText), MptCallkitPlugin.enableBlurBackground: \(MptCallkitPlugin.enableBlurBackground), bgPath: \(String(describing: bgPath))")

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
                    enableDebugLog: enableDebugLog,
                    resolution: resolution,
                    bitrate: bitrate,
                    frameRate: frameRate
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
                let destination = args["destination"] as? String,
                let isVideoCall = args["isVideoCall"] as? Bool
            {

                // Kiểm tra trạng thái đăng ký trước khi thực hiện cuộc gọi
                if loginViewController.sipRegistrationStatus == .LOGIN_STATUS_ONLINE {
                    // Sử dụng hàm makeCall có sẵn trong plugin
                    let sessionId = makeCall(destination, videoCall: isVideoCall)
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
                if disablePushNoti == true {
                    // clear all shared preferences
                    UserDefaults.standard.removeObject(forKey: "username")
                    UserDefaults.standard.removeObject(forKey: "displayName")
                    UserDefaults.standard.removeObject(forKey: "authName")
                    UserDefaults.standard.removeObject(forKey: "password")
                    UserDefaults.standard.removeObject(forKey: "userDomain")
                    UserDefaults.standard.removeObject(forKey: "sipServer")
                    UserDefaults.standard.removeObject(forKey: "sipServerPort")
                    UserDefaults.standard.removeObject(forKey: "transportType")
                    UserDefaults.standard.removeObject(forKey: "srtpType")
                    UserDefaults.standard.removeObject(forKey: "enableDebugLog")
                    UserDefaults.standard.removeObject(forKey: "resolution")
                    UserDefaults.standard.removeObject(forKey: "bitrate")
                    UserDefaults.standard.removeObject(forKey: "frameRate")
                    UserDefaults.standard.removeObject(forKey: "recordLabel")
                    UserDefaults.standard.removeObject(forKey: "autoLogin")
                    UserDefaults.standard.removeObject(forKey: "enableBlurBackground")
                    UserDefaults.standard.removeObject(forKey: "bgPath")
                    UserDefaults.standard.synchronize()
                }
            }
            
            self.loginViewController.offLine()
            result(true)
        case "hangup":
            let hangupResult = hangUpCall()
            result(hangupResult)
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
            let ansr = answerCall(isAutoAnswer: false)
            result(ansr)
        case "socketStatus":
            if let args = call.arguments as? [String: Any], let ready = args["ready"] as? Bool {
                _callManager.updateSocketReady(ready)
                result(true)
            } else if let ready = call.arguments as? Bool {
                _callManager.updateSocketReady(ready)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected {ready: Bool} or Bool for socketStatus", details: nil))
            }
        case "reject":
            let rejectResult = hangUpCall()
            result(rejectResult)
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
                
//                let sendVideoRes = portSIPSDK.sendVideo(
//                    sessionResult.session.sessionId, sendState: isVideo)
//                NSLog("🔍 updateVideoCall - sendVideo(\(isVideo)): \(sendVideoRes)")

                // Update call to add video stream
                let updateRes = portSIPSDK.updateCall(
                    sessionResult.session.sessionId, enableAudio: true, enableVideo: isVideo)
                NSLog("🔍 updateVideoCall - updateCall(audio=true, video=\(isVideo)): \(updateRes)")

                // Start capture session after SIP update to ensure it's not interfered with
                if isVideo {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let sendResult = self.portSIPSDK.enableSendVideoStream(toRemote: self.activeSessionid, state: true)
                        print("enableSendVideoStream result: \(sendResult)")
                        self.startSession()
                    }
                }

                // 🔥 SIMPLE: Just send notification, let views handle themselves
                let videoState = PortSIPVideoState(
                    sessionId: Int64(sessionResult.session.sessionId),
                    isVideoEnabled: isVideo,
                    isCameraOn: isVideo,
                    useFrontCamera: mUseFrontCamera,
                    conference: self.isConference
                )
                PortSIPStateManager.shared.updateVideoState(videoState)

                result(updateRes == 0)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing or invalid arguments for updateVideoCall", details: nil))
            }
            
        case "getCallkitAnsweredState":
            result(getCallkitAnsweredState())
            return
        case "refreshRegister":
            print("refreshRegister called")
//             loginViewController.refreshRegister()
            result(-1)
        case "refreshRegistration":
            print("refreshRegistration called")
//             loginViewController.refreshRegister()
            result(-1)
        case "setResolutionMode":
            if let args = call.arguments as? [String: Any],
               let mode = args["mode"] as? Int {
                setResolutionMode(mode)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid mode for setResolutionMode", details: nil))
            }
        case "setCustomResolution":
            if let args = call.arguments as? [String: Any],
               let width = args["width"] as? Int,
               let height = args["height"] as? Int {
                setCustomResolution(width: width, height: height)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing width or height for setCustomResolution", details: nil))
            }
        case "getResolutionMode":
            result(getResolutionMode())
        case "getCurrentResolution":
            let resolution = getCurrentResolution()
            result(["width": resolution.width, "height": resolution.height])
        case "setOverlayText":
            if let args = call.arguments as? [String: Any],
               let text = args["text"] as? String {
                setOverlayText(text)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing text for setOverlayText", details: nil))
            }
        case "getOverlayText":
            result(getOverlayText())
        case "getCurrentCallSessionId":
            result(self.currentSessionid)
        case "isInternal":
            let isInternalPayload = call.arguments as? [String: Any]
            let isInternal = isInternalPayload?["isInternal"] as? Bool
            let sessionId = isInternalPayload?["sessionId"] as? String
            let agentExtension = isInternalPayload?["extension"] as? String
            sendCustomMessage(
                callSessionId: sessionId!, userExtension: agentExtension!,
                type: "call_state", payloadKey: "isInternal", payloadValue: isInternal ?? true)
        case "conference":
            updateToConference()
            result(true)
        case "inviteToConference":
            if let args = call.arguments as? [String: Any],
                let destination = args["destination"] as? String,
                let isVideoCall = args["isVideoCall"] as? Bool
            {
                var selectedLine = autoSelectAvailableLine()
                
                if selectedLine != -1 {
                    didSelectLine(selectedLine)
                    
                    // Check reg status first
                    if loginViewController.sipRegistrationStatus == .LOGIN_STATUS_ONLINE {
                        // then make call
                        let sessionId = makeCall(destination, videoCall: isVideoCall)
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
                            code: "NO_AVAILABLE_LINE",
                            message: "No available line for inviteToConference",
                            details: nil))
                }

            }
            result(true)
        case "getConferenceState":
            result(self.isConference)
        case "sendSipMessage":
            var sendMsgRes = -1
            if let args = call.arguments as? [String: Any],
               let sipSessionId = args["sipSessionId"] as? CLong ?? self.activeSessionid,
               let message = args["message"]  as? String
            {
                sendMsgRes = self.sendSipMessage(sessionId: sipSessionId, message: message)
            }
            result(sendMsgRes)
        case "hangUpAllCalls":
            self.hangUpAllCalls()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Stdout/Stderr redirection
    private var originalStdout: Int32 = -1
    private var originalStderr: Int32 = -1
    private var logFileFd: Int32 = -1
    private var stdoutReadFd: Int32 = -1
    private var stderrReadFd: Int32 = -1
    private var stdoutSource: DispatchSourceRead?
    private var stderrSource: DispatchSourceRead?

    private func redirectStdoutStderr(toFileAtPath path: String) -> Bool {
        let fileManager = FileManager.default
        let dirPath = (path as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: dirPath) {
            do {
                try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
            } catch {
                return false
            }
        }

        if originalStdout == -1 { originalStdout = dup(fileno(stdout)) }
        if originalStderr == -1 { originalStderr = dup(fileno(stderr)) }

        // Open log file for appending
        path.withCString { cPath in
            logFileFd = open(cPath, O_CREAT | O_APPEND | O_WRONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        }
        if logFileFd == -1 { return false }

        // Create pipe for stdout
        var outPipe: [Int32] = [0, 0]
        if pipe(&outPipe) != 0 { close(logFileFd); logFileFd = -1; return false }
        stdoutReadFd = outPipe[0]
        let stdoutWriteFd = outPipe[1]
        if dup2(stdoutWriteFd, fileno(stdout)) == -1 { close(stdoutReadFd); close(stdoutWriteFd); close(logFileFd); logFileFd = -1; return false }
        close(stdoutWriteFd)

        // Create pipe for stderr
        var errPipe: [Int32] = [0, 0]
        if pipe(&errPipe) != 0 { restoreStdoutStderr(); return false }
        stderrReadFd = errPipe[0]
        let stderrWriteFd = errPipe[1]
        if dup2(stderrWriteFd, fileno(stderr)) == -1 { close(stderrReadFd); close(stderrWriteFd); restoreStdoutStderr(); return false }
        close(stderrWriteFd)

        // Start Dispatch sources to tee output to original and file
        let queue = DispatchQueue.global(qos: .background)

        stdoutSource = DispatchSource.makeReadSource(fileDescriptor: stdoutReadFd, queue: queue)
        stdoutSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let n = read(self.stdoutReadFd, &buffer, buffer.count)
            if n > 0 {
                let prefix = self.timestampPrefix(platform: "iOS")
                _ = write(self.originalStdout, buffer, n)
                _ = write(self.logFileFd, Array(prefix.utf8), prefix.utf8.count)
                _ = write(self.logFileFd, buffer, n)
            }
        }
        stdoutSource?.setCancelHandler { [weak self] in
            if let fd = self?.stdoutReadFd, fd != -1 { close(fd) }
            self?.stdoutReadFd = -1
        }
        stdoutSource?.resume()

        stderrSource = DispatchSource.makeReadSource(fileDescriptor: stderrReadFd, queue: queue)
        stderrSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let n = read(self.stderrReadFd, &buffer, buffer.count)
            if n > 0 {
                let prefix = self.timestampPrefix(platform: "iOS")
                _ = write(self.originalStderr, buffer, n)
                _ = write(self.logFileFd, Array(prefix.utf8), prefix.utf8.count)
                _ = write(self.logFileFd, buffer, n)
            }
        }
        stderrSource?.setCancelHandler { [weak self] in
            if let fd = self?.stderrReadFd, fd != -1 { close(fd) }
            self?.stderrReadFd = -1
        }
        stderrSource?.resume()

        return true
    }

    private func restoreStdoutStderr() -> Bool {
        var ok = true
        // Cancel sources (will close read fds via cancel handlers)
        stdoutSource?.cancel()
        stderrSource?.cancel()
        stdoutSource = nil
        stderrSource = nil

        // Restore stdout/stderr
        if originalStdout != -1 {
            if dup2(originalStdout, fileno(stdout)) == -1 { ok = false }
            close(originalStdout)
            originalStdout = -1
        }
        if originalStderr != -1 {
            if dup2(originalStderr, fileno(stderr)) == -1 { ok = false }
            close(originalStderr)
            originalStderr = -1
        }

        if logFileFd != -1 { close(logFileFd); logFileFd = -1 }
        return ok
    }

    private func timestampPrefix(platform: String) -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "ddMMyy-HHmmss.SSS"
        let ts = formatter.string(from: now)
        return "[\(ts)] [\(platform)] "
    }

    public func onRegisterSuccess(_ statusText: String!, statusCode: Int32, sipMessage: String!) {
        NSLog(
            "onRegisterSuccess Status: \(String(describing: statusText)), Message: \(String(describing: sipMessage))"
        )
        sipRegistered = true
        methodChannel?.invokeMethod("onlineStatus", arguments: true)
        methodChannel?.invokeMethod("registrationStateStream", arguments: true)
        loginViewController.sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_ONLINE
        loginViewController.onRegisterSuccess(statusText: statusText)
        NSLog("onRegisterSuccess")
    }

    public func onRegisterFailure(_ statusText: String!, statusCode: Int32, sipMessage: String!) {
        NSLog(
            "onRegisterFailure Status: \(String(describing: statusText)), Message: \(String(describing: sipMessage))"
        )
        sipRegistered = false
        methodChannel?.invokeMethod("onlineStatus", arguments: false)
        methodChannel?.invokeMethod("registrationStateStream", arguments: false)
        loginViewController.sipRegistrationStatus = LOGIN_STATUS.LOGIN_STATUS_FAILUE
        loginViewController.onRegisterFailure(statusCode: statusCode, statusText: statusText)
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
                    let sendResult = self.portSIPSDK.enableSendVideoStream(toRemote: activeSessionid, state: true)
                    print("enableSendVideoStream result: \(sendResult)")
                    startSession()
                    print("Camera turned on")
                } else {
                    // Tắt camera - chỉ mute camera chứ không disable video hoàn toàn
                    portSIPSDK.sendVideo(activeSessionid, sendState: false)
                    result!.session.videoMuted = true  // Camera muted
                    stopSession()
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
                    useFrontCamera: mUseFrontCamera,
                    conference: self.isConference
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
    func answerCall(isAutoAnswer: Bool) ->  Int32{
        NSLog("🔍 answerCall - START")
//        if activeSessionid != CLong(INVALID_SESSION_ID) {
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

                _callManager.waitSocketBeforeAnswer = !isAutoAnswer
                let answerRes = _callManager.answerCall(
                    sessionId: activeSessionid, isVideo: result?.session.videoState ?? false)

                if answerRes == 0 {
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
                    // reInvite(self.xSessionIdRecv)
                } else {
                    NSLog(
                        "❌ answerCall - Answer call failed with error code: \(String(describing: answerRes))"
                    )
                }
                
                NSLog(
                    "🔍 answerCall() - Waiting for onInviteAnswered() to send proper state notifications"
                )

                NSLog("🔍 answerCall - Call answered")
                
                return answerRes
            } else {
                return 1
                NSLog("❌ answerCall - Cannot find session for activeSessionid: \(activeSessionid)")
            }
//        } else {
//            return -1
//            NSLog("❌ answerCall - No active session - \(activeSessionid)")
//        }
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
        // Cập nhật state manager thay vì gọi trực tiếp UI
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            if let result = _callManager.findCallBySessionID(activeSessionid) {
                let callState: [String: Any] = [
                    "sessionId": activeSessionid,
                    "hasVideo": result.session.videoState,
                    "state": state.rawValue,
                ]
                // Gửi trạng thái cơ bản
                print("sendCallStateToFlutter: \(callState)")
                methodChannel?.invokeMethod("callState", arguments: callState)

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
        case .UPDATED:
            return .updated
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
                useFrontCamera: mUseFrontCamera,
                conference: self.isConference
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
        stopSession()
        // Wait for stop to complete, then start session (which will reconfigure)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let sendResult = self.portSIPSDK.enableSendVideoStream(toRemote: self.activeSessionid, state: true)
            print("enableSendVideoStream result: \(sendResult)")
            self.startSession()
        }

        // Send state notification - views will handle themselves
        let videoState = PortSIPVideoState(
            sessionId: Int64(activeSessionid),
            isVideoEnabled: true,
            isCameraOn: true,
            useFrontCamera: newUseFrontCamera,
            conference: self.isConference
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
            // let sendVideoRes = portSIPSDK.sendVideo(
            //     sessionResult.session.sessionId, sendState: true)
            // NSLog("reinviteSession - sendVideo(): \(sendVideoRes)")

            // Update call to add video stream
            let updateRes = portSIPSDK.updateCall(
                sessionResult.session.sessionId, enableAudio: true, enableVideo: true)
            NSLog("reinviteSession - updateCall(): \(updateRes)")

            // 🔥 ANDROID PATTERN: Send state notification instead of direct calls
            let videoState = PortSIPVideoState(
                sessionId: Int64(sessionResult.session.sessionId),
                isVideoEnabled: true,
                isCameraOn: true,
                useFrontCamera: mUseFrontCamera,
                conference: self.isConference
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
    
    func sendSipMessage(sessionId: Int, message: String) -> Int{
        if sessionId < 0 {
            NSLog("sendSipMessage... sessionId is invalid")
            return -1
        }
        NSLog("sendSipMessage... sendMessage message= \(message.data(using: .utf8))")
        let resSendMsg = portSIPSDK.sendMessage(
            sessionId, mimeType: "text",
            subMimeType: "plain",
            message: message.data(using: .utf8)!,
            messageLength: Int32(message.count)
        )
        NSLog("sendSipMessage... sendMessage result: \(resSendMsg)")
        return resSendMsg
    }
    
    /**
     * Gửi tin nhắn call state với nhiều key-value pairs trong payload
     * 
     * - Parameters:
     *   - callSessionId: Session ID của cuộc gọi
     *   - userExtension: Extension của user
     *   - type: Loại message (mặc định là "call_state")
     *   - payload: Dictionary chứa nhiều key-value pairs
     * 
     * Example usage:
     * ```
     * let payload: [String: Any] = [
     *     "answered": true,
     *     "microphone": false,
     *     "camera": true,
     *     "isInternal": false
     * ]
     * sendCallStateMsg(callSessionId: sessionId, userExtension: extension, type: "call_state", payload: payload)
     * ```
     */
    func sendCallStateMsg(callSessionId: String, userExtension: String, type: String, payload: [String: Any]) {
        if activeSessionid != CLong(INVALID_SESSION_ID) {
            do {
                // Tạo message object với payload chứa nhiều key-value pairs
                let message: [String: Any] = [
                    "sessionId": callSessionId,
                    "extension": userExtension,
                    "type": type,
                    "payload": payload,
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

                NSLog("SDK-iOS: Sending call state message: \(jsonString)")

                let messageData = jsonString.data(using: .utf8)!
                let resSendMsg = portSIPSDK.sendMessage(
                    activeSessionid,
                    mimeType: "text",
                    subMimeType: "plain",
                    message: messageData,
                    messageLength: Int32(messageData.count))
                NSLog("SDK-iOS: Send call state message result: \(resSendMsg)")
            } catch {
                NSLog("SDK-iOS: Error creating call state message: \(error.localizedDescription)")
            }
        } else {
            NSLog("SDK-iOS: Cannot send call state message - no active session")
        }
    }
    
    /**
     * Gửi tin nhắn call state (shorthand method với type mặc định là "call_state")
     * 
     * - Parameters:
     *   - callSessionId: Session ID của cuộc gọi
     *   - userExtension: Extension của user
     *   - payload: Dictionary chứa nhiều key-value pairs
     * 
     * Example usage:
     * ```
     * let sessionInfo = getCurrentSessionInfo()
     * let payload: [String: Any] = [
     *     "answered": true,
     *     "microphone": false,
     *     "camera": true
     * ]
     * sendCallStateMsg(callSessionId: sessionInfo.0, userExtension: sessionInfo.1, payload: payload)
     * ```
     */
    func sendCallStateMsg(callSessionId: String, userExtension: String, payload: [String: Any]) {
        sendCallStateMsg(callSessionId: callSessionId, userExtension: userExtension, type: "call_state", payload: payload)
    }

    /**
     * Helper method để lấy session ID và extension hiện tại
     */
    private func getCurrentSessionInfo() -> (String, String) {
        let sessionId = !currentSessionid.isEmpty ? currentSessionid : "empty_X_Session_Id"
        let userExtension = !currentUsername.isEmpty ? currentUsername : "unknown"
        return (sessionId, userExtension)
    }
    
    private func getCallkitAnsweredState() -> Bool{
        let sessionCall = _callManager.findCallByUUID(uuid: self.currentUUID!)
        var ret = false
        
        if (sessionCall != nil){
            ret =  sessionCall?.session.callKitAnswered == true;
        }
        else {
            ret = false;
        }
        
        print("getCallkitAnsweredState = \(ret)")
        
        return ret;
    }
    private var frameCount = 0
    // Add debug logging to verify this method is being called
    var frameLogCount = 0
  private var isProcessingFrame = false
  
  // FPS Control: 1 = process every frame, 2 = every 2nd frame, 3 = every 3rd frame, etc.
  private let frameSkipInterval =  1 // Change this to adjust FPS vs Performance balance
  
  // Dedicated queue for video processing to avoid priority inversion
  private let videoProcessingQueue = DispatchQueue(
    label: "com.mpt.videoprocessing", 
    qos: .utility,
    attributes: [],
    autoreleaseFrequency: .workItem
  )
}

extension MptCallkitPlugin : AVCaptureVideoDataOutputSampleBufferDelegate{
    
    public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    
    frameLogCount += 1
    if frameLogCount <= 5 || frameLogCount % 100 == 0 {
      print("📹 captureOutput called - frame #\(frameLogCount)")
    }
      
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("❌ Failed to get image buffer from sample buffer.")
      return
    }

    if !MptCallkitPlugin.enableBlurBackground {
        DispatchQueue.main.async(qos: .userInteractive) { [weak self] in
            self?.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
        }
      return
    }
    
    frameCount += 1
    
    // Skip processing if previous frame is still being processed
    guard !isProcessingFrame else {
      return
    }
    
    // Apply frame skip interval for FPS control
    if frameSkipInterval > 1 && frameCount % frameSkipInterval != 0 {
      return
    }
    
    // Set processing flag and use async processing
    isProcessingFrame = true
    // Use dedicated video processing queue to avoid priority inversion
    videoProcessingQueue.async { [weak self] in
        self?.processSegmentationWithMediaPipe(imageBuffer)
    }
  }

  /// Process segmentation using MediaPipe (iOS 13+ compatible)
  private func processSegmentationWithMediaPipe(_ imageBuffer: CVPixelBuffer) {
    // Ensure processing flag is reset even if function exits early
    defer {
      DispatchQueue.main.async { [weak self] in
        self?.isProcessingFrame = false
      }
    }
    
    guard let processor = mediaPipeProcessor else {
      print("❌ MediaPipe processor not available")
      return
    }
    
    processor.processSampleBuffer(imageBuffer, background: bgBitmap) { [weak self] result in
      guard let result = result else {
          DispatchQueue.main.async(qos: .userInteractive) { [weak self] in
              self?.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
          }
        return
      }
        DispatchQueue.main.async(qos: .userInteractive) { [weak self] in
            self?.updatePreviewOverlayViewWithImageBuffer(result)
        }
    }
  }

  /// Loads the background image from the specified path into bgBitmap.
  /// Supports both local file paths and internet URLs.
  private func loadBackgroundImage() {
    guard let path = bgPath, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      print("No background path specified, clearing bgBitmap")
      bgBitmap = nil
      return
    }
    
    // Check if it's a valid URL
    if isValidUrl(path) {
      print("Loading background image from URL: \(path)")
      loadImageFromUrl(path)
    } else {
      // Local file path
      do {
        // Load the background image from local file
        if let image = UIImage(contentsOfFile: path) {
          bgBitmap = image
          print("Successfully loaded background image: \(path) (size: \(image.size.width)x\(image.size.height))")
        } else {
          print("Failed to load background image from path: \(path)")
          bgBitmap = nil
        }
      } catch {
        print("Error loading background image from path: \(path), error: \(error)")
        bgBitmap = nil
      }
    }
  }
  
  /// Checks if the given string is a valid URL
  private func isValidUrl(_ string: String) -> Bool {
    guard let url = URL(string: string) else { return false }
    return url.scheme != nil && (url.scheme == "http" || url.scheme == "https")
  }
  
  /// Loads image from URL asynchronously
  private func loadImageFromUrl(_ urlString: String) {
    guard let url = URL(string: urlString) else {
      print("Invalid URL: \(urlString)")
      bgBitmap = nil
      return
    }
    
    DispatchQueue.global(qos: .background).async { [weak self] in
      do {
        let data = try Data(contentsOf: url)
        DispatchQueue.main.async {
          if let image = UIImage(data: data) {
            self?.bgBitmap = image
            print("Successfully loaded background image from URL: \(urlString) (size: \(image.size.width)x\(image.size.height))")
          } else {
            print("Failed to load background image from URL: \(urlString)")
            self?.bgBitmap = nil
          }
        }
      } catch {
        DispatchQueue.main.async {
          print("Error loading background image from URL: \(urlString), error: \(error)")
          self?.bgBitmap = nil
        }
      }
    }
  }
    
    /// Convert UIImage -> I420 contiguous Data ([Y][U][V]).
    /// Applies 180-degree rotation + horizontal flip for correct video orientation.
    /// - Parameters:
    ///   - image: The UIImage to convert
    /// - Returns: Data length = W*H + (W/2)*(H/2)*2, or nil on error.
    func convertUIImageToI420Data(_ image: UIImage) -> Data? {
        let size = image.size
        let width = Int(size.width)
        let height = Int(size.height)

        // Require even dimensions for simple 4:2:0 sampling
        guard width % 2 == 0 && height % 2 == 0 else {
            print("Width and height must be even for I420 conversion. Got: \(width)x\(height)")
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let pixelBufferSize = height * bytesPerRow

        // Allocate pixel buffer for RGBA data
        guard let pixelData = malloc(pixelBufferSize) else { return nil }
        defer { free(pixelData) }

        // Use RGBA format with proper alpha handling
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let ctx = CGContext(data: pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo) else {
            return nil
        }

        // Apply transformations for correct orientation
        // 1. Rotate 180 degrees to fix top-bottom flip
        ctx.translateBy(x: CGFloat(width), y: CGFloat(height))
        ctx.rotate(by: .pi) // 180 degrees rotation
        
        // 2. Flip horizontally to fix left-right flip (scale x by -1)
        ctx.scaleBy(x: -1.0, y: 1.0)
        ctx.translateBy(x: -CGFloat(width), y: 0)
        
        // Draw the image with correct orientation
        UIGraphicsPushContext(ctx)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        let src = pixelData.bindMemory(to: UInt8.self, capacity: pixelBufferSize)

        let ySize = width * height
        let uvWidth = width / 2
        let uvHeight = height / 2
        let uvSize = uvWidth * uvHeight
        let totalSize = ySize + uvSize * 2

        var i420 = Data(count: totalSize)
        i420.withUnsafeMutableBytes { rawPtr in
            guard let base = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

            let yPlane = base
            let uPlane = base.advanced(by: ySize)
            let vPlane = base.advanced(by: ySize + uvSize)

            // --- Fill Y plane (full resolution) - Optimized
            for yy in 0..<height {
                let rowSrc = yy * bytesPerRow
                let rowY = yy * width
                for xx in 0..<width {
                    let pixelIndex = rowSrc + xx * 4
                    // layout: RGBA with premultipliedLast + byteOrder32Big
                    let r = Int(src[pixelIndex])
                    let g = Int(src[pixelIndex + 1])
                    let b = Int(src[pixelIndex + 2])
                    let a = Int(src[pixelIndex + 3])

                    // Optimized alpha handling - avoid division when alpha is 255
                    let actualR: Int
                    let actualG: Int
                    let actualB: Int
                    
                    if a == 255 {
                        actualR = r
                        actualG = g
                        actualB = b
                    } else if a > 0 {
                        actualR = min(255, (r * 255) / a)
                        actualG = min(255, (g * 255) / a)
                        actualB = min(255, (b * 255) / a)
                    } else {
                        actualR = 0
                        actualG = 0
                        actualB = 0
                    }

                    // BT.601 limited-range conversion (video range) - Optimized
                    let yValue = (66 * actualR + 129 * actualG + 25 * actualB + 128) >> 8
                    yPlane[rowY + xx] = UInt8(max(16, min(235, yValue + 16)))
                }
            }

            // --- Fill U and V planes (4:2:0, average 2x2 block) - Optimized
            for j in 0..<uvHeight {
                let baseY = (j * 2) * bytesPerRow
                let uvRowIndex = j * uvWidth
                
                for i in 0..<uvWidth {
                    var rSum = 0, gSum = 0, bSum = 0
                    let baseX = i * 2
                    
                    // Unroll 2x2 loop for better performance
                    for dy in 0..<2 {
                        let rowOffset = baseY + dy * bytesPerRow
                        for dx in 0..<2 {
                            let pixelIndex = rowOffset + (baseX + dx) * 4
                            let r = Int(src[pixelIndex])
                            let g = Int(src[pixelIndex + 1])
                            let b = Int(src[pixelIndex + 2])
                            let a = Int(src[pixelIndex + 3])
                            
                            // Optimized alpha handling
                            if a == 255 {
                                rSum += r
                                gSum += g
                                bSum += b
                            } else if a > 0 {
                                rSum += min(255, (r * 255) / a)
                                gSum += min(255, (g * 255) / a)
                                bSum += min(255, (b * 255) / a)
                            }
                        }
                    }
                    
                    // Average the 2x2 block (divide by 4)
                    rSum >>= 2
                    gSum >>= 2
                    bSum >>= 2

                    // BT.601 limited-range U and V conversion - Optimized
                    let uVal = ((-38 * rSum - 74 * gSum + 112 * bSum + 128) >> 8) + 128
                    let vVal = ((112 * rSum - 94 * gSum - 18 * bSum + 128) >> 8) + 128

                    let uvIndex = uvRowIndex + i
                    uPlane[uvIndex] = UInt8(max(16, min(240, uVal)))
                    vPlane[uvIndex] = UInt8(max(16, min(240, vVal)))
                }
            }
        }

        return i420
    }
    
    // MARK: - Camera Resolution Management
    
    /// Sets the camera resolution mode
    func setResolutionMode(_ mode: Int) {
        guard mode >= MptCallkitPlugin.RESOLUTION_LOW && mode <= MptCallkitPlugin.RESOLUTION_AUTO else {
            NSLog("Invalid resolution mode: \(mode)")
            return
        }
        resolutionMode = mode
        updateRequestedResolution()
    }
    
    /// Gets the current resolution mode
    func getResolutionMode() -> Int {
        return resolutionMode
    }
    
    /// Sets custom resolution (overrides resolution mode)
    func setCustomResolution(width: Int, height: Int) {
        requestedWidth = width
        requestedHeight = height
        resolutionMode = -1 // Custom mode
        NSLog("Custom resolution set: \(width)x\(height)")
    }
    
    /// Updates the requested resolution based on the current resolution mode
    private func updateRequestedResolution() {
        switch resolutionMode {
        case MptCallkitPlugin.RESOLUTION_LOW:
            requestedWidth = 480
            requestedHeight = 848
        case MptCallkitPlugin.RESOLUTION_MEDIUM:
            requestedWidth = 720
            requestedHeight = 1280
        case MptCallkitPlugin.RESOLUTION_HIGH:
            requestedWidth = 720
            requestedHeight = 1280
        case MptCallkitPlugin.RESOLUTION_AUTO:
            autoSelectResolution()
        default:
            // Custom resolution - keep current values
            break
        }
        NSLog("Resolution updated: \(requestedWidth)x\(requestedHeight) (mode: \(resolutionMode))")
    }
    
    /// Automatically selects the best resolution based on device capabilities
    private func autoSelectResolution() {
        // Get screen dimensions
        let screenBounds = UIScreen.main.bounds
        let screenScale = UIScreen.main.scale
        let screenWidth = Int(min(screenBounds.width, screenBounds.height) * screenScale)
        let screenHeight = Int(max(screenBounds.width, screenBounds.height) * screenScale)
        
        // Get device performance indicators
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        let processorCount = processInfo.processorCount
        
        // Get device model for additional detection
        let deviceModel = getDeviceModel()
        
        // Auto-select based on device capabilities
        if isHighEndDevice(physicalMemory: physicalMemory, processorCount: processorCount, 
                          screenWidth: screenWidth, screenHeight: screenHeight, deviceModel: deviceModel) {
            // High-end device: use high resolution
            requestedWidth = 720
            requestedHeight = 1280
            NSLog("Auto-selected HIGH resolution for high-end device (\(deviceModel))")
        } else if isMidRangeDevice(physicalMemory: physicalMemory, processorCount: processorCount,
                                 screenWidth: screenWidth, screenHeight: screenHeight, deviceModel: deviceModel) {
            // Mid-range device: use medium resolution
            requestedWidth = 720
            requestedHeight = 1280
            NSLog("Auto-selected MEDIUM resolution for mid-range device (\(deviceModel))")
        } else {
            // Low-end device: use low resolution
            requestedWidth = 480    
            requestedHeight = 848
            NSLog("Auto-selected LOW resolution for low-end device (\(deviceModel))")
        }
        
        // Adjust for screen size if needed
        adjustForScreenSize(screenWidth: screenWidth, screenHeight: screenHeight)
    }
    
    /// Determines if the device is high-end based on hardware specs
    private func isHighEndDevice(physicalMemory: UInt64, processorCount: Int, 
                                screenWidth: Int, screenHeight: Int, deviceModel: String) -> Bool {
        // Memory check: > 3GB RAM
        let memoryGB = physicalMemory / (1024 * 1024 * 1024)
        
        // Check for known high-end device models (iPhone 12 Pro and newer, iPad Pro, etc.)
        let highEndModels = ["iPhone13", "iPhone14", "iPhone15", "iPhone16", "iPad13", "iPad14"]
        let isHighEndModel = highEndModels.contains { deviceModel.contains($0) }
        
        return memoryGB > 3 &&                    // > 3GB RAM
               processorCount >= 6 &&             // >= 6 CPU cores  
               screenWidth >= 1080 &&             // >= 1080p screen
               (isHighEndModel || memoryGB >= 6)  // High-end model or >= 6GB RAM
    }
    
    /// Determines if the device is mid-range based on hardware specs
    private func isMidRangeDevice(physicalMemory: UInt64, processorCount: Int,
                                 screenWidth: Int, screenHeight: Int, deviceModel: String) -> Bool {
        let memoryGB = physicalMemory / (1024 * 1024 * 1024)
        
        // Check for known mid-range device models (iPhone X and newer, regular iPads)
        let midRangeModels = ["iPhone10", "iPhone11", "iPhone12", "iPad11", "iPad12"]
        let isMidRangeModel = midRangeModels.contains { deviceModel.contains($0) }
        
        return memoryGB > 2 &&                    // > 2GB RAM
               processorCount >= 4 &&             // >= 4 CPU cores
               screenWidth >= 720 &&              // >= 720p screen
               (isMidRangeModel || memoryGB >= 3) // Mid-range model or >= 3GB RAM
    }
    
    /// Adjusts resolution based on screen size to avoid unnecessary upscaling
    private func adjustForScreenSize(screenWidth: Int, screenHeight: Int) {
        // Don't use resolution higher than screen resolution
        if requestedWidth > screenWidth {
            let ratio = Double(screenWidth) / Double(requestedWidth)
            requestedWidth = screenWidth
            requestedHeight = Int(Double(requestedHeight) * ratio)
            NSLog("Adjusted resolution for screen size: \(requestedWidth)x\(requestedHeight)")
        }
    }
    
    /// Gets the device model string for device-specific optimizations
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    /// Gets the current requested resolution as a tuple
    func getCurrentResolution() -> (width: Int, height: Int) {
        return (width: requestedWidth, height: requestedHeight)
    }
    
    /// Sets the overlay text for segmentation (matching Android SegmenterProcessor)
    func setOverlayText(_ text: String) {
        MptCallkitPlugin.overlayText = text
        NSLog("Overlay text set to: \(text)")
    }
    
    /// Gets the current overlay text
    func getOverlayText() -> String {
        return MptCallkitPlugin.overlayText
    }
    
    /// Gets the optimal AVCaptureSession preset based on requested resolution
    private func getOptimalSessionPreset() -> AVCaptureSession.Preset {
        // Map resolution to appropriate AVCaptureSession preset
        if requestedHeight >= 1920 {
//            if #available(iOS 9.0, *) {
//                return .hd1920x1080
//            } else {
//                return .high
//            }
            return .hd1280x720
        } else if requestedHeight >= 1280 {
            return .hd1280x720
        } else if requestedHeight >= 640 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// Draws black text at the top center of the image (matching Android SegmenterProcessor logic)
    /// This method replicates the exact behavior of Android's Canvas.drawText() with:
    /// - Black color (Color.BLACK)
    /// - Bold font (Typeface.DEFAULT_BOLD) 
    /// - Size 48 (textSize = 48)
    /// - Top center positioning (x = width/2, y = textBounds.height() + 100)
    private func drawTextOnImage(_ image: UIImage, text: String) -> UIImage? {
        // if text is empty, return image
        if text.isEmpty {
            return image
        }
//        print("drawTextOnImage \(drawTextOnImage)")
        let imageSize = image.size
        
        // Create graphics context with same size as image
        UIGraphicsBeginImageContextWithOptions(imageSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        // Draw the original image
        image.draw(in: CGRect(origin: .zero, size: imageSize))
        
        // Configure text attributes (matching Android settings)
        // Calculate font size based on screen width (responsive sizing) - matching Android logic
        let fontSize: CGFloat = imageSize.width * 0.05 // 5% of screen width, adjust multiplier as needed
        let font = UIFont.boldSystemFont(ofSize: fontSize) // Matching Android Typeface.DEFAULT_BOLD
        let textColor = UIColor.black // Matching Android Color.BLACK
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        // Calculate text size for positioning
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.boundingRect(
            with: CGSize(width: imageSize.width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        // Position text at top center (matching Android logic)
        let x = (imageSize.width - textSize.width) / 2.0 // Center horizontally
        let y = textSize.height + imageSize.height * 0.01 // Top with margin (matching Android y = textBounds.height() + 100)
        let textRect = CGRect(x: x, y: y, width: textSize.width, height: textSize.height)
        
        // Draw the text
        attributedText.draw(in: textRect)
        
        // Get the final image with text
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Apply orientation transformation to a UIImage to match camera output
    /// - Parameters:
    ///   - image: The input image to transform
    ///   - orientation: The target orientation (e.g., .leftMirrored for front camera)
    /// - Returns: Transformed UIImage
    private func applyOrientationToImage(_ image: UIImage, orientation: UIImage.Orientation) -> UIImage {
        // If orientation is already correct, return as-is
        if image.imageOrientation == orientation {
            return image
        }
        
        // Create new image with the desired orientation
        guard let cgImage = image.cgImage else {
            return image
        }
        
        // Return new UIImage with updated orientation
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation)
    }

    private func updateToConference() {
        guard let result = _callManager.findCallBySessionID(activeSessionid) else {
            NSLog("updateToConference - Not exist this SessionId = \(activeSessionid)")
            return
        }
        
        if !isConference {
            let videoState = PortSIPVideoState(
                sessionId: Int64(activeSessionid),
                isVideoEnabled: result.session.videoState,
                isCameraOn: result.session.videoState && !result.session.videoMuted,
                useFrontCamera: mUseFrontCamera,
                conference: true
            )
            PortSIPStateManager.shared.updateVideoState(videoState)
        }else {
            let videoState = PortSIPVideoState(
                sessionId: Int64(activeSessionid),
                isVideoEnabled: result.session.videoState,
                isCameraOn: result.session.videoState && !result.session.videoMuted,
                useFrontCamera: mUseFrontCamera,
                conference: false
            )
            PortSIPStateManager.shared.updateVideoState(videoState)
        }
    }
}


