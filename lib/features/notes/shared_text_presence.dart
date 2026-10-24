import '../../app/orbit_theme.dart';
import 'package:flutter/rendering.dart';

Color sharedPeerColor(Map peer) {
  final identity = '${peer['session'] ?? peer['name']}';
  final hash = identity.codeUnits.fold<int>(
    0,
    (a, b) => (a * 31 + b) & 0x7fffffff,
  );
  return const [
    Color(0xff267a9e),
    Color(0xff8d4f9f),
    Color(0xffa15b32),
    Color(0xff337b5e),
    Color(0xff7c609f),
  ][hash % 5];
}

RenderEditable? sharedEditable(RenderObject? root) {
  if (root is RenderEditable) return root;
  RenderEditable? result;
  root?.visitChildren((child) {
    result ??= sharedEditable(child);
  });
  return result;
}

/// Awareness only: the painter never edits text, layout or native selection.
class SharedTextPresencePainter extends CustomPainter {
  SharedTextPresencePainter({
    required this.peers,
    required this.boxes,
    required this.caret,
    this.sourceCurrent,
    super.repaint,
  });
  final bool Function()? sourceCurrent;
  final List<Map<String, dynamic>> peers;
  final List<Rect> Function(TextSelection) boxes;
  final Rect? Function(int) caret;
  @override
  void paint(Canvas canvas, Size size) {
    if (sourceCurrent?.call() == false) return;
    for (final peer in peers) {
      final base = peer['textBase'], extent = peer['textExtent'];
      if (base is! int || extent is! int) continue;
      final color = sharedPeerColor(peer),
          selection = TextSelection(baseOffset: base, extentOffset: extent);
      for (final rect in boxes(selection)) {
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: .18));
      }
      final cursor = caret(extent);
      if (cursor == null ||
          !cursor.isFinite ||
          cursor.bottom < 0 ||
          cursor.top > size.height) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTWH(cursor.left, cursor.top, 2, cursor.height),
        Paint()..color = color,
      );
      final label = TextPainter(
        text: TextSpan(
          text: String.fromCharCodes(
            '${peer['name'] ?? 'Collaborator'}'.runes.take(24),
          ),
          style: TextStyle(
            fontSize: 10,
            color: OrbitContrast.inkOn(color),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 180);
      final left = cursor.left
          .clamp(0, (size.width - label.width - 8).clamp(0, double.infinity))
          .toDouble();
      final top = (cursor.top - label.height - 4)
          .clamp(0, double.infinity)
          .toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, label.width + 8, label.height + 4),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
      label.paint(canvas, Offset((left + 4).toDouble(), (top + 2).toDouble()));
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(SharedTextPresencePainter oldDelegate) => true;
}
