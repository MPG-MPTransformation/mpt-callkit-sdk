import UIKit
import Flutter
import PushKit
import UserNotifications
import mpt_callkit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register APNs PUSH
    // if #available(iOS 10.0, *) {
    //     // iOS 10 and above
    //     let center = UNUserNotificationCenter.current()
    //     center.delegate = self
    //     center.requestAuthorization(options: [.badge, .sound, .alert]) { granted, error in
    //         if error == nil {
    //             print("request User Notification succeeded!")
    //         }
    //     }
    // } else {
    //     // iOS 8-10
    //     if UIApplication.shared.responds(to: #selector(UIApplication.registerUserNotificationSettings(_:))) {
    //         let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
    //         UIApplication.shared.registerUserNotificationSettings(settings)
    //     }
    // }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    var deviceTokenString = String()
    let bytes = [UInt8](deviceToken)
    for item in bytes {
      deviceTokenString += String(format: "%02x", item & 0x0000_00FF)
    }
    print("deviceTokenString: \(deviceTokenString)")
    
    // Truyền deviceTokenString sang MptCallkitPlugin thông qua public method
    MptCallkitPlugin.shared.setAPNsPushToken(deviceTokenString)
    
    return super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Thêm xử lý khi app sẽ terminate
  override func applicationWillTerminate(_ application: UIApplication) {
    // Gọi method public để cleanup PortSIP SDK
    MptCallkitPlugin.shared.cleanupOnTerminate()
      
    super.applicationWillTerminate(application)
  }
  
  // Thêm xử lý khi app enter background

  override func applicationDidEnterBackground(_ application: UIApplication) {
    MptCallkitPlugin.shared.didEnterBackground()
    super.applicationDidEnterBackground(application)
    
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    MptCallkitPlugin.shared.willEnterForeground()
    super.applicationWillEnterForeground(application)
    
  }
}
