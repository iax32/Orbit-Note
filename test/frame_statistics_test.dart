import 'package:flutter_test/flutter_test.dart';
import '../tool/performance/frame_statistics.dart';

void main() {
  test(
    'empty or invalid timings remain unavailable rather than perfect zero',
    () {
      expect(durationStatistics([-1])['p95Ms'], isNull);
      expect(durationStatistics([])['count'], 0);
    },
  );
  test(
    'percentiles retain slow tails, exclude invalid data and do not mutate input',
    () {
      final values = [100000, 1000, -1, 2000, 3000];
      final stats = durationStatistics(values);
      expect(stats['count'], 4);
      expect(stats['p50Ms'], 2);
      expect(stats['p95Ms'], 100);
      expect(stats['worstMs'], 100);
      expect(values.first, 100000);
    },
  );
  test('pipelined build and raster budgets are evaluated separately', () {
    final result = summarizeFrames([
      {'buildUs': 10000, 'rasterUs': 10000, 'totalUs': 25000},
      {'buildUs': 17000, 'rasterUs': 18000, 'totalUs': 40000},
    ], budgetUs: 16667);
    expect(result['buildOverBudget'], 1);
    expect(result['rasterOverBudget'], 1);
    expect(result['frames'], 2);
  });
}
