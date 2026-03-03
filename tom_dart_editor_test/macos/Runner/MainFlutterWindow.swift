import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Set a larger default window size
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let windowWidth: CGFloat = min(1400, screenFrame.width * 0.85)
    let windowHeight: CGFloat = min(900, screenFrame.height * 0.85)
    let windowX = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
    let windowY = screenFrame.origin.y + (screenFrame.height - windowHeight) / 2
    let windowFrame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
