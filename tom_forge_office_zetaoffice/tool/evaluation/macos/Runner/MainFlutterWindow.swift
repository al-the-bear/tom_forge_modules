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

    // The office evaluation needs its window visible to the person at the
    // machine (WebKit runs ZetaOffice's page normally only then, and the
    // window images show it): it comes to the front at the start.
    // Flutter stops drawing a fully covered window, and the harness waits
    // on frames: the window floats above the others for the run (on its
    // display; the screen is unlocked whenever the runner starts it), and
    // on every Space: on one Space only it is hidden as soon as the person
    // at the machine switches to another.
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    // Nor can it be minimised: a minimised window draws no frames either.
    self.styleMask.remove(.miniaturizable)
    NSApp.activate(ignoringOtherApps: true)
    self.makeKeyAndOrderFront(nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      NSApp.activate(ignoringOtherApps: true)
      self?.makeKeyAndOrderFront(nil)
    }

    // An evaluation-only switch (WebKit SPI, never in Forge): WebKit stops
    // drawing (and requestAnimationFrame) in a window it finds covered or
    // hidden, so every webview of the window keeps drawing when the window
    // is covered or the screen is locked, and an unattended run measures
    // the ZetaOffice view at all. The results record whether the screen was locked. (A
    // floating window brought to the front hangs in LaunchServices while
    // the screen is locked, so the window is left where macOS puts it.)
    occlusionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) {
      [weak self] _ in
      guard let root = self?.contentView else { return }
      MainFlutterWindow.keepVisible(root)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The crash-isolation measure: this window's web content processes end
    // as the system ends one under memory pressure, by a SIGKILL to the pid
    // WebKit gives for each of this window's webviews (never another app's).
    // WebKit's test switch _killWebContentProcess is not used: it ends the
    // process as requested by the client, and WebKit then tells no
    // navigation delegate, so the tab could never notice it. Evaluation only,
    // never in Forge.
    let webkit = FlutterMethodChannel(
      name: "eval/webkit", binaryMessenger: flutterViewController.engine.binaryMessenger)
    webkit.setMethodCallHandler { [weak self] call, result in
      guard call.method == "killWebContent", let root = self?.contentView else {
        result(FlutterMethodNotImplemented)
        return
      }
      var pids: [Int] = []
      MainFlutterWindow.webViews(root).forEach { web in
        if let pid = web.value(forKey: "_webProcessIdentifier") as? Int, pid > 0 {
          pids.append(pid)
          Darwin.kill(pid_t(pid), SIGKILL)
        }
      }
      result(pids)
    }

    super.awakeFromNib()
  }

  private static func webViews(_ view: NSView) -> [WKWebView] {
    var out: [WKWebView] = []
    if let web = view as? WKWebView { out.append(web) }
    for child in view.subviews { out += webViews(child) }
    return out
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
