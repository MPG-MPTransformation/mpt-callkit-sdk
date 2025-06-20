import UIKit
import PortSIPVoIPSDK

class LocalViewController: UIViewController {
    var mCameraDeviceId: Int32 = 1 // 1 - FrontCamera 0 - BackCamera
    var viewLocalVideo: PortSIPVideoRenderView!
    var portSIPSDK: PortSIPSDK!
    var isVideoInitialized: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("LocalViewController - viewDidLoad")
        setupLocalVideoView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("LocalViewController - viewWillAppear")
        if !isVideoInitialized {
            mCameraDeviceId = 1
            initializeLocalVideo()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("LocalViewController - viewDidAppear")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("LocalViewController - viewDidDisappear")
        cleanupVideo()
    }
    
    private func setupLocalVideoView() {
        print("LocalViewController - setupLocalVideoView")
        // Create the local video view
        viewLocalVideo = PortSIPVideoRenderView()
        viewLocalVideo.translatesAutoresizingMaskIntoConstraints = false
        viewLocalVideo.backgroundColor = .black
        viewLocalVideo.contentMode = .scaleAspectFill // Sử dụng scaleAspectFill để lấp đầy view
        viewLocalVideo.clipsToBounds = true // Cắt phần thừa để không bị tràn ra ngoài
        self.view.addSubview(viewLocalVideo)
        
        // Đặt constraints để lấp đầy toàn bộ view controller
        NSLayoutConstraint.activate([
            viewLocalVideo.topAnchor.constraint(equalTo: view.topAnchor),
            viewLocalVideo.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            viewLocalVideo.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewLocalVideo.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Set a clear background for easy debugging
        self.view.backgroundColor = .black
    }
    
    func initializeLocalVideo() {
        print("LocalViewController - initializeLocalVideo")
        // Get the SDK instance from the plugin
        let appDelegate = MptCallkitPlugin.shared
        portSIPSDK = appDelegate.portSIPSDK
        
        if portSIPSDK != nil {
            print("LocalViewController - Initializing video render")
            viewLocalVideo.initVideoRender()
            // Display local video with mirror enabled for front camera
            let result = portSIPSDK.displayLocalVideo(true, mirror: mCameraDeviceId == 1, localVideoWindow: viewLocalVideo)
            print("LocalViewController - displayLocalVideo result: \(result)")
            isVideoInitialized = true
            
            // Make sure the view is visible
            viewLocalVideo.isHidden = false
            self.view.isHidden = false
        } else {
            print("LocalViewController - Error: portSIPSDK is nil")
        }
    }
    
    func switchCamera() {
        print("LocalViewController - switchCamera: current device ID = \(mCameraDeviceId)")
        
        // Toggle camera ID (1 -> 0 OR 0 -> 1)
        let newCameraId: Int32 = mCameraDeviceId == 1 ? 0 : 1
        
        if portSIPSDK.setVideoDeviceId(newCameraId) == 0 {
            mCameraDeviceId = newCameraId
            // Enable mirror only for front camera (ID = 1)
            let shouldMirror = mCameraDeviceId == 1
            portSIPSDK.displayLocalVideo(true, mirror: shouldMirror, localVideoWindow: viewLocalVideo)
            print("LocalViewController - Switched to \(shouldMirror ? "front" : "back") camera with mirror \(shouldMirror ? "enabled" : "disabled")")
        }
        
        // Make sure the view is visible
        viewLocalVideo.isHidden = false
        self.view.isHidden = false
    }
    
    func updateVideoVisibility(isVisible: Bool) {
        print("LocalViewController - updateVideoVisibility: \(isVisible)")
        
        // Check viewLocalVideo
        guard let localVideo = viewLocalVideo else {
            print("[Error] LocalViewController - updateVideoVisibility: viewLocalVideo is nil")
            return
        }
        
        // Check portSIPSDK
        guard let sdk = portSIPSDK else {
            print("[Error] LocalViewController - updateVideoVisibility: portSIPSDK is nil")
            return
        }
            
        // Update the visibility of the view
        localVideo.isHidden = !isVisible
        
        // Only process video when it is initialized
        guard isVideoInitialized else {
            print("[Warning] LocalViewController - updateVideoVisibility: video is not initialized")
            return
        }
        
        // Process video display
        if isVisible {
            // Display video with mirror depending on the camera
            let result = sdk.displayLocalVideo(true, 
                                             mirror: mCameraDeviceId == 1, 
                                             localVideoWindow: localVideo)
            print("[Debug] LocalViewController - Display local video result: \(result)")
        } else {
            // Hide video but not release
            let result = sdk.displayLocalVideo(false, 
                                             mirror: false, 
                                             localVideoWindow: nil)
            print("[Debug] LocalViewController - Hide local video result: \(result)")
        }
    }
    
    func cleanupVideo() {
        print("LocalViewController - cleanupVideo")
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
