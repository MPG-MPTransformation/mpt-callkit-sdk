import Flutter
import UIKit
import PortSIPVoIPSDK


class LocalViewFactory: NSObject, FlutterPlatformViewFactory {
   private var messenger: FlutterBinaryMessenger
  
   init(messenger: FlutterBinaryMessenger) {
       self.messenger = messenger
       super.init()
   }
  
   func create(
       withFrame frame: CGRect,
       viewIdentifier viewId: Int64,
       arguments args: Any?
   ) -> FlutterPlatformView {
       // 🔥 ANDROID PATTERN: Each view creates its own controller instance
       let independentLocalViewController = LocalViewController()
       
       // Get shared SDK reference from plugin
       let plugin = MptCallkitPlugin.shared
       independentLocalViewController.portSIPSDK = plugin.portSIPSDK
       independentLocalViewController.mCameraDeviceId = plugin.mUseFrontCamera ? 1 : 0
      
       return LocalView(
           frame: frame,
           viewIdentifier: viewId,
           arguments: args,
           binaryMessenger: messenger,
           localViewController: independentLocalViewController)
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
       print("LocalView - deinit: View is being destroyed")
       // Thông báo cho plugin biết local view bị destroyed
       NotificationCenter.default.post(name: NSNotification.Name("LocalViewDestroyed"), object: nil)
      
       // SAFE cleanup: Chỉ cleanup view controller riêng của platform view này
       // Không ảnh hưởng đến shared view controllers
       if let localVC = localViewController {
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
      
       print("LocalView - Posted LocalViewDestroyed notification")
   }
  
   func createNativeView(view _view: UIView, arguments args: Any?, localViewController: LocalViewController) {
       print("LocalViewFactory - Creating native view")
      
       let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
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
       print("LocalViewFactory - Posted LocalViewCreated notification")
      
       // 🔥 QUAN TRỌNG: Setup local video nếu đang có video call active
       setupLocalVideoForActiveCall(localViewController: localViewController)
   }
  
   private func setupLocalVideoForActiveCall(localViewController: LocalViewController) {
       // 🔥 ANDROID PATTERN: Views self-manage via state notifications
       // No direct setup calls needed - views will receive notifications and handle themselves
       print("LocalViewFactory - View created, will self-manage via state notifications")
   }
  
}

