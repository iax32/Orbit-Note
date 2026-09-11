import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/workspace/workspace_shell.dart';
import 'orbit_theme.dart';
import 'orbit_components.dart';
import 'workspace_controller.dart';

class OrbitNoteApp extends ConsumerWidget {
  const OrbitNoteApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      workspaceProvider.select((_) {
        final c = ref.read(workspaceProvider.notifier);
        return (c.session.compact, c.session.motion);
      }),
    );
    final controller = ref.read(workspaceProvider.notifier);
    return MaterialApp(
      title: 'Orbit Note',
      debugShowCheckedModeBanner: false,
      theme: orbitDarkTheme(compact: controller.session.compact),
      themeAnimationDuration:
          controller.session.motion != 'normal' ||
              View.of(
                context,
              ).platformDispatcher.accessibilityFeatures.disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 160),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final reduced =
            controller.session.motion != 'normal' || media.disableAnimations;
        return OrbitMotionScope(
          preference: controller.session.motion,
          osReduced: media.disableAnimations,
          child: MediaQuery(
            data: media.copyWith(disableAnimations: reduced),
            child: child!,
          ),
        );
      },
      home: const WorkspaceShell(),
    );
  }
}
