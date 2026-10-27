/// Logical pixels per 16ms tick. Stops outside the surface and is independent
/// of document size/zoom; callers clamp scroll positions and own cancellation.
double edgeScrollStep(
  double position,
  double extent, {
  double edge = 48,
  double maximum = 12,
}) {
  if (!position.isFinite ||
      !extent.isFinite ||
      extent <= 0 ||
      position < 0 ||
      position > extent) {
    return 0;
  }
  final band = edge.clamp(1, extent / 2 < 1 ? 1 : extent / 2);
  if (position < band) return -maximum * (1 - position / band);
  if (position > extent - band) {
    return maximum * (1 - (extent - position) / band);
  }
  return 0;
}
