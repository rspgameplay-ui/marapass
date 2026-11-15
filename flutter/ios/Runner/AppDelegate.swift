import Flutter
import UIKit
import GoogleMaps
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var compass: MaraPassCompass?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
       !key.isEmpty, !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MaraPassCompass") {
      let handler = MaraPassCompass()
      compass = handler
      FlutterEventChannel(name: "marapass/compass", binaryMessenger: registrar.messenger()).setStreamHandler(handler)
    }
  }
}

final class MaraPassCompass: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
 private let manager = CLLocationManager()
 private var sink: FlutterEventSink?
 override init() { super.init(); manager.delegate = self; manager.headingFilter = 3 }
 func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
  guard CLLocationManager.headingAvailable() else { return FlutterError(code: "unavailable", message: "Bússola indisponível", details: nil) }
  sink = events; manager.startUpdatingHeading(); return nil
 }
 func onCancel(withArguments arguments: Any?) -> FlutterError? { manager.stopUpdatingHeading(); sink = nil; return nil }
 func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
  guard heading.headingAccuracy >= 0 else { return }
  sink?(heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading)
 }
 func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { return false }
}
