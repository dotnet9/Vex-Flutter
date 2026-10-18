#include "flutter_window.h"

#include <optional>
#include <cstring>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "vex/clipboard",
          &flutter::StandardMethodCodec::GetInstance());
  clipboard_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != "writeHtml") {
          result->NotImplemented();
          return;
        }
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        const auto argument = [args](const char* name) -> const flutter::EncodableValue* {
          if (!args) return nullptr;
          const auto found = args->find(flutter::EncodableValue(name));
          return found == args->end() ? nullptr : &found->second;
        };
        const auto* rich_argument = argument("windowsHtml");
        const auto* text_argument = argument("text");
        const auto* bytes = rich_argument ? std::get_if<std::vector<uint8_t>>(rich_argument) : nullptr;
        const auto* text = text_argument ? std::get_if<std::string>(text_argument) : nullptr;
        if (!bytes || !text) {
          result->Error("clipboard", "Invalid clipboard content");
          return;
        }
        const int length = MultiByteToWideChar(CP_UTF8, 0, text->c_str(), -1,
                                             nullptr, 0);
        HGLOBAL rich = GlobalAlloc(GMEM_MOVEABLE, bytes->size() + 1);
        HGLOBAL plain = GlobalAlloc(GMEM_MOVEABLE, length * sizeof(wchar_t));
        void* rich_data = rich ? GlobalLock(rich) : nullptr;
        auto* plain_data = plain ? static_cast<wchar_t*>(GlobalLock(plain)) : nullptr;
        if (!rich_data || !plain_data) {
          if (rich_data) GlobalUnlock(rich);
          if (plain_data) GlobalUnlock(plain);
          if (rich) GlobalFree(rich);
          if (plain) GlobalFree(plain);
          result->Error("clipboard", "Cannot allocate clipboard content");
          return;
        }
        std::memcpy(rich_data, bytes->data(), bytes->size());
        static_cast<char*>(rich_data)[bytes->size()] = '\0';
        MultiByteToWideChar(CP_UTF8, 0, text->c_str(), -1, plain_data, length);
        GlobalUnlock(rich);
        GlobalUnlock(plain);
        if (!OpenClipboard(GetHandle())) {
          GlobalFree(rich);
          GlobalFree(plain);
          result->Error("clipboard_busy", "Clipboard is busy");
          return;
        }
        const UINT format = RegisterClipboardFormatW(L"HTML Format");
        bool ok = format != 0 && EmptyClipboard();
        if (ok && SetClipboardData(CF_UNICODETEXT, plain)) {
          plain = nullptr;  // Ownership passes to Windows only on success.
        } else {
          ok = false;
        }
        if (ok && SetClipboardData(format, rich)) {
          rich = nullptr;
        } else {
          ok = false;
        }
        CloseClipboard();
        if (rich) GlobalFree(rich);
        if (plain) GlobalFree(plain);
        if (ok) result->Success();
        else result->Error("clipboard", "Cannot write clipboard content");
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  clipboard_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
