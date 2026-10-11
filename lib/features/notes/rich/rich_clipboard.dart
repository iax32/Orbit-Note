import 'package:flutter/services.dart';
import '../../../platform/rich_clipboard.dart' as platform;

/// Publishes both the editable plain representation and a rich HTML
/// representation when the host supports multiple clipboard formats. Flutter's
/// stock Clipboard API remains the fallback when the host rejects rich data,
/// so rich copy never makes ordinary paste fail.
Future<bool> writeRichClipboard({
  required String plainText,
  required String html,
}) async {
  try {
    final accepted = await platform.writeRichClipboard(plainText, html);
    if (accepted == true) return true;
  } catch (_) {
    // The host may not implement rich clipboard formats.
  }
  try {
    await Clipboard.setData(ClipboardData(text: plainText));
    return true;
  } catch (_) {
    return false;
  }
}
