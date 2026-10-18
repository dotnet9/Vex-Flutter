import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMethodChannel(name: "vex/clipboard", binaryMessenger: flutterViewController.engine.binaryMessenger).setMethodCallHandler { call, result in
      guard call.method == "writeHtml" else { result(FlutterMethodNotImplemented); return }
      guard let args = call.arguments as? [String: Any], let html = args["html"] as? String, let text = args["text"] as? String else {
        result(FlutterError(code: "clipboard", message: "Invalid clipboard content", details: nil)); return
      }
      let item = NSPasteboardItem()
      item.setString(html, forType: .html)
      item.setString(text, forType: .string)
      NSPasteboard.general.clearContents()
      if NSPasteboard.general.writeObjects([item]) { result(nil) }
      else { result(FlutterError(code: "clipboard", message: "Cannot write clipboard content", details: nil)) }
    }

    super.awakeFromNib()
  }
}
