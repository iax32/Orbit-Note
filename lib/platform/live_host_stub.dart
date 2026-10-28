import 'package:flutter/foundation.dart';

class OrbitLiveHost extends ChangeNotifier {
  bool get supported => false;
  bool get busy => false;
  Uri? get endpoint => null;
  Uri? get localEndpoint => null;
  String? get ownerToken => null;
  String get status => 'Start live sharing on your Windows PC, then join here.';
  Future<void> start() async => throw StateError(status);
  Future<void> stop() async {}
}
