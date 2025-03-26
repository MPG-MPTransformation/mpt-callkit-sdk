import Flutter
import UIKit

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
    private var localVideoView: PortSIPVideoRenderer?
    
    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        _view = UIView(frame: frame)
        super.init()
        
        // Thiết lập view
        _view.backgroundColor = UIColor.black
        
        // Tạo và cấu hình localVideoView
        createLocalView()
    }
    
    func view() -> UIView {
        return _view
    }
    
    private func createLocalView() {
        // Tạo video view
        localVideoView = PortSIPVideoRenderer(frame: CGRect(x: 0, y: 0, width: _view.frame.width, height: _view.frame.height))
        
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
        }
    }
    
    // Giải phóng tài nguyên khi view bị hủy
    deinit {
        if let localVideoView = localVideoView {
            // Gọi method để giải phóng tài nguyên video renderer nếu cần
            // localVideoView.release()
        }
    }
}
