import Flutter
import UIKit
import PortSIPVoIPSDK


class RemoteViewFactory: NSObject, FlutterPlatformViewFactory {
   private var messenger: FlutterBinaryMessenger
   public static var remoteView: RemoteView? // only keep one instance
  
   init(messenger: FlutterBinaryMessenger) {
       self.messenger = messenger
       super.init()
   }
  
   func create(
       withFrame frame: CGRect,
       viewIdentifier viewId: Int64,
       arguments args: Any?
   ) -> FlutterPlatformView {
       // 🔥 PATTERN: Each view creates its own controller instance
       let viewController = RemoteViewController()
       
       // Get shared SDK reference from plugin
       let plugin = MptCallkitPlugin.shared
       viewController.portSIPSDK = plugin.portSIPSDK
       viewController.sessionId = 0 // Will be set later via notifications
      
       RemoteViewFactory.remoteView = RemoteView(
           frame: frame,
           viewIdentifier: viewId,
           arguments: args,
           binaryMessenger: messenger,
           remoteViewController: viewController)
        return RemoteViewFactory.remoteView!
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
//       _view.backgroundColor = .black // 🔥 FIX: Background đen cho letterbox/pillarbox
//       _view.clipsToBounds = true // 🔥 FIX: Cắt phần thừa để không bị tràn ra ngoài
       self.remoteViewController = remoteViewController
       super.init()
       createNativeView(view: _view, arguments: args, remoteViewController: remoteViewController)
   }
  
   func view() -> UIView {
       return _view
   }
  
   deinit {
       print("RemoteView - deinit: View is being destroyed")
       
       // Fix: Ensure cleanup happens on main thread to prevent warnings
       DispatchQueue.main.async {
           // Thông báo cho plugin biết remote view bị destroyed
           NotificationCenter.default.post(name: NSNotification.Name("RemoteViewDestroyed"), object: nil)
           
           print("RemoteView - Posted RemoteViewDestroyed notification")
       }
      
       // SAFE cleanup: Chỉ cleanup view controller riêng của platform view này
       // Không ảnh hưởng đến shared view controllers
       if let remoteVC = remoteViewController {
           // Fix: Dismiss keyboard input to prevent RTIInputSystemClient warnings
           remoteVC.view.endEditing(true)
           
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
   }
  
   func createNativeView(view _view: UIView, arguments args: Any?, remoteViewController: RemoteViewController) {
       print("RemoteViewFactory - Creating native view")
      
       // Fix: Use modern window access pattern for iOS 13+
       let keyWindow: UIWindow?
       if #available(iOS 13.0, *) {
           keyWindow = UIApplication.shared.connectedScenes
               .compactMap { $0 as? UIWindowScene }
               .flatMap { $0.windows }
               .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.connectedScenes
               .compactMap { $0 as? UIWindowScene }
               .flatMap { $0.windows }
               .first
       } else {
           keyWindow = UIApplication.shared.keyWindow
       }
       let topController = keyWindow?.rootViewController
       let flutterView = remoteViewController
      
       let view = flutterView.view
       view?.translatesAutoresizingMaskIntoConstraints = false
//       view?.clipsToBounds = true // 🔥 FIX: Cắt phần thừa để không bị tràn ra ngoài


       topController?.addChild(flutterView)
       _view.addSubview(view!)


       // 🔥 FIX: Respect Flutter widget size constraints
       // Instead of forcing full size, let the view controller size itself
       // The RemoteViewController will handle its own sizing within the Flutter widget bounds
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
       // 🔥 PATTERN: Views self-manage via state notifications
       // No direct setup calls needed - views will receive notifications and handle themselves
       print("RemoteViewFactory - View created, will self-manage via state notifications")
   }
  
}

