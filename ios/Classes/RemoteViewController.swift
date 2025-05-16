import UIKit
import PortSIPVoIPSDK

class RemoteViewController: UIViewController {
    var sessionId: Int = 0
    var viewRemoteVideo: PortSIPVideoRenderView!
    var portSIPSDK: PortSIPSDK!
    var isVideoInitialized: Bool = false
    var isStartVideo: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("RemoteViewController - viewDidLoad")
        setupRemoteVideoView()
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
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("RemoteViewController - viewDidDisappear")
        cleanupVideo()
    }
    
    private func setupRemoteVideoView() {
        print("RemoteViewController - setupRemoteVideoView")
        // Create the remote video view
        viewRemoteVideo = PortSIPVideoRenderView()
        viewRemoteVideo.translatesAutoresizingMaskIntoConstraints = false
        viewRemoteVideo.backgroundColor = .black
        viewRemoteVideo.contentMode = .scaleAspectFill // Sử dụng scaleAspectFill để lấp đầy view
        viewRemoteVideo.clipsToBounds = true // Cắt phần thừa để không bị tràn ra ngoài
        self.view.addSubview(viewRemoteVideo)
        
        // Đặt constraints để lấp đầy toàn bộ màn hình (không dùng safeArea)
        NSLayoutConstraint.activate([
            viewRemoteVideo.topAnchor.constraint(equalTo: view.topAnchor),
            viewRemoteVideo.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            viewRemoteVideo.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewRemoteVideo.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Đặt màu nền rõ ràng để dễ debug
        self.view.backgroundColor = .black
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
            
            // Đảm bảo view được hiển thị
            viewRemoteVideo.isHidden = false
            self.view.isHidden = false
        } else {
            print("RemoteViewController - Error: portSIPSDK is nil or sessionId = 0")
        }
    }
    
    func onStartVideo(_ sessionID: Int) {
        print("RemoteViewController - onStartVideo: \(sessionID)")
        DispatchQueue.main.async {
            self.isStartVideo = true
            self.sessionId = sessionID
            
            if self.isVideoInitialized {
                // Set the remote video window
                print("RemoteViewController - Setting remote video window")
                let result = self.portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: self.viewRemoteVideo)
                print("RemoteViewController - setRemoteVideoWindow result: \(result)")
            } else {
                // Initialize if not already done
                print("RemoteViewController - Initializing remote video first")
                self.initializeRemoteVideo()
                let result = self.portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: self.viewRemoteVideo)
                print("RemoteViewController - setRemoteVideoWindow result: \(result)")
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
        self.viewRemoteVideo.isHidden = !isVisible
        
        if isVisible && isVideoInitialized && sessionId != 0 {
            // Đảm bảo video được hiển thị
            let result = portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: self.viewRemoteVideo)
            print("RemoteViewController - setRemoteVideoWindow result: \(result)")
        } else if !isVisible && isVideoInitialized && sessionId != 0 {
            // Ẩn video
            portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: nil)
        }
    }
    
    func cleanupVideo() {
        print("RemoteViewController - cleanupVideo")
        if isVideoInitialized {
            if sessionId != 0 {
                portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
                portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: nil)
            }
            
            viewRemoteVideo.releaseVideoRender()
            isVideoInitialized = false
            isStartVideo = false
        }
    }
}