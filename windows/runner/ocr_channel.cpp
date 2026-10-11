#include "ocr_channel.h"
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>
#include <algorithm>
#include <stdexcept>
#include <string>

namespace {
flutter::EncodableValue Recognize(const std::vector<uint8_t>& bytes) {
  winrt::init_apartment(winrt::apartment_type::multi_threaded);
  struct Apartment { ~Apartment() { winrt::uninit_apartment(); } } apartment;
  using namespace winrt::Windows::Graphics::Imaging;
  using namespace winrt::Windows::Storage::Streams;
  using winrt::Windows::Media::Ocr::OcrEngine;
  auto engine = OcrEngine::TryCreateFromUserProfileLanguages();
  if (!engine) throw std::runtime_error("No OCR language is installed for your Windows profile. Add a supported language in Windows Settings, then retry.");
  InMemoryRandomAccessStream stream;
  DataWriter writer(stream);
  writer.WriteBytes(bytes);
  writer.StoreAsync().get();
  writer.DetachStream();
  stream.Seek(0);
  auto decoder = BitmapDecoder::CreateAsync(stream).get();
  const auto max_dimension = std::min<uint32_t>(2600, OcrEngine::MaxImageDimension());
  auto width = decoder.PixelWidth();
  auto height = decoder.PixelHeight();
  if (width == 0 || height == 0 || static_cast<uint64_t>(width) * height > 100000000) {
    throw std::runtime_error("Image dimensions exceed the recognition safety limit (100 megapixels).");
  }
  const auto scale = std::min(1.0, static_cast<double>(max_dimension) / std::max(width, height));
  BitmapTransform transform;
  transform.ScaledWidth(std::max<uint32_t>(1, static_cast<uint32_t>(width * scale)));
  transform.ScaledHeight(std::max<uint32_t>(1, static_cast<uint32_t>(height * scale)));
  auto bitmap = decoder.GetSoftwareBitmapAsync(BitmapPixelFormat::Bgra8,
      BitmapAlphaMode::Ignore, transform, ExifOrientationMode::IgnoreExifOrientation,
      ColorManagementMode::DoNotColorManage).get();
  auto result = engine.RecognizeAsync(bitmap).get();
  flutter::EncodableList lines;
  std::wstring text;
  for (const auto& line : result.Lines()) {
    if (line.Words().Size() == 0) continue;
    double left = bitmap.PixelWidth(), top = bitmap.PixelHeight(), right = 0, bottom = 0;
    for (const auto& word : line.Words()) {
      const auto box = word.BoundingRect();
      left = std::min(left, static_cast<double>(box.X));
      top = std::min(top, static_cast<double>(box.Y));
      right = std::max(right, static_cast<double>(box.X + box.Width));
      bottom = std::max(bottom, static_cast<double>(box.Y + box.Height));
    }
    if (!text.empty()) text += L'\n';
    const auto start = text.size();
    text += line.Text().c_str();
    const auto end = text.size();
    if (end > 2 * 1024 * 1024) throw std::runtime_error("Recognized text exceeds the safety limit.");
    const auto w = static_cast<double>(bitmap.PixelWidth());
    const auto h = static_cast<double>(bitmap.PixelHeight());
    left = std::clamp(left / w, 0.0, 1.0);
    top = std::clamp(top / h, 0.0, 1.0);
    right = std::clamp(right / w, left, 1.0);
    bottom = std::clamp(bottom / h, top, 1.0);
    lines.emplace_back(flutter::EncodableMap{
      {flutter::EncodableValue("start"), flutter::EncodableValue(static_cast<int64_t>(start))},
      {flutter::EncodableValue("end"), flutter::EncodableValue(static_cast<int64_t>(end))},
      {flutter::EncodableValue("x"), flutter::EncodableValue(left)},
      {flutter::EncodableValue("y"), flutter::EncodableValue(top)},
      {flutter::EncodableValue("width"), flutter::EncodableValue(right - left)},
      {flutter::EncodableValue("height"), flutter::EncodableValue(bottom - top)}});
  }
  bitmap.Close();
  stream.Close();
  return flutter::EncodableValue(flutter::EncodableMap{
    {flutter::EncodableValue("text"), flutter::EncodableValue(winrt::to_string(text))},
    {flutter::EncodableValue("language"), flutter::EncodableValue(winrt::to_string(engine.RecognizerLanguage().LanguageTag()))},
    {flutter::EncodableValue("lines"), flutter::EncodableValue(lines)}});
}
}

OcrChannel::OcrChannel(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window), channel_(messenger, "orbit_note/ocr", &flutter::StandardMethodCodec::GetInstance()) {
  channel_.SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "recognize") { result->NotImplemented(); return; }
    const auto* bytes = call.arguments() ? std::get_if<std::vector<uint8_t>>(call.arguments()) : nullptr;
    if (!bytes || bytes->empty() || bytes->size() > 100 * 1024 * 1024) {
      result->Error("invalid_image", "Expected image bytes up to 100 MiB."); return;
    }
    if (pending_) { result->Error("busy", "Recognition is already running."); return; }
    pending_ = std::move(result);
    if (!SetTimer(window_, kOrbitOcrTimer, 50, nullptr)) {
      pending_->Error("timer_failed", "Could not start recognition."); pending_.reset(); return;
    }
    try { work_ = std::async(std::launch::async, Recognize, *bytes); }
    catch (const std::exception& e) { KillTimer(window_, kOrbitOcrTimer); pending_->Error("ocr_failed", e.what()); pending_.reset(); }
  });
}

OcrChannel::~OcrChannel() {
  channel_.SetMethodCallHandler(nullptr);
  KillTimer(window_, kOrbitOcrTimer);
  if (work_.valid()) work_.wait();
  if (pending_) pending_->Error("closed", "Recognition closed with the window.");
}

void OcrChannel::Poll() {
  if (!pending_ || !work_.valid() || work_.wait_for(std::chrono::seconds(0)) != std::future_status::ready) return;
  KillTimer(window_, kOrbitOcrTimer);
  try { pending_->Success(work_.get()); }
  catch (const winrt::hresult_error& e) { pending_->Error("ocr_failed", winrt::to_string(e.message())); }
  catch (const std::exception& e) { pending_->Error("ocr_failed", e.what()); }
  pending_.reset();
}
