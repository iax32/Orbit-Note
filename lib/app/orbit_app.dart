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
          c.session.motionOptions,
          c.session.fontFamily,
          c.session.documentFontFamily,
          c.session.monoFontFamily,
          c.session.codeFontSize,
          c.session.showLineNumbers,
          c.session.defaultCodeWrap,
          c.session.themePreset,
          c.session.followSystemAppearance,
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
      theme: orbitThemeForPreferences(
        controller.session.preferences,
        MediaQuery.platformBrightnessOf(context),
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
          options: controller.session.motionOptions,
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
