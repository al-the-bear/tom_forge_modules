import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // The evaluation is user-initiated and latency critical: macOS must
  // neither nap the app nor throttle its timers while it measures.
  private let activity = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiated, .latencyCritical, .idleSystemSleepDisabled],
    reason: "the PDF evaluation is measuring")

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
