#pragma once
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <future>
#include <memory>

// One serial background worker. Results return only on the window thread.
class OcrChannel {
 public:
  OcrChannel(flutter::BinaryMessenger* messenger, HWND window);
  ~OcrChannel();
  void Poll();
 private:
  HWND window_;
  flutter::MethodChannel<flutter::EncodableValue> channel_;
  std::future<flutter::EncodableValue> work_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> pending_;
};
constexpr UINT_PTR kOrbitOcrTimer = 0x4f4352;
