import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/workspace/workspace_shell.dart';
import 'orbit_theme.dart';
import 'app_zoom.dart';
import 'orbit_components.dart';
import 'workspace_controller.dart';

class OrbitNoteApp extends ConsumerWidget {
  const OrbitNoteApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      workspaceProvider.select((_) {
        final c = ref.read(workspaceProvider.notifier);
        return (
          c.session.compact,
          c.session.uiZoom,
          c.session.motion,
          c.session.fontFamily,
          c.session.documentFontFamily,
          c.session.monoFontFamily,
          c.session.themePreset,
          c.session.cornerStyle,
          c.session.accentColor,
          c.session.colorOverrides,
          c.session.customThemes,
        );
      }),
    );
    final controller = ref.read(workspaceProvider.notifier);
    return MaterialApp(
      title: 'Orbit Note',
      debugShowCheckedModeBanner: false,
      theme: orbitTheme(
        preset: controller.session.themePreset,
        compact: controller.session.compact,
        uiZoom: controller.session.uiZoom,
        fontFamily: controller.session.fontFamily,
        documentFontFamily: controller.session.documentFontFamily,
        monoFontFamily: controller.session.monoFontFamily,
        cornerStyle: controller.session.cornerStyle,
        accentColor: OrbitColors.accentFromPreset(
          controller.session.accentColor,
        ),
        colorOverrides: controller.session.colorOverrides,
        customPacks: controller.session.customThemes,
      ),
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
            child: AppZoom(
              zoom: controller.session.uiZoom,
              onChanged: (value) =>
                  controller.updateSession((s) => s.uiZoom = value),
              child: child!,
            ),
          ),
        );
      },
      home: const WorkspaceShell(),
    );
  }
}
