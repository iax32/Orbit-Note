/// Statistics for native profile-mode engine timings. This is a benchmark
/// helper, not telemetry; empty measurements must stay visibly unavailable.
Map<String, Object?> durationStatistics(Iterable<int> microseconds) {
  final values = microseconds.where((v) => v >= 0).toList()..sort();
  if (values.isEmpty) {
    return {'count': 0, 'p50Ms': null, 'p95Ms': null, 'worstMs': null};
  }
  double percentile(double p) => values[(p * values.length).ceil() - 1] / 1000;
  return {
    'count': values.length,
    'p50Ms': percentile(.5),
    'p95Ms': percentile(.95),
    'worstMs': values.last / 1000,
  };
}

Map<String, Object?> summarizeFrames(
  List<Map<String, int>> frames, {
  required double budgetUs,
}) => {
  'frames': frames.length,
  'budgetMs': budgetUs / 1000,
  'build': durationStatistics(frames.map((f) => f['buildUs']!)),
  'raster': durationStatistics(frames.map((f) => f['rasterUs']!)),
  'totalSpan': durationStatistics(frames.map((f) => f['totalUs']!)),
  // UI and raster are pipelined. Adding them is not a frame-budget test.
  'buildOverBudget': frames.where((f) => f['buildUs']! > budgetUs).length,
  'rasterOverBudget': frames.where((f) => f['rasterUs']! > budgetUs).length,
};
