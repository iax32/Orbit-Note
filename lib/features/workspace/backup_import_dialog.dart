import 'package:flutter/material.dart';

import '../../app/orbit_components.dart';
import '../../application/backup_bundle.dart';
import '../../platform/android_vault_folders.dart';

/// Review a validated backup before opening a folder picker or writing files.
class BackupImportDialog extends StatelessWidget {
  const BackupImportDialog({super.key, required this.bundle});
  final BackupBundle bundle;

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: const Text('Add Vault'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(bundle.name),
        const SizedBox(height: 8),
        Text(
          '${bundle.files.length} files · ${(bundle.totalBytes / 1048576).toStringAsFixed(1)} MiB',
        ),
        const SizedBox(height: 16),
        const Text(
          'Review notices',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        if (bundle.warnings.isEmpty) const Text('None'),
        for (final warning in bundle.warnings)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(warning)),
        const SizedBox(height: 16),
        Text(
          usesAndroidVaultFolders
              ? 'Add this Vault to your library using its original name. Your source stays unchanged. Recovery journals are kept for review.'
              : 'Choose where to keep this Vault. Orbit uses its original name and adds a number if that folder already exists. Existing files stay unchanged. Recovery journals are kept for review.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(usesAndroidVaultFolders ? 'Add Vault' : 'Choose location'),
      ),
    ],
  );
}
