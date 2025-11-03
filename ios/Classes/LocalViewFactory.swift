import Flutter
import UIKit
import PortSIPVoIPSDK


class LocalViewFactory: NSObject, FlutterPlatformViewFactory {
   private var messenger: FlutterBinaryMessenger
   public static var localView: LocalView?
  
   init(messenger: FlutterBinaryMessenger) {
       self.messenger = messenger
       super.init()
   }

     public func setImage(image: UIImage?) {
         LocalViewFactory.localView?.localViewController?.setImage(image: image)
     }
  
   func create(
       withFrame frame: CGRect,
       viewIdentifier viewId: Int64,
       arguments args: Any?
   ) -> FlutterPlatformView {
       // 🔥 ANDROID PATTERN: Each view creates its own controller instance
       
       // Get shared SDK reference from plugin
       let plugin = MptCallkitPlugin.shared
       let viewController = LocalViewController()
       viewController.portSIPSDK = plugin.portSIPSDK
       viewController.mCameraDeviceId = plugin.mUseFrontCamera ? 1 : 0
      
       LocalViewFactory.localView = LocalView(
           frame: frame,
           viewIdentifier: viewId,
           arguments: args,
           binaryMessenger: messenger,
           localViewController: viewController)
        return LocalViewFactory.localView!
   }
  
   public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
       return FlutterStandardMessageCodec.sharedInstance()
   }
}


class LocalView: NSObject, FlutterPlatformView {
   private var _view: UIView
   var localViewController: LocalViewController!
  
   init(
       frame: CGRect,
       viewIdentifier viewId: Int64,
       arguments args: Any?,
       binaryMessenger messenger: FlutterBinaryMessenger?,
       localViewController: LocalViewController
   ) {
       _view = UIView()
       self.localViewController = localViewController
       super.init()
       createNativeView(view: _view, arguments: args, localViewController: localViewController)
   }
  
   func view() -> UIView {
       return _view
   }
  
   deinit {
       NSLog("LocalView - deinit: View is being destroyed")
       
       // Fix: Ensure cleanup happens on main thread to prevent warnings
       DispatchQueue.main.async {
           // Thông báo cho plugin biết local view bị destroyed
           NotificationCenter.default.post(name: NSNotification.Name("LocalViewDestroyed"), object: nil)
           
           NSLog("LocalView - Posted LocalViewDestroyed notification")
       }
      
       // SAFE cleanup: Chỉ cleanup view controller riêng của platform view này
       // Không ảnh hưởng đến shared view controllers
       if let localVC = localViewController {
           // Fix: Dismiss keyboard input to prevent RTIInputSystemClient warnings
           localVC.view.endEditing(true)
           
           // Chỉ remove khỏi parent nếu nó thực sự là child
           if localVC.parent != nil {
               localVC.removeFromParent()
           }
           // Chỉ remove view nếu nó có superview
           if localVC.view.superview != nil {
               localVC.view.removeFromSuperview()
           }
           // Cleanup video để tránh memory leak
           localVC.cleanupVideo()
       }
   }
  
   func createNativeView(view _view: UIView, arguments args: Any?, localViewController: LocalViewController) {
       NSLog("LocalViewFactory - Creating native view")
      
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
       let flutterView = localViewController
      
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
      
       // Thông báo cho plugin biết local view đã được tạo
       NotificationCenter.default.post(name: NSNotification.Name("LocalViewCreated"), object: nil)
       NSLog("LocalViewFactory - Posted LocalViewCreated notification")
      
       // 🔥 QUAN TRỌNG: Setup local video nếu đang có video call active
       setupLocalVideoForActiveCall(localViewController: localViewController)
   }
  
   private func setupLocalVideoForActiveCall(localViewController: LocalViewController) {
       // 🔥 ANDROID PATTERN: Views self-manage via state notifications
       // No direct setup calls needed - views will receive notifications and handle themselves
       NSLog("LocalViewFactory - View created, will self-manage via state notifications")
   }
  
}

