String suggestedExportName(String title, {DateTime? dated}) {
  var value = title
      .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (value.isEmpty) value = 'Orbit document';
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
    caseSensitive: false,
  ).hasMatch(value)) {
    value = 'Orbit $value';
  }
  if (value.length > 120) {
    var end = 120;
    if (value.codeUnitAt(end - 1) >= 0xd800 &&
        value.codeUnitAt(end - 1) <= 0xdbff) {
      end--;
    }
    value = value.substring(0, end).trimRight();
  }
  if (dated != null) {
    value =
        '$value — ${dated.year}-${dated.month.toString().padLeft(2, '0')}-${dated.day.toString().padLeft(2, '0')}';
  }
  return value;
}
