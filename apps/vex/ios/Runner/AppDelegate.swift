import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var documentResult: FlutterResult?
  private var exportFile: URL?
  private let documentQueue = DispatchQueue(label: "com.codewf.vex.documents")
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VexDocuments")!
    FlutterMethodChannel(name: "vex/documents", binaryMessenger: registrar.messenger()).setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "pickDocument", "saveDocument":
        guard self.documentResult == nil else { result(FlutterError(code: "busy", message: "A document picker is already open", details: nil)); return }
        do {
          let picker: UIDocumentPickerViewController
          if call.method == "saveDocument" {
            guard let bytes = args["bytes"] as? FlutterStandardTypedData, let name = args["name"] as? String else { throw CocoaError(.fileWriteUnknown) }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent((name as NSString).lastPathComponent)
            try bytes.data.write(to: file, options: .atomic)
            self.exportFile = file
            picker = UIDocumentPickerViewController(url: file, in: .exportToService)
          } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.text", "public.data"], in: .open)
          }
          picker.delegate = self
          picker.allowsMultipleSelection = false
          guard var presenter = self.window?.rootViewController ?? UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.rootViewController }).first else { throw CocoaError(.userCancelled) }
          while let presented = presenter.presentedViewController { presenter = presented }
          self.documentResult = result
          presenter.present(picker, animated: true)
        } catch { self.finishDocument(error: error, result: result) }
      case "readDocument", "writeDocument":
        self.documentQueue.async {
          do {
            guard let location = args["location"] as? String, location.hasPrefix("vex-document:ios:"), let bookmark = UserDefaults.standard.data(forKey: location) else { throw CocoaError(.fileReadNoPermission) }
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [], bookmarkDataIsStale: &stale)
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if call.method == "writeDocument" {
              guard let bytes = args["bytes"] as? FlutterStandardTypedData else { throw CocoaError(.fileWriteUnknown) }
              var coordinationError: NSError?
              var writeError: Error?
              NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
                do { try bytes.data.write(to: target, options: .atomic) } catch { writeError = error }
              }
              if let error = coordinationError { throw error }
              if let error = writeError { throw error }
              DispatchQueue.main.async { result(nil) }
            } else {
              let value = try self.readDocument(url, location: location)
              DispatchQueue.main.async { result(value) }
            }
          } catch { DispatchQueue.main.async { result(FlutterError(code: "document", message: error.localizedDescription, details: nil)) } }
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func readDocument(_ url: URL, location: String) throws -> [String: Any] {
    guard ["md", "markdown", "txt"].contains(url.pathExtension.lowercased()) else { throw CocoaError(.fileReadUnknown) }
    var bytes: Data?
    var readError: Error?
    var coordinationError: NSError?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { source in
      do {
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 128 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        bytes = try Data(contentsOf: source)
      } catch { readError = error }
    }
    if let error = coordinationError { throw error }
    if let error = readError { throw error }
    guard let data = bytes, data.count <= 128 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
    return ["location": location, "name": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: data)]
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = documentResult, let url = urls.first else { return }
    let isExport = exportFile != nil
    documentQueue.async {
      let access = url.startAccessingSecurityScopedResource()
      defer { if access { url.stopAccessingSecurityScopedResource() } }
      do {
        let location = "vex-document:ios:" + UUID().uuidString
        let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        var value = try self.readDocument(url, location: location)
        if !FileManager.default.isWritableFile(atPath: url.path) && !isExport {
          value.removeValue(forKey: "location")
        } else {
          UserDefaults.standard.set(bookmark, forKey: location)
        }
        DispatchQueue.main.async { self.documentResult = nil; result(value); self.clearExport() }
      } catch { DispatchQueue.main.async { self.finishDocument(error: error, result: result) } }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    documentResult?(nil)
    documentResult = nil
    clearExport()
  }

  private func finishDocument(error: Error, result: FlutterResult) {
    documentResult = nil
    clearExport()
    result(FlutterError(code: "document", message: error.localizedDescription, details: nil))
  }

  private func clearExport() {
    if let file = exportFile { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    exportFile = nil
  }
}
