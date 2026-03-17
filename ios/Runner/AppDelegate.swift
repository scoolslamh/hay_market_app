import Flutter
import UIKit
import GoogleMaps // 1. أضف هذا السطر لاستيراد المكتبة

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 2. أضف هذا السطر ووضع مفتاح الـ API الخاص بك بين القوسين
    GMSServices.provideAPIKey("AIzaSyCbjtLCziPC2AeMg7poifI710bRKveSAAI")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}