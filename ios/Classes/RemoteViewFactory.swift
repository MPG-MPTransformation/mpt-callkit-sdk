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
        }
    }
    
    // Giải phóng tài nguyên khi view bị hủy
    deinit {
        if let remoteVideoView = remoteVideoView {
            // Gọi method để giải phóng tài nguyên video renderer nếu cần
            // remoteVideoView.release()
        }
    }
}
