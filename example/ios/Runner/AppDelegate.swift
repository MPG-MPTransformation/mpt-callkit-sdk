import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Thêm xử lý khi app sẽ terminate
  override func applicationWillTerminate(_ application: UIApplication) {
    super.applicationWillTerminate(application)
    
    // // Unregister SIP
    // if let plugin = MptCallkitPlugin.shared {
    //   plugin.loginViewController.offLine()
    // }
  }
  
  // Thêm xử lý khi app enter background
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    
    // // Unregister SIP
    // if let plugin = MptCallkitPlugin.shared {
    //   plugin.loginViewController.offLine()
    // }
  }
}
