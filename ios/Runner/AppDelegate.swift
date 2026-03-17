import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain // استخدم هذا الوسم لضمان التوافق الكامل
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // تسجيل مفتاح خرائط جوجل
    GMSServices.provideAPIKey("AIzaSyCbjtLCziPC2AeMg7poifI710bRKveSAAI")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}