import Flutter
import UIKit
import PortSIPVoIPSDK


class RemoteViewFactory: NSObject, FlutterPlatformViewFactory {
   private var messenger: FlutterBinaryMessenger
   var sharedRemoteViewController: RemoteViewController!
  
   init(messenger: FlutterBinaryMessenger, remoteViewController: RemoteViewController) {
       self.messenger = messenger
       self.sharedRemoteViewController = remoteViewController
       super.init()
   }
  
   func create(
       withFrame frame: CGRect,
       viewIdentifier viewId: Int64,
       arguments args: Any?
   ) -> FlutterPlatformView {
       // Tạo view controller riêng cho mỗi platform view instance
       let independentRemoteViewController = RemoteViewController()
       independentRemoteViewController.portSIPSDK = sharedRemoteViewController.portSIPSDK
       independentRemoteViewController.sessionId = sharedRemoteViewController.sessionId
      
       return RemoteView(
           frame: frame,
           viewIdentifier: viewId,
           arguments: args,
           binaryMessenger: messenger,
           remoteViewController: independentRemoteViewController)
   }
  
   public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
       return FlutterStandardMessageCodec.sharedInstance()
   }
}


class RemoteView: NSObject, FlutterPlatformView {
   private var _view: UIView
   var remoteViewController: RemoteViewController!
  
   init(
       frame: CGRect,
       viewIdentifier viewId: Int64,
       arguments args: Any?,
       binaryMessenger messenger: FlutterBinaryMessenger?,
       remoteViewController: RemoteViewController
   ) {
       _view = UIView()
       self.remoteViewController = remoteViewController
       super.init()
       createNativeView(view: _view, arguments: args, remoteViewController: remoteViewController)
   }
  
   func view() -> UIView {
       return _view
   }
  
   deinit {
       print("RemoteView - deinit: View is being destroyed")
       // Thông báo cho plugin biết remote view bị destroyed
       NotificationCenter.default.post(name: NSNotification.Name("RemoteViewDestroyed"), object: nil)
      
       // SAFE cleanup: Chỉ cleanup view controller riêng của platform view này
       // Không ảnh hưởng đến shared view controllers
       if let remoteVC = remoteViewController {
           // Chỉ remove khỏi parent nếu nó thực sự là child
           if remoteVC.parent != nil {
               remoteVC.removeFromParent()
           }
           // Chỉ remove view nếu nó có superview
           if remoteVC.view.superview != nil {
               remoteVC.view.removeFromSuperview()
           }
           // Cleanup video để tránh memory leak
           remoteVC.cleanupVideo()
       }
      
       print("RemoteView - Posted RemoteViewDestroyed notification")
   }
  
   func createNativeView(view _view: UIView, arguments args: Any?, remoteViewController: RemoteViewController) {
       print("RemoteViewFactory - Creating native view")
      
       let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
       let topController = keyWindow?.rootViewController
       let flutterView = remoteViewController
      
       let view = flutterView.view
       view?.translatesAutoresizingMaskIntoConstraints = false


       topController?.addChild(flutterView)
       _view.addSubview(view!)


       NSLayoutConstraint.activate([
           view!.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
           view!.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
           view!.topAnchor.constraint(equalTo: _view.topAnchor),
           view!.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
       ])


       flutterView.didMove(toParent: topController)
      
       // Thông báo cho plugin biết remote view đã được tạo
       NotificationCenter.default.post(name: NSNotification.Name("RemoteViewCreated"), object: nil)
       print("RemoteViewFactory - Posted RemoteViewCreated notification")
      
       // 🔥 QUAN TRỌNG: Setup remote video nếu đang có video call active
       setupRemoteVideoForActiveCall(remoteViewController: remoteViewController)
   }
  
   private func setupRemoteVideoForActiveCall(remoteViewController: RemoteViewController) {
       // Delay để đảm bảo view đã được setup hoàn toàn
       DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
           let plugin = MptCallkitPlugin.shared
          
           // Kiểm tra xem có active video call không
           guard plugin.activeSessionid != CLong(INVALID_SESSION_ID),
                 let result = plugin._callManager.findCallBySessionID(plugin.activeSessionid),
                 result.session.videoState && result.session.sessionState else {
               print("RemoteViewFactory - No active video call to setup")
               return
           }
          
           print("RemoteViewFactory - Found active video call, setting up remote video")
          
           // Cập nhật sessionId cho remote view controller
           remoteViewController.sessionId = Int(plugin.activeSessionid)
           remoteViewController.portSIPSDK = plugin.portSIPSDK
          
           // Initialize và setup remote video
           if !remoteViewController.isVideoInitialized {
               remoteViewController.initializeRemoteVideo()
           }
          
           // Setup remote video window
           remoteViewController.onStartVideo(Int(plugin.activeSessionid))
          
           print("RemoteViewFactory - Remote video setup completed for session \(plugin.activeSessionid)")
       }
   }
  
}

