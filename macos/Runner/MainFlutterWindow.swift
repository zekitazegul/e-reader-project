import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "e_reader/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    windowChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setFullscreen", let enabled = call.arguments as? Bool,
            let window = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      if window.styleMask.contains(.fullScreen) != enabled {
        window.toggleFullScreen(nil)
      }
      result(nil)
    }
    for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(fullscreenChanged(_:)), name: name, object: self)
    }

    super.awakeFromNib()
  }

  @objc private func fullscreenChanged(_ notification: Notification) {
    windowChannel?.invokeMethod("fullscreenChanged", arguments: styleMask.contains(.fullScreen))
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
