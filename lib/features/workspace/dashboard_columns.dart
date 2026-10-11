import 'package:flutter/material.dart';

/// Dashboard cards keep readable widths as the window or app zoom changes.
/// Accepts the same Expanded cards and spacing used by the wide layout.
class DashboardColumns extends StatelessWidget {
  const DashboardColumns({
    super.key,
    required this.children,
    this.minColumnWidth = 360,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });
  final List<Widget> children;
  final double minColumnWidth;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = children.where((child) => child is! SizedBox).toList();
      final columns =
          ((constraints.maxWidth + 12) /
                  (minColumnWidth *
                          (MediaQuery.textScalerOf(context).scale(14) / 14) +
                      12))
              .floor()
              .clamp(1, cards.length);
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final card in cards)
            SizedBox(width: width, child: card is Expanded ? card.child : card),
        ],
      );
    },
  );
}
