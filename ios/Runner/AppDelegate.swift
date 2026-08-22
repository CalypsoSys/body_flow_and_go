import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let storageChannel = FlutterMethodChannel(
      name: "com.calypsosystems.golog/storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    storageChannel.setMethodCallHandler { call, result in
      guard call.method == "excludeDatabaseFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Database path is required", details: nil))
        return
      }

      do {
        try Self.excludeFromBackup(path: path)
        result(nil)
      } catch {
        result(FlutterError(code: "BACKUP_EXCLUSION_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }

  private static func excludeFromBackup(path: String) throws {
    let fileManager = FileManager.default
    let paths = [path, "\(path)-wal", "\(path)-shm"]
    for candidate in paths where fileManager.fileExists(atPath: candidate) {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var url = URL(fileURLWithPath: candidate)
      try url.setResourceValues(values)
    }
  }
}
