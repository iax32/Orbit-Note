import 'package:flutter/foundation.dart';

class OrbitLiveHost extends ChangeNotifier {
  bool get supported => false;
  bool get busy => false;
  Uri? get endpoint => null;
  Uri? get localEndpoint => null;
  String? get ownerToken => null;
  String get status => 'Start live sharing on your Windows PC, then join here.';
  Uri? get setupAddress => null;
  Future<void> start({String route = 'relay', Uri? publicAddress}) async =>
      throw StateError(status);
  Future<void> stop() async {}
}
