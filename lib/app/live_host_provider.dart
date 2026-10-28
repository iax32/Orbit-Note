import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/live_host.dart';

final liveHostProvider = Provider<OrbitLiveHost>((ref) {
  final host = OrbitLiveHost();
  ref.onDispose(host.dispose);
  return host;
});
