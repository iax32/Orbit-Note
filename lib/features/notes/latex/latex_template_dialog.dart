import 'package:flutter/material.dart';
import 'latex_templates.dart';

/// Dialog allowing the user to choose an academic starter template
class LatexTemplateDialog extends StatelessWidget {
  const LatexTemplateDialog({super.key});

  static Future<LatexTemplate?> show(BuildContext context) {
    return showDialog<LatexTemplate>(
      context: context,
      builder: (_) => const LatexTemplateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = LatexTemplates.all;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.functions_rounded, color: Color(0xFF8B7CF6), size: 24),
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
                        color: const Color(0xFF8B7CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.description_outlined,
                          color: Color(0xFF8B7CF6),
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
