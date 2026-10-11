import 'package:flutter_test/flutter_test.dart';
import '../tool/note_performance_benchmark.dart' as checks;

void main() {
  test('indexed positions and footer retain lossless editing semantics', () {
    checks.runChecks();
  });
}
