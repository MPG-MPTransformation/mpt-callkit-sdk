import Flutter
import UIKit
import PortSIPVoIPSDK

class RemoteViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return RemoteView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class RemoteView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var remoteVideoView: PortSIPVideoRenderView?
    private weak var plugin: MptCallkitPlugin?
    
    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        _view = UIView(frame: frame)
        plugin = MptCallkitPlugin.shared
        super.init()
        
        // Thiết lập view
        _view.backgroundColor = UIColor.black
        
        // Tạo và cấu hình remoteVideoView
        createRemoteView()
        
        // Cập nhật trạng thái video dựa trên phiên hiện tại
        updateVideoState()
    }
    
    func view() -> UIView {
        return _view
    }
    
    private func createRemoteView() {
        // Tạo video view
        remoteVideoView = PortSIPVideoRenderView(frame: CGRect(x: 0, y: 0, width: _view.frame.width, height: _view.frame.height))
        
        // Đảm bảo remoteVideoView tự điều chỉnh kích thước theo container
        guard let remoteVideoView = remoteVideoView else { return }
        
        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        _view.addSubview(remoteVideoView)
        
        // Thiết lập constraints để fill toàn bộ view cha
        NSLayoutConstraint.activate([
            remoteVideoView.topAnchor.constraint(equalTo: _view.topAnchor),
            remoteVideoView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
            remoteVideoView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
            remoteVideoView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
        ])
        
        // Hiển thị remote video
        if let plugin = plugin,
           let activeSessionId = plugin.activeSessionid {
            plugin.portSIPSDK.setRemoteVideoWindow(activeSessionId, remoteVideoWindow: remoteVideoView)
        }
        
        // Đăng ký lắng nghe sự kiện broadcast
        setupReceiver()
    }
    
    private func updateVideoState() {
        guard let plugin = plugin,
              let activeSessionId = plugin.activeSessionid,
              let currentSession = plugin._callManager.findCallBySessionID(activeSessionId) else {
            return
        }
        
        if currentSession.session.sessionState && !currentSession.session.videoState {
            // Phiên kết nối và video không bị mute
            remoteVideoView?.isHidden = false
            
            if let remoteVideoView = remoteVideoView {
                plugin.portSIPSDK.setRemoteVideoWindow(activeSessionId, remoteVideoWindow: remoteVideoView)
            }
        } else {
            // Phiên không kết nối hoặc video bị mute
            remoteVideoView?.isHidden = true
            plugin.portSIPSDK.setRemoteVideoWindow(activeSessionId, remoteVideoWindow: nil)
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
    }
    
    @objc private func handleVideoStateChanged(_ notification: Notification) {
        updateVideoState()
    }
    
    // Giải phóng tài nguyên khi view bị hủy
    deinit {
        // Hủy đăng ký thông báo
        NotificationCenter.default.removeObserver(self)
        
        // Giải phóng video renderer
        if let remoteVideoView = remoteVideoView,
           let plugin = plugin,
           let activeSessionId = plugin.activeSessionid {
            plugin.portSIPSDK.setRemoteVideoWindow(activeSessionId, remoteVideoWindow: nil)
            remoteVideoView.removeFromSuperview()
        }
    }
}
