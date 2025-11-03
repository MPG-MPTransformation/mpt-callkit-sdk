import UIKit
import PortSIPVoIPSDK


class LocalViewController: UIViewController {
   var mCameraDeviceId: Int32 = 1 // 1 - FrontCamera 0 - BackCamera
   var viewLocalVideo: PortSIPVideoRenderView!
   var portSIPSDK: PortSIPSDK!
   var isVideoInitialized: Bool = false
    public lazy var previewOverlayView: UIImageView = {

        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
       previewOverlayView.clipsToBounds = true
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
      }()
    public func setImage(image: UIImage?) {
        self.previewOverlayView.image = image
    }
  
   override func viewDidLoad() {
       super.viewDidLoad()
       NSLog("LocalViewController - viewDidLoad")
       setupLocalVideoView()
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
      
       NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleCameraStateChange(_:)),
           name: .portSIPCameraStateChanged,
           object: nil
       )
   }
  
   @objc private func handleCallStateChange(_ notification: Notification) {
       guard let userInfo = notification.userInfo,
             let state = userInfo["state"] as? String else {
           return
       }
      
       NSLog("LocalViewController - Call state changed: \(state)")
      
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
          
           switch state {
           case "INCOMING", "ANSWERED", "CONNECTED", "UPDATED":
               // 🔥 SIMPLE: Always show local video for any active call
               NSLog("LocalViewController - Active call (\(state)), showing local video")
               if !self.isVideoInitialized {
                   self.initializeLocalVideo()
               }
               self.updateVideoVisibility(isVisible: true)
           case "CLOSED", "FAILED":
               self.updateVideoVisibility(isVisible: true)
               self.cleanupVideo()
           default:
               break
           }
       }
   }
  
   @objc private func handleVideoStateChange(_ notification: Notification) {
       guard let userInfo = notification.userInfo,
             let isVideoEnabled = userInfo["isVideoEnabled"] as? Bool else {
           return
       }
      
       NSLog("LocalViewController - handleVideoStateChange - video enabled: \(isVideoEnabled)")
      
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
          
           if isVideoEnabled && !self.isVideoInitialized {
               self.initializeLocalVideo()
           }
           self.updateVideoVisibility(isVisible: true)
       }
   }
  
   @objc private func handleCameraStateChange(_ notification: Notification) {
       guard let userInfo = notification.userInfo,
             let isCameraOn = userInfo["isCameraOn"] as? Bool,
             let useFrontCamera = userInfo["useFrontCamera"] as? Bool else {
           return
       }
      
       NSLog("LocalViewController - Camera state changed: on=\(isCameraOn), front=\(useFrontCamera)")
      
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
          
           if isCameraOn {
               let newCameraId: Int32 = useFrontCamera ? 1 : 0
               
               if !self.isVideoInitialized {
                   self.mCameraDeviceId = newCameraId
                   self.initializeLocalVideo()
               } else {
                   // Only update camera if it's different from current
                   if self.mCameraDeviceId != newCameraId {
                       self.mCameraDeviceId = newCameraId
                       self.setCameraDirectly(useFrontCamera: useFrontCamera)
                   }
               }
               // Hiển thị video khi camera bật
               self.updateCameraDisplay(isOn: true)
           } else {
               // Khi camera tắt, chỉ dừng video capture nhưng vẫn hiển thị view
               self.updateCameraDisplay(isOn: false)
           }
          
           // KHÔNG ẩn view khi camera tắt - chỉ cập nhật video content
           // self.updateVideoVisibility(isVisible: isCameraOn) // Bỏ dòng này
       }
   }
  
   private func updateCameraDisplay(isOn: Bool) {
       guard let sdk = portSIPSDK,
             let localVideo = viewLocalVideo else {
           return
       }
      
       DispatchQueue.main.async {
           if isOn {
               // Bật camera - hiển thị video
               let result = sdk.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
               NSLog("[Debug] LocalViewController - Enable camera display result: \(result)")
              
               // Đảm bảo view hiển thị và xóa placeholder
               localVideo.isHidden = false
               localVideo.backgroundColor = UIColor.clear
               self.removeCameraOffPlaceholder()
           } else {
               // Tắt camera - dừng video nhưng vẫn hiển thị view với background
               let result = sdk.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
               NSLog("[Debug] LocalViewController - Disable camera display result: \(result)")
              
               // Vẫn hiển thị view nhưng với background thay vì video
               localVideo.isHidden = false
               localVideo.backgroundColor = UIColor.darkGray
              
//               // Hiển thị placeholder báo camera tắt
//               self.showCameraOffPlaceholder()
           }
       }
   }
  
   private func showCameraOffPlaceholder() {
       guard let localVideo = viewLocalVideo else { return }
      
       DispatchQueue.main.async {
           // Remove existing placeholder nếu có
           self.removeCameraOffPlaceholder()
          
           // Tạo placeholder label
           let placeholderLabel = UILabel()
           placeholderLabel.text = "Camera Off"
           placeholderLabel.textColor = UIColor.white
           placeholderLabel.textAlignment = .center
           placeholderLabel.backgroundColor = UIColor.clear
           placeholderLabel.tag = 998 // Tag để identify placeholder cho local view
           placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
          
           localVideo.addSubview(placeholderLabel)
          
           // Center placeholder
           NSLayoutConstraint.activate([
               placeholderLabel.centerXAnchor.constraint(equalTo: localVideo.centerXAnchor),
               placeholderLabel.centerYAnchor.constraint(equalTo: localVideo.centerYAnchor)
           ])
       }
   }
  
   private func removeCameraOffPlaceholder() {
       guard let localVideo = viewLocalVideo else { return }
      
       DispatchQueue.main.async {
           // Remove existing placeholder nếu có
           localVideo.subviews.forEach { view in
               if view.tag == 998 { // Tag để identify placeholder cho local view
                   view.removeFromSuperview()
               }
           }
       }
   }
  
   override func viewWillAppear(_ animated: Bool) {
       super.viewWillAppear(animated)
       NSLog("LocalViewController - viewWillAppear")
       if !isVideoInitialized {
           NSLog("LocalViewController - viewWillAppear camera setting: \(mCameraDeviceId)")
           initializeLocalVideo()
       }
   }
  
   override func viewDidAppear(_ animated: Bool) {
       super.viewDidAppear(animated)
       NSLog("LocalViewController - viewDidAppear")
       
       // Ready notification removed - views manage themselves via state manager
   }
  
   override func viewDidDisappear(_ animated: Bool) {
       super.viewDidDisappear(animated)
       NSLog("LocalViewController - viewDidDisappear")
       cleanupVideo()
   }
  
   deinit {
       NotificationCenter.default.removeObserver(self)
       NSLog("LocalViewController - deinit")
   }
  
   private func setupLocalVideoView() {
       NSLog("LocalViewController - setupLocalVideoView")
       // Create the local video view
       viewLocalVideo = PortSIPVideoRenderView()
       viewLocalVideo.translatesAutoresizingMaskIntoConstraints = false
       viewLocalVideo.backgroundColor = .black
//       viewLocalVideo.contentMode = .scaleToFill // Sử dụng scaleAspectFill để lấp đầy view
//       viewLocalVideo.clipsToBounds = true // Cắt phần thừa để không bị tràn ra ngoài
//       self.view.addSubview(viewLocalVideo)
       self.view.addSubview(previewOverlayView)
       NSLayoutConstraint.activate([
         previewOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
         previewOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
         previewOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
         previewOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

       ])
      
       // Đặt constraints để lấp đầy toàn bộ view controller
//       NSLayoutConstraint.activate([
//           viewLocalVideo.topAnchor.constraint(equalTo: view.topAnchor),
//           viewLocalVideo.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//           viewLocalVideo.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//           viewLocalVideo.trailingAnchor.constraint(equalTo: view.trailingAnchor)
//       ])
      
       // Set a clear background for easy debugging
       self.view.backgroundColor = .black
   }
  
   func initializeLocalVideo() {
       NSLog("LocalViewController - initializeLocalVideo")
       // Get the SDK instance from the plugin
       let appDelegate = MptCallkitPlugin.shared
       portSIPSDK = appDelegate.portSIPSDK
      
       if portSIPSDK != nil {
           NSLog("LocalViewController - Initializing video render")
           viewLocalVideo.initVideoRender()
           // Display local video with mirror enabled for front camera
           let result = portSIPSDK.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
           NSLog("LocalViewController - displayLocalVideo result: \(result)")
           isVideoInitialized = true
          
           // Make sure the view is visible
           viewLocalVideo.isHidden = false
           self.view.isHidden = false
       } else {
           NSLog("LocalViewController - Error: portSIPSDK is nil")
       }
   }
  
   func switchCamera() {
       NSLog("LocalViewController - switchCamera: current device ID = \(mCameraDeviceId)")
      
       // Safety check: ensure SDK is available
       guard let sdk = portSIPSDK else {
           NSLog("LocalViewController - switchCamera failed: portSIPSDK is nil")
           return
       }
      
       // Safety check: ensure video view is available
       guard let localVideo = viewLocalVideo else {
           NSLog("LocalViewController - switchCamera failed: viewLocalVideo is nil")
           return
       }
      
       // Safety check: ensure video is initialized
       if !isVideoInitialized {
           NSLog("LocalViewController - switchCamera failed: video is not initialized")
           // Try to initialize video first
           initializeLocalVideo()
          
           // Check again after initialization
           guard isVideoInitialized else {
               NSLog("LocalViewController - switchCamera failed: unable to initialize video")
               return
           }
       }
      
       // Toggle camera ID (1 -> 0 OR 0 -> 1)
       let newCameraId: Int32 = mCameraDeviceId == 1 ? 0 : 1
      
       let setVideoResult = sdk.setVideoDeviceId(newCameraId)
       if setVideoResult == 0 {
           mCameraDeviceId = newCameraId
           // Enable mirror only for front camera (ID = 1)
           let shouldMirror = mCameraDeviceId == 1
          
           // Additional safety check before calling displayLocalVideo
           let displayResult = sdk.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
           if displayResult == 0 {
               NSLog("LocalViewController - Switched to \(shouldMirror ? "front" : "back") camera with mirror \(shouldMirror ? "enabled" : "disabled")")
              
               // Make sure the view is visible
               localVideo.isHidden = false
               self.view.isHidden = false
           } else {
               NSLog("LocalViewController - displayLocalVideo failed with result: \(displayResult)")
           }
       } else {
           NSLog("LocalViewController - setVideoDeviceId failed with result: \(setVideoResult)")
       }
   }
   
   func setCameraDirectly(useFrontCamera: Bool) {
       NSLog("LocalViewController - setCameraDirectly: front=\(useFrontCamera)")
      
       // Safety check: ensure SDK is available
       guard let sdk = portSIPSDK else {
           NSLog("LocalViewController - setCameraDirectly failed: portSIPSDK is nil")
           return
       }
      
       // Safety check: ensure video view is available
       guard let localVideo = viewLocalVideo else {
           NSLog("LocalViewController - setCameraDirectly failed: viewLocalVideo is nil")
           return
       }
      
       // Safety check: ensure video is initialized
       if !isVideoInitialized {
           NSLog("LocalViewController - setCameraDirectly failed: video is not initialized")
           return
       }
      
       let cameraId: Int32 = useFrontCamera ? 1 : 0
       let setVideoResult = sdk.setVideoDeviceId(cameraId)
       if setVideoResult == 0 {
           // Enable mirror only for front camera
           let shouldMirror = useFrontCamera
          
           let displayResult = sdk.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
           if displayResult == 0 {
               NSLog("LocalViewController - Set to \(shouldMirror ? "front" : "back") camera with mirror \(shouldMirror ? "enabled" : "disabled")")
              
               // Make sure the view is visible
               localVideo.isHidden = false
               self.view.isHidden = false
           } else {
               NSLog("LocalViewController - displayLocalVideo failed with result: \(displayResult)")
           }
       } else {
           NSLog("LocalViewController - setVideoDeviceId failed with result: \(setVideoResult)")
       }
   }
  
   func updateVideoVisibility(isVisible: Bool) {
       NSLog("LocalViewController - updateVideoVisibility: \(isVisible)")
      
       // CRITICAL: Check if view controller is still valid and views are loaded
       guard isViewLoaded else {
           NSLog("[Warning] LocalViewController - View not loaded, ignoring video visibility update")
           return
       }
      
       // Check if we're still attached to a parent (not destroyed)
       guard parent != nil || view.superview != nil else {
           NSLog("[Warning] LocalViewController - View controller detached, ignoring video visibility update")
           return
       }
      
       // Check viewLocalVideo
       guard let localVideo = viewLocalVideo else {
           NSLog("[Warning] LocalViewController - viewLocalVideo is nil, view may be destroyed")
           self.safeUnregisterFromNotifications()
           return
       }
      
       // Check portSIPSDK
       guard let sdk = portSIPSDK else {
           NSLog("[Error] LocalViewController - portSIPSDK is nil")
           return
       }
      
       // Ensure we're on main thread
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
          
           // Double-check views are still valid on main thread
           guard let localVideo = self.viewLocalVideo else {
               NSLog("[Warning] LocalViewController - viewLocalVideo became nil on main thread")
               return
           }
          
           // Update the visibility of the view
           localVideo.isHidden = !isVisible
          
           // Only process video when it is initialized
           guard self.isVideoInitialized else {
               NSLog("[Warning] LocalViewController - updateVideoVisibility: video is not initialized")
               if isVisible {
                   // Try to initialize if we need to show video
                   self.initializeLocalVideo()
               }
               return
           }
          
           // Process video display
           if isVisible {
               // Display video with mirror depending on the camera
               let result = sdk.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
               NSLog("[Debug] LocalViewController - Display local video result: \(result)")
           } else {
               // Hide video but not release
               let result = sdk.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
               NSLog("[Debug] LocalViewController - Hide local video result: \(result)")
           }
       }
   }
  
   private func safeUnregisterFromNotifications() {
       NSLog("[Debug] LocalViewController - Safely unregistering from notifications due to view destruction")
       NotificationCenter.default.removeObserver(self)
   }
  
   func cleanupVideo() {
       NSLog("LocalViewController - cleanupVideo")
       if isVideoInitialized {
           portSIPSDK.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
           viewLocalVideo.releaseVideoRender()
           isVideoInitialized = false
       }
   }
  
   override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
       super.viewWillTransition(to: size, with: coordinator)
       coordinator.animate(alongsideTransition: { _ in
           // Không cần điều chỉnh kích thước video khi xoay màn hình vì đã dùng auto layout
           // để lấp đầy toàn bộ màn hình
       })
   }
}



