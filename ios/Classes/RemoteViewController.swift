import UIKit
import PortSIPVoIPSDK


class RemoteViewController: UIViewController {
   var sessionId: Int = 0
   var viewRemoteVideo: PortSIPVideoRenderView!
   var portSIPSDK: PortSIPSDK!
   var isVideoInitialized: Bool = false
   var isStartVideo: Bool = false
   var contentModeTimer: Timer?
   var isConferenceMode: Bool = false
  
   override func viewDidLoad() {
       super.viewDidLoad()
       print("RemoteViewController - viewDidLoad")
       setupRemoteVideoView()
       setupNotificationObservers()
   }
  
   private func setupNotificationObservers() {
       NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleCallStateChange(_:)),
           name: .portSIPCallAnswered,
           object: nil
       )
      
       NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleCallStateChange(_:)),
           name: .portSIPCallConnected,
           object: nil
       )
      
       NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleCallStateChange(_:)),
           name: .portSIPCallClosed,
           object: nil
       )
      
       // 🔥 FIX: Add missing notification for UPDATED state
       NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleCallStateChange(_:)),
           name: .portSIPCallUpdated,
           object: nil
       )
      
       NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleVideoStateChange(_:)),
           name: .portSIPVideoStateChanged,
           object: nil
       )
   }
  
   @objc private func handleCallStateChange(_ notification: Notification) {
       guard let userInfo = notification.userInfo,
             let sessionIdInt64 = userInfo["sessionId"] as? Int64,
             let hasVideo = userInfo["hasVideo"] as? Bool,
             let state = userInfo["state"] as? String else {
           return
       }
      
       let sessionId = Int(sessionIdInt64)
       print("RemoteViewController - Call state changed: \(state), hasVideo: \(hasVideo), sessionId: \(sessionId)")
      
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
          
                  switch state {
       case "INCOMING":
           // 🔥 FIX: Prepare remote video for incoming video calls but don't show yet
           if hasVideo {
               NSLog("RemoteViewController - Incoming video call, preparing remote video")
               if !self.isVideoInitialized {
                   self.initializeRemoteVideo()
               }
               // Don't show remote video until call is answered/connected
               self.updateVideoVisibility(isVisible: true)
           } else {
               self.updateVideoVisibility(isVisible: true)
           }
       case "ANSWERED", "CONNECTED", "UPDATED":
           if hasVideo {
               if !self.isVideoInitialized {
                   self.initializeRemoteVideo()
               }
               self.onStartVideo(sessionId)
               self.updateVideoVisibility(isVisible: true)
           } else {
               self.updateVideoVisibility(isVisible: true)
           }
       case "CLOSED", "FAILED":
           self.updateVideoVisibility(isVisible: false)
           self.cleanupVideo()
       default:
           break
       }
       }
   }
  
   @objc private func handleVideoStateChange(_ notification: Notification) {
       guard let userInfo = notification.userInfo,
             let sessionIdInt64 = userInfo["sessionId"] as? Int64,
             let isVideoEnabled = userInfo["isVideoEnabled"] as? Bool,
             let isCameraOn = userInfo["isCameraOn"] as? Bool else {
           return
       }
      
       let sessionId = Int(sessionIdInt64)
       let isConference = userInfo["conference"] as? Bool ?? false
       
       print("RemoteViewController - Video state changed: enabled=\(isVideoEnabled), camera=\(isCameraOn), conference=\(isConference), sessionId: \(sessionId)")
      
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
          
           // Handle conference mode change
           self.handleConferenceModeChange(isConference: isConference)
          
           if isVideoEnabled {
               if !self.isVideoInitialized {
                   self.initializeRemoteVideo()
               }
               self.onStartVideo(sessionId)
              
               // Cập nhật hiển thị dựa trên camera state
               self.updateRemoteVideoDisplay(hasCameraOn: isCameraOn)
           } else {
               // Khi video bị disable hoàn toàn thì ẩn view
               self.updateVideoVisibility(isVisible: false)
           }
       }
   }

   /// Handles conference mode changes (switching between normal call and conference call)
   private func handleConferenceModeChange(isConference: Bool) {
       guard isConferenceMode != isConference else {
           print("RemoteViewController - same action")
           return
       }
      
       print("RemoteViewController - Conference mode changed from \(isConferenceMode) to \(isConference)")
       isConferenceMode = isConference
       // Get the SDK instance from the plugin
       let appDelegate = MptCallkitPlugin.shared
       let sessionId = appDelegate.activeSessionid ?? 0
      
       if isConference {
           // Entered conference mode
           print("RemoteViewController - Entering CONFERENCE mode")
           appDelegate.createConference(viewRemoteVideo)
           
       } else {
           // Exited conference mode (back to normal call)
           print("RemoteViewController - Exiting CONFERENCE mode (back to normal)")
           appDelegate.destoryConference(viewRemoteVideo)
           portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: viewRemoteVideo)
       }
   }
    
   private func updateRemoteVideoDisplay(hasCameraOn: Bool) {
       guard let remoteVideo = viewRemoteVideo else {
           return
       }
      
       DispatchQueue.main.async {
           if hasCameraOn {
               // Remote camera bật - hiển thị video bình thường
               remoteVideo.isHidden = false
               remoteVideo.backgroundColor = UIColor.clear
               self.removeCameraOffPlaceholder() // Xóa placeholder khi camera bật
               print("[Debug] RemoteViewController - Remote camera ON - showing video")
           } else {
               // Remote camera tắt - hiển thị placeholder thay vì ẩn view
               remoteVideo.isHidden = false
               remoteVideo.backgroundColor = UIColor.darkGray
               print("[Debug] RemoteViewController - Remote camera OFF - showing placeholder")
              
//               // Hiển thị placeholder báo camera đã tắt
//               self.showCameraOffPlaceholder()
           }
       }
   }
  
   private func showCameraOffPlaceholder() {
       guard let remoteVideo = viewRemoteVideo else { return }
      
       DispatchQueue.main.async {
           // Remove existing placeholder nếu có
           self.removeCameraOffPlaceholder()
          
           // Tạo placeholder label
           let placeholderLabel = UILabel()
           placeholderLabel.text = "Remote Camera Off"
           placeholderLabel.textColor = UIColor.white
           placeholderLabel.textAlignment = .center
           placeholderLabel.backgroundColor = UIColor.clear
           placeholderLabel.tag = 999
           placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
          
           remoteVideo.addSubview(placeholderLabel)
          
           // Center placeholder
           NSLayoutConstraint.activate([
               placeholderLabel.centerXAnchor.constraint(equalTo: remoteVideo.centerXAnchor),
               placeholderLabel.centerYAnchor.constraint(equalTo: remoteVideo.centerYAnchor)
           ])
       }
   }
  
   private func removeCameraOffPlaceholder() {
       guard let remoteVideo = viewRemoteVideo else { return }
      
       DispatchQueue.main.async {
           // Remove existing placeholder nếu có
           remoteVideo.subviews.forEach { view in
               if view.tag == 999 { // Tag để identify placeholder
                   view.removeFromSuperview()
               }
           }
       }
   }
  
   override func viewWillAppear(_ animated: Bool) {
       super.viewWillAppear(animated)
       print("RemoteViewController - viewWillAppear")
       if !isVideoInitialized {
           initializeRemoteVideo()
       }
   }
  
   override func viewDidAppear(_ animated: Bool) {
       super.viewDidAppear(animated)
       print("RemoteViewController - viewDidAppear")
       
       // Ready notification removed - views manage themselves via state manager
   }
  
   override func viewDidDisappear(_ animated: Bool) {
       super.viewDidDisappear(animated)
       print("RemoteViewController - viewDidDisappear")
       cleanupVideo()
   }
  
   deinit {
       NotificationCenter.default.removeObserver(self)
       print("RemoteViewController - deinit")
   }
  
   private func setupRemoteVideoView() {
       print("RemoteViewController - setupRemoteVideoView")
       // Create the remote video view
       viewRemoteVideo = PortSIPVideoRenderView()
       viewRemoteVideo.translatesAutoresizingMaskIntoConstraints = false
       viewRemoteVideo.backgroundColor = .black
       viewRemoteVideo.contentMode = .scaleAspectFill // 🔥 FIX: Hiển thị toàn bộ video không bị cắt
       viewRemoteVideo.clipsToBounds = true // Giữ clipsToBounds để không tràn ra ngoài
       
       // 🔥 DEBUG: Log video view properties
       print("RemoteViewController - Video view frame: \(viewRemoteVideo.frame)")
       print("RemoteViewController - Video view bounds: \(viewRemoteVideo.bounds)")
       print("RemoteViewController - Video view contentMode: \(viewRemoteVideo.contentMode.rawValue)")
       
       // 🔥 FIX: Override contentMode in layoutSubviews
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
           self.viewRemoteVideo.contentMode = .scaleAspectFill
           self.viewRemoteVideo.setNeedsLayout()
           self.viewRemoteVideo.layoutIfNeeded()
       }
       self.view.addSubview(viewRemoteVideo)
      
       // Đặt constraints để lấp đầy toàn bộ view controller (không dùng safeArea)
       // Nhưng tôn trọng kích thước của Flutter widget
       NSLayoutConstraint.activate([
           viewRemoteVideo.topAnchor.constraint(equalTo: view.topAnchor),
           viewRemoteVideo.bottomAnchor.constraint(equalTo: view.bottomAnchor),
           viewRemoteVideo.leadingAnchor.constraint(equalTo: view.leadingAnchor),
           viewRemoteVideo.trailingAnchor.constraint(equalTo: view.trailingAnchor)
       ])
      
       // Đặt màu nền đen cho letterbox/pillarbox areas
       self.view.backgroundColor = .black
       self.view.clipsToBounds = true // 🔥 FIX: Cắt phần thừa để không bị tràn ra ngoài
   }
  
   func initializeRemoteVideo() {
       print("RemoteViewController - initializeRemoteVideo")
       // Get the SDK instance from the plugin
       let appDelegate = MptCallkitPlugin.shared
       portSIPSDK = appDelegate.portSIPSDK
       sessionId = appDelegate.activeSessionid ?? 0
      
       if portSIPSDK != nil && sessionId != 0 {
           print("RemoteViewController - Initializing video render for session \(sessionId)")
           viewRemoteVideo.initVideoRender()
           isVideoInitialized = true
          
           // 🔥 FIX: Force set contentMode after video initialization
           DispatchQueue.main.async { [weak self] in
               guard let self = self else { return }
               self.viewRemoteVideo.contentMode = .scaleAspectFill
               print("RemoteViewController - Forced contentMode to scaleAspectFill")
           }
          
           // Đảm bảo view được hiển thị
           viewRemoteVideo.isHidden = false
           self.view.isHidden = false
       } else {
           print("RemoteViewController - Error: portSIPSDK is nil or sessionId = 0")
       }
       
       self.updateVideoVisibility(isVisible: true)
       
       // 🔥 FIX: Start timer to continuously force contentMode
       startContentModeTimer()
   }
   
   private func startContentModeTimer() {
       contentModeTimer?.invalidate()
       contentModeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
           guard let self = self, let videoView = self.viewRemoteVideo else { return }
           if videoView.contentMode != .scaleAspectFill {
               videoView.contentMode = .scaleAspectFill
               print("RemoteViewController - Timer forced contentMode to scaleAspectFill")
           }
       }
   }
   
   private func stopContentModeTimer() {
       contentModeTimer?.invalidate()
       contentModeTimer = nil
   }
  
   func onStartVideo(_ sessionID: Int) {
       print("RemoteViewController - onStartVideo: \(sessionID)")
       DispatchQueue.main.async {
           self.isStartVideo = true
           self.sessionId = sessionID
          
           if self.isVideoInitialized {
               // Set the remote video window
               print("RemoteViewController - Setting remote video window")
               if self.isConferenceMode {
                   let result1 = self.portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: nil)
                   let result2 = self.portSIPSDK.setConferenceVideoWindow(self.viewRemoteVideo)
                   print("RemoteViewController - setRemoteVideoWindow result=\(result1) - setConferenceVideoWindow result=\(result2)")
               } else {
                   let result1 = self.portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: self.viewRemoteVideo)
                   let result2 = self.portSIPSDK.setConferenceVideoWindow(nil)
                   print("RemoteViewController - setRemoteVideoWindow result=\(result1) - setConferenceVideoWindow result=\(result2)")
               }
               // 🔥 FIX: Force set contentMode after setting video window
               self.viewRemoteVideo.contentMode = .scaleAspectFill
               print("RemoteViewController - Forced contentMode to scaleAspectFill in onStartVideo")
           } else {
               // Initialize if not already done
               print("RemoteViewController - Initializing remote video first")
               self.initializeRemoteVideo()
               if self.isConferenceMode {
                   let result1 = self.portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: nil)
                   let result2 = self.portSIPSDK.setConferenceVideoWindow(self.viewRemoteVideo)
                   print("RemoteViewController - setRemoteVideoWindow result=\(result1) - setConferenceVideoWindow result=\(result2)")
               } else {
                   let result1 = self.portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: self.viewRemoteVideo)
                   let result2 = self.portSIPSDK.setConferenceVideoWindow(nil)
                   print("RemoteViewController - setRemoteVideoWindow result=\(result1) - setConferenceVideoWindow result=\(result2)")
               }
               
               // 🔥 FIX: Force set contentMode after setting video window
               self.viewRemoteVideo.contentMode = .scaleAspectFill
               print("RemoteViewController - Forced contentMode to scaleAspectFill in onStartVideo")
           }
          
           // Đảm bảo view được hiển thị
           self.viewRemoteVideo.isHidden = false
           self.view.isHidden = false
       }
   }
  
   func onStopVideo(_ sessionID: Int) {
       print("RemoteViewController - onStopVideo: \(sessionID)")
       DispatchQueue.main.async {
           if self.sessionId == sessionID {
               self.isStartVideo = false
              
               // Clear the remote video window
               self.portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: nil)
           }
       }
   }
  
   func onSetRemoteScreenWindow(_ sessionID: Int) {
       print("RemoteViewController - onSetRemoteScreenWindow: \(sessionID)")
       DispatchQueue.main.async {
           if self.sessionId == sessionID {
               // Set remote screen window for screen sharing
               let result = self.portSIPSDK.setRemoteScreenWindow(self.sessionId, remoteScreenWindow: self.viewRemoteVideo)
               print("RemoteViewController - setRemoteScreenWindow result: \(result)")
              
               // Đảm bảo view được hiển thị
               self.viewRemoteVideo.isHidden = false
               self.view.isHidden = false
           }
       }
   }
  
   func updateVideoVisibility(isVisible: Bool) {
       print("RemoteViewController - updateVideoVisibility: \(isVisible)")
      
       // CRITICAL: Check if view controller is still valid and views are loaded
       guard isViewLoaded else {
           print("[Warning] RemoteViewController - View not loaded, ignoring video visibility update")
           return
       }
      
       // Check if we're still attached to a parent (not destroyed)
       guard parent != nil || view.superview != nil else {
           print("[Warning] RemoteViewController - View controller detached, ignoring video visibility update")
           return
       }
      
       // Check viewRemoteVideo
       guard let remoteVideo = viewRemoteVideo else {
           print("[Warning] RemoteViewController - viewRemoteVideo is nil, view may be destroyed")
           self.safeUnregisterFromNotifications()
           return
       }
      
       // Check portSIPSDK
       guard let sdk = portSIPSDK else {
           print("[Error] RemoteViewController - portSIPSDK is nil")
           return
       }
      
       // Ensure we're on main thread
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
          
           // Double-check views are still valid on main thread
           guard let remoteVideo = self.viewRemoteVideo else {
               print("[Warning] RemoteViewController - viewRemoteVideo became nil on main thread")
               return
           }
          
           // Update the visibility of the view
           remoteVideo.isHidden = !isVisible
          
           if isVisible && self.isVideoInitialized && self.sessionId != 0 {
               // Đảm bảo video được hiển thị
               let result = sdk.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: remoteVideo)
               print("RemoteViewController - setRemoteVideoWindow result: \(result)")
           } else if !isVisible && self.isVideoInitialized && self.sessionId != 0 {
               // Ẩn video
               sdk.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: nil)
           } else if isVisible && !self.isVideoInitialized {
               // Try to initialize if we need to show video
               print("[Info] RemoteViewController - Attempting to initialize video for display")
               self.initializeRemoteVideo()
               if self.sessionId != 0 {
                   let result = sdk.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: remoteVideo)
                   print("RemoteViewController - setRemoteVideoWindow after init result: \(result)")
               }
           }
       }
   }
  
   private func safeUnregisterFromNotifications() {
       print("[Debug] RemoteViewController - Safely unregistering from notifications due to view destruction")
       NotificationCenter.default.removeObserver(self)
   }
  
   func cleanupVideo() {
       print("RemoteViewController - cleanupVideo")
       
       // 🔥 FIX: Stop contentMode timer
       stopContentModeTimer()
       
       if isVideoInitialized {
           if sessionId != 0 {
               portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
               portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: nil)
               portSIPSDK.setConferenceVideoWindow(nil)
           }
          
           viewRemoteVideo.releaseVideoRender()
           isVideoInitialized = false
           isStartVideo = false
       }
   }
}

