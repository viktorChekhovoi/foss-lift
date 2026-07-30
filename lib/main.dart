import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'router.dart';
import 'services/deep_links.dart';
import 'theme/app_theme.dart';
import 'util/text_scale.dart';
import 'widgets/resume_workout_bar.dart';
import 'widgets/tutorial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(ProviderScope(
    overrides: [openSessionProvider.overrideWithValue(_openSession)],
    child: const FossLiftApp(),
  ));
}

/// Raises the live board — what the shade's Done, Missed and Start buttons do
/// once the press reaches this isolate. Here rather than in `providers.dart` so
/// nothing in the provider layer has to know the router exists.
void _openSession() => appRouter.push('/session');

/// The app root. A [ConsumerWidget] only so that it can watch
/// [reminderSyncProvider]: something has to hold that subscription for the
/// life of the app, and the root is the one widget alive on every screen.
class FossLiftApp extends ConsumerWidget {
  const FossLiftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reminderSyncProvider);
    // Puts the live workout in the notification shade and keeps it current.
    ref.watch(workoutShadeSyncProvider);
    // Brings back a session Android killed the process out from under. Once, on
    // launch, before anything can be started on top of it.
    ref.watch(liveSessionRestoreProvider);
    // Collects any clip file a crash stranded. Once, on launch.
    ref.watch(orphanSweepProvider);
    final palette = ref.watch(activePaletteProvider);

    // Nothing is painted until the stored theme is known. `activePaletteProvider`
    // is synchronous and falls back to the system-brightness default while the
    // settings row is still on its way, so building the app now would paint a
    // frame of the *wrong* theme and then correct it. That is a flicker on every
    // cold launch even when nothing is stale — and a local SQLite read is a
    // frame or two, behind the launch screen, so there is nothing to wait
    // through. The holding frame is the ground colour the guess arrived at,
    // which is what the launch screen is showing anyway.
    if (!ref.watch(themeReadyProvider)) {
      return ColoredBox(color: palette.ground, child: const SizedBox.expand());
    }
    // Status-bar icons have to contrast with the app's ground: dark icons over a
    // light theme, light icons over a dark one. Re-applied here so switching to
    // a light theme flips them immediately rather than leaving them invisible.
    final light = palette.brightness == Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
    ));
    return MaterialApp.router(
      // The screens read AppColors directly, not Theme.of, so a theme change
      // has to force the whole tree to repaint. Keying by the palette's
      // fingerprint rebuilds everything against the freshly applied colours;
      // go_router keeps the current location across the rebuild.
      key: ValueKey(palette.signature),
      title: 'Foss Lift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(palette),
      routerConfig: appRouter,
      // Wraps every route so a collapsed workout can be resumed from anywhere,
      // and — on top of that — so the first-run tour can spotlight any of it.
      builder: (context, child) => MediaQuery(
        // The phone's text size, nudged by the user's own and held inside the
        // range every screen is swept at — see util/text_scale.dart.
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            resolveTextScale(
              system: MediaQuery.textScalerOf(context).scale(1),
              chosen: ref.watch(textScaleProvider).value ?? 1.0,
            ),
          ),
        ),
        child: DeepLinkListener(
          router: appRouter,
          child: TutorialOverlay(
            child: ResumeWorkoutOverlay(child: child!),
          ),
        ),
      ),
    );
  }
}
