/// A readable portable directory name. This never changes the Vault manifest
/// or identity, and never treats a display name as a filesystem path.
String vaultFolderName(String name) {
  var value = String.fromCharCodes(name.runes.take(72))
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'[. ]+$'), '');
  if (value.isEmpty || value == '.' || value == '..') value = 'Vault';
  if (RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
    caseSensitive: false,
  ).hasMatch(value)) {
    value = 'Vault $value';
  }
  return value;
}
