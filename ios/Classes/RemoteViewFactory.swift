import Flutter
import UIKit

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
    private var remoteVideoView: PortSIPVideoRenderer?
    
    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        _view = UIView(frame: frame)
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
        remoteVideoView = PortSIPVideoRenderer(frame: CGRect(x: 0, y: 0, width: _view.frame.width, height: _view.frame.height))
        
        // Đảm bảo remoteVideoView tự điều chỉnh kích thước theo container
        if let remoteVideoView = remoteVideoView {
            remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
            _view.addSubview(remoteVideoView)
            
            // Thiết lập constraints để fill toàn bộ view cha
            NSLayoutConstraint.activate([
                remoteVideoView.topAnchor.constraint(equalTo: _view.topAnchor),
                remoteVideoView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
                remoteVideoView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
                remoteVideoView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
            ])
            
            // Thiết lập remote video window
            if let plugin = MptCallkitPlugin.shared, plugin.activeSessionid > 0 {
                plugin.portSIPSDK.setRemoteVideoWindow(plugin.activeSessionid, remoteVideoWindow: remoteVideoView)
            }
        }
        
        // Đăng ký lắng nghe sự kiện broadcast
        setupReceiver()
    }
    
    private func updateVideoState() {
        // Kiểm tra phiên hiện tại để quyết định hiển thị hay ẩn remote video
        if let plugin = MptCallkitPlugin.shared, 
           let currentSession = plugin._callManager.findCallBySessionID(plugin.activeSessionid) {
            
            if currentSession.session.sessionState && currentSession.session.videoState {
                // Phiên kết nối và có video
                remoteVideoView?.isHidden = false
                
                if let remoteVideoView = remoteVideoView {
                    plugin.portSIPSDK.setRemoteVideoWindow(plugin.activeSessionid, remoteVideoWindow: remoteVideoView)
                }
            } else {
                // Phiên không kết nối hoặc không có video
                remoteVideoView?.isHidden = true
                plugin.portSIPSDK.setRemoteVideoWindow(plugin.activeSessionid, remoteVideoWindow: nil)
            }
        }
    }
    
    private func setupReceiver() {
        // Đăng ký lắng nghe thông báo để cập nhật trạng thái video
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCallStateChanged),
            name: NSNotification.Name("CALL_STATE_CHANGED"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVideoStateChanged),
            name: NSNotification.Name("VIDEO_MUTE_STATE_CHANGED"),
            object: nil
        )
    }
    
    @objc private func handleCallStateChanged(_ notification: Notification) {
        updateVideoState()
    }
    
    @objc private func handleVideoStateChanged(_ notification: Notification) {
        updateVideoState()
    }
    
    // Giải phóng tài nguyên khi view bị hủy
    deinit {
        // Hủy đăng ký thông báo
        NotificationCenter.default.removeObserver(self)
        
        if let remoteVideoView = remoteVideoView {
            // Gọi method để giải phóng tài nguyên video renderer
            if let plugin = MptCallkitPlugin.shared, plugin.activeSessionid > 0 {
                plugin.portSIPSDK.setRemoteVideoWindow(plugin.activeSessionid, remoteVideoWindow: nil)
            }
            remoteVideoView.releaseDrawer()
        }
    }
}
