import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/drive_vault_scheduler.dart';

class DriveScheduleSettings extends ConsumerStatefulWidget {
  const DriveScheduleSettings({super.key});
  @override
  ConsumerState<DriveScheduleSettings> createState() =>
      _DriveScheduleSettingsState();
}

class _DriveScheduleSettingsState extends ConsumerState<DriveScheduleSettings> {
  bool opened = false;
  @override
  Widget build(BuildContext context) {
    if (!opened) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: OutlinedButton(
          onPressed: () => setState(() => opened = true),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule),
              SizedBox(width: 8),
              Flexible(child: Text('Manage scheduled Vault checks')),
            ],
          ),
        ),
      );
    }
    final c = ref.watch(driveVaultSchedulerProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 30),
          Text(
            'Scheduled Vault checks',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'In Upload/Download multiple Vaults, select “Keep these Vaults updated” to add successful transfers. Checks run only while Orbit is open. Individually paused Vaults stay paused; Shared Vault sessions suspend this schedule.',
          ),
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(c.status)),
          if (c.error.isNotEmpty) Text(c.error),
          if (c.busy || c.loading) const LinearProgressIndicator(),
          if (c.lastCheck != null)
            Text('Last check: ${c.lastCheck!.toLocal()}'),
          if (c.enabled && c.nextCheck != null)
            Text('Next check: ${c.nextCheck!.toLocal()}'),
          if (c.vaults.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: c.loading || c.configurationBlocked
                      ? null
                      : () => c.setEnabled(!c.enabled),
                  child: Text(
                    c.enabled
                        ? 'Pause scheduled checks'
                        : 'Resume scheduled checks',
                  ),
                ),
                TextButton(
                  onPressed: c.busy || c.loading || !c.enabled
                      ? null
                      : () => c.checkNow(force: true),
                  child: const Text('Check selected Vaults now'),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: c.minutes,
                    onChanged: c.busy || c.loading || c.configurationBlocked
                        ? null
                        : (value) {
                            if (value != null) c.setMinutes(value);
                          },
                    items: [
                      for (final n in [1, 5, 15])
                        DropdownMenuItem(
                          value: n,
                          child: Text('Every $n minute${n == 1 ? '' : 's'}'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          for (final vault in c.vaults)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vault.name),
                        Text(
                          vault.path,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        for (final job in c.jobs.where((j) => j.id == vault.id))
                          Text(job.message),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove ${vault.name} from schedule',
                    onPressed: c.busy || c.loading || c.configurationBlocked
                        ? null
                        : () => c.removeVault(vault.id),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          if (c.vaults.isNotEmpty || c.configurationBlocked)
            TextButton(
              onPressed: c.loading ? null : c.forget,
              child: const Text('Forget schedule · keep local and Drive files'),
            ),
        ],
      ),
    );
  }
}
