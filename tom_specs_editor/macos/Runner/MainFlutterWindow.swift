import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // Closing the window is quitting the app (it has one window), so the close
  // is routed through `NSApp.terminate`, which FlutterAppDelegate hands to the
  // framework as an exit request the Forge shell can refuse (an application
  // with background work, an unsaved editor). Closing the window directly
  // would tear the view down first and ask afterwards, leaving no window to
  // show the question in.
  override func performClose(_ sender: Any?) {
    NSApp.terminate(sender)
  }
}
