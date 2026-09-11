class OrbitPdfField {
  const OrbitPdfField({
    required this.page,
    required this.index,
    required this.name,
    required this.checkbox,
    required this.value,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  final int page, index;
  final String name;
  final bool checkbox;
  final Object value;
  final double left, top, right, bottom;
  String get id => '$page:$index';
}
