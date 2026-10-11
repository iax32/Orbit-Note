// Headless native acceptance: exercise the exact shipping recognition engine.
// No desktop automation, account, network, or original files are involved.
#include "../windows/runner/ocr_channel.cpp"
#include <fstream>
#include <iostream>
#include <iterator>
int main(int argc, char** argv) {
  if (argc != 2) return 2;
  try {
    std::ifstream file(argv[1], std::ios::binary);
    std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(file)), {});
    auto value = Recognize(bytes);
    const auto& data = std::get<flutter::EncodableMap>(value);
    const auto& text = std::get<std::string>(data.at(flutter::EncodableValue("text")));
    const auto& lines = std::get<flutter::EncodableList>(data.at(flutter::EncodableValue("lines")));
    std::cout << text << "\nRegions: " << lines.size() << std::endl;
    return text.find("ORBIT") != std::string::npos && !lines.empty() ? 0 : 3;
  } catch (const winrt::hresult_error& e) { std::cerr << winrt::to_string(e.message()); return 4; }
  catch (const std::exception& e) { std::cerr << e.what(); return 5; }
}
