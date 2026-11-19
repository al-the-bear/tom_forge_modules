import Cocoa
import FlutterMacOS
import WebKit

class MainFlutterWindow: NSWindow {
  private var occlusionTimer: Timer?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // The same window for every run: 1280 x 900 points, as a Forge editor
    // area on a laptop screen.
    let windowFrame = NSRect(x: 80, y: 80, width: 1280, height: 900)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // An evaluation-only switch (WebKit SPI, never in Forge): WebKit stops
    // drawing (and requestAnimationFrame) in a window it finds covered or
    // hidden, so every webview of the window keeps drawing when the window
    // is covered or the screen is locked, and an unattended run measures
    // pdf.js at all. The results record whether the screen was locked. (A
    // floating window brought to the front hangs in LaunchServices while
    // the screen is locked, so the window is left where macOS puts it.)
    occlusionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) {
      [weak self] _ in
      guard let root = self?.contentView else { return }
      MainFlutterWindow.keepVisible(root)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  private static func keepVisible(_ view: NSView) {
    if let web = view as? WKWebView {
      let selector = Selector(("_setWindowOcclusionDetectionEnabled:"))
      if web.responds(to: selector),
        (web.value(forKey: "_windowOcclusionDetectionEnabled") as? Bool) != false
      {
        web.setValue(false, forKey: "_windowOcclusionDetectionEnabled")
      }
    }
    for child in view.subviews { keepVisible(child) }
  }
}
