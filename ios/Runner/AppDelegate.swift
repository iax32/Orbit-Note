import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var clipboardChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OrbitRichClipboard") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "orbit_note/clipboard", binaryMessenger: registrar.messenger())
    clipboardChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "setRichText" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let plainText = arguments["plainText"] as? String,
            let html = arguments["html"] as? String else {
        result(FlutterError(code: "invalid_arguments",
                            message: "Expected clipboard text and HTML.", details: nil))
        return
      }
      // One item with two representations: setting .string afterward would
      // discard HTML. Data keeps the rich representation encoded as UTF-8.
      UIPasteboard.general.items = [[
        "public.utf8-plain-text": Data(plainText.utf8),
        "public.html": Data(html.utf8),
      ]]
      result(true)
    }
  }
}
