import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Start at a comfortable desktop size (sidebar layout); never so narrow that the phone layout breaks.
    self.setContentSize(NSSize(width: 1180, height: 820))
    self.contentMinSize = NSSize(width: 420, height: 600)
    self.title = "Oratge"
    self.center()
    self.setFrameAutosaveName("OratgeMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
