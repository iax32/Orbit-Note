import '../../../app/orbit_components.dart';
import '../../../app/orbit_theme.dart';
import 'package:flutter/material.dart';
import 'latex_templates.dart';

/// Dialog allowing the user to choose an academic starter template
class LatexTemplateDialog extends StatelessWidget {
  const LatexTemplateDialog({super.key});

  static Future<LatexTemplate?> show(BuildContext context) {
    return showOrbitDialog<LatexTemplate>(
      context: context,
      builder: (_) => const LatexTemplateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = LatexTemplates.all;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.functions_rounded,
            color: OrbitColors.of(context).accent,
            size: 24,
          ),
          SizedBox(width: 10),
          Text('New LaTeX Document'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select an academic starter template:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: templates.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final t = templates[idx];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: OrbitColors.of(
                          context,
                        ).accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.description_outlined,
                          color: OrbitColors.of(context).accent,
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      t.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      t.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, t),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
