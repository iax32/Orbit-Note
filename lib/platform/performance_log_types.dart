abstract interface class PerformanceLogStore {
  bool get enabled;
  String? get path;
  Future<void> setEnabled(bool enabled);
  Future<void> append(String lines);
  Future<String> read();
}
