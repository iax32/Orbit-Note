#include "flutter_window.h"

#include <windows.h>

#include <cstring>
#include <iomanip>
#include <sstream>
#include <string>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

HGLOBAL GlobalUtf16(const std::string& utf8) {
  const auto size = MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (size < 0) return nullptr;
  std::wstring value(static_cast<size_t>(size), L'\0');
  if (size > 0 && MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                      static_cast<int>(utf8.size()),
                                      value.data(), size) == 0) {
    return nullptr;
  }
  const auto bytes = (value.size() + 1) * sizeof(wchar_t);
  auto memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
  if (memory == nullptr) return nullptr;
  auto* target = static_cast<wchar_t*>(GlobalLock(memory));
  if (target == nullptr) {
    GlobalFree(memory);
    return nullptr;
  }
  std::memcpy(target, value.c_str(), bytes);
  GlobalUnlock(memory);
  return memory;
}

std::string HtmlClipboardPayload(const std::string& html) {
  const std::string before =
      "<html><body><!--StartFragment-->";
  const std::string after = "<!--EndFragment--></body></html>";
  const std::string body = before + html + after;
  const auto start_fragment = before.size();
  const auto end_fragment = start_fragment + html.size();
  const std::string blank = "0000000000";
  const std::string template_header =
      "Version:0.9\r\nStartHTML:" + blank + "\r\nEndHTML:" + blank +
      "\r\nStartFragment:" + blank + "\r\nEndFragment:" + blank +
      "\r\n";
  const auto start = template_header.size();
  const auto start_html = start;
  const auto end = start + body.size();
  const auto fragment_start = start + start_fragment;
  const auto fragment_end = start + end_fragment;
  auto field = [](size_t value) {
    std::ostringstream out;
    out << std::setw(10) << std::setfill('0') << value;
    return out.str();
  };
  const std::string header =
      "Version:0.9\r\nStartHTML:" + field(start_html) + "\r\nEndHTML:" +
      field(end) + "\r\nStartFragment:" + field(fragment_start) +
      "\r\nEndFragment:" + field(fragment_end) + "\r\n";
  return header + body;
}

bool SetWindowsRichClipboard(HWND owner, const std::string& plain_text,
                             const std::string& html) {
  auto plain = GlobalUtf16(plain_text);
  if (plain == nullptr) return false;
  const auto format = RegisterClipboardFormat(L"HTML Format");
  if (format == 0) {
    GlobalFree(plain);
    return false;
  }
  const auto rich_text = HtmlClipboardPayload(html);
  auto rich = GlobalAlloc(GMEM_MOVEABLE, rich_text.size() + 1);
  if (rich == nullptr) {
    GlobalFree(plain);
    return false;
  }
  auto* rich_target = static_cast<char*>(GlobalLock(rich));
  if (rich_target == nullptr) {
    GlobalFree(plain);
    GlobalFree(rich);
    return false;
  }
  std::memcpy(rich_target, rich_text.c_str(), rich_text.size() + 1);
  GlobalUnlock(rich);
  if (!OpenClipboard(owner)) {
    GlobalFree(plain);
    GlobalFree(rich);
    return false;
  }
  EmptyClipboard();
  const auto plain_ok = SetClipboardData(CF_UNICODETEXT, plain) != nullptr;
  const auto rich_ok = SetClipboardData(format, rich) != nullptr;
  if (!plain_ok) GlobalFree(plain);
  if (!rich_ok) GlobalFree(rich);
  CloseClipboard();
  return plain_ok && rich_ok;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() { ocr_channel_.reset(); }

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
  ocr_channel_ = std::make_unique<OcrChannel>(flutter_controller_->engine()->messenger(), GetHandle());
  clipboard_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "orbit_note/clipboard",
      &flutter::StandardMethodCodec::GetInstance());
  clipboard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setRichText") {
          result->NotImplemented();
          return;
        }
        const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("invalid_arguments", "Expected clipboard text and HTML.");
          return;
        }
        const auto plain_it = arguments->find(flutter::EncodableValue("plainText"));
        const auto html_it = arguments->find(flutter::EncodableValue("html"));
        const auto* plain = plain_it == arguments->end()
                                ? nullptr
                                : std::get_if<std::string>(&plain_it->second);
        const auto* html = html_it == arguments->end()
                               ? nullptr
                               : std::get_if<std::string>(&html_it->second);
        if (plain == nullptr || html == nullptr) {
          result->Error("invalid_arguments", "Expected clipboard text and HTML.");
          return;
        }
        result->Success(flutter::EncodableValue(
            SetWindowsRichClipboard(GetHandle(), *plain, *html)));
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
  ocr_channel_.reset();
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
    case WM_TIMER:
      if (wparam == kOrbitOcrTimer && ocr_channel_) { ocr_channel_->Poll(); return 0; }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
