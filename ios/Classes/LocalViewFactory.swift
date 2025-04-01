import Flutter
import UIKit
import PortSIPVoIPSDK

class LocalViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return LocalView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class LocalView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var localVideoView: PortSIPVideoRenderView?
    
    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        _view = UIView(frame: frame)
        super.init()
        
        // Thiết lập view
        _view.backgroundColor = UIColor.black
        
        // Thiết lập camera dựa vào trạng thái hiện tại của mUseFrontCamera
        if let plugin = MptCallkitPlugin.shared {
            plugin.setCamera(useFrontCamera: plugin.mUseFrontCamera)
        }
        
        // Tạo và cấu hình localVideoView
        createLocalView()
        
        // Cập nhật trạng thái video dựa trên phiên hiện tại
        updateVideoState()
    }
    
    func view() -> UIView {
        return _view
    }
    
    private func createLocalView() {
        // Tạo video view
        localVideoView = PortSIPVideoRenderView(frame: CGRect(x: 0, y: 0, width: _view.frame.width, height: _view.frame.height))
        
        // Đảm bảo localVideoView tự điều chỉnh kích thước theo container
        if let localVideoView = localVideoView {
            localVideoView.translatesAutoresizingMaskIntoConstraints = false
            _view.addSubview(localVideoView)
            
            // Thiết lập constraints để fill toàn bộ view cha
            NSLayoutConstraint.activate([
                localVideoView.topAnchor.constraint(equalTo: _view.topAnchor),
                localVideoView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
                localVideoView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
                localVideoView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
            ])
            
            // Hiển thị local video
            if let plugin = MptCallkitPlugin.shared {
                plugin.portSIPSDK.displayLocalVideo(true, mirror: true, localVideoWindow: localVideoView)
            }
        }
        
        // Đăng ký lắng nghe sự kiện broadcast
        setupReceiver()
    }
    
    private func updateVideoState() {
        // Kiểm tra phiên hiện tại để quyết định hiển thị hay ẩn video
        if let plugin = MptCallkitPlugin.shared, 
           let currentSession = plugin._callManager.findCallBySessionID(plugin.activeSessionid) {
            
            if currentSession.session.sessionState && !currentSession.session.videoState {
                // Phiên kết nối và video không bị mute
                localVideoView?.isHidden = false
                
                if let localVideoView = localVideoView {
                    plugin.portSIPSDK.displayLocalVideo(true, mirror: true, localVideoWindow: localVideoView)
                }
            } else {
                // Phiên không kết nối hoặc video bị mute
                localVideoView?.isHidden = true
                plugin.portSIPSDK.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
            }
        }
    }
    
    private func setupReceiver() {
        // Đăng ký lắng nghe thông báo để cập nhật trạng thái video
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVideoStateChanged),
            name: NSNotification.Name("VIDEO_MUTE_STATE_CHANGED"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCameraSwitch),
            name: NSNotification.Name("CAMERA_SWITCH_ACTION"),
            object: nil
        )
    }
    
    @objc private func handleVideoStateChanged(_ notification: Notification) {
        updateVideoState()
    }
    
    @objc private func handleCameraSwitch(_ notification: Notification) {
        if let plugin = MptCallkitPlugin.shared {
            _ = plugin.switchCamera()
        }
    }
    
    // Giải phóng tài nguyên khi view bị hủy
    deinit {
        // Hủy đăng ký thông báo
        NotificationCenter.default.removeObserver(self)
        
        // Giải phóng video renderer
        if let localVideoView = localVideoView {
            // Gọi method để giải phóng tài nguyên video renderer
            if let plugin = MptCallkitPlugin.shared {
                plugin.portSIPSDK.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
            }

            if localVideoView.responds(to: #selector(releaseDrawer)) {
            localVideoView.releaseDrawer()
        }
    }

    @objc private func releaseDrawer() {
    }
}
