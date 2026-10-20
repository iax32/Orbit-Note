Future<Map<String, dynamic>> loadCodeToolSettings([String? location]) async =>
    {};
Future<void> saveCodeToolSettings(
  Map<String, dynamic> settings, {
  String? location,
}) async => throw UnsupportedError('Local code tools require desktop.');
