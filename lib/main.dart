import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'router.dart';
import 'services/deep_links.dart';
import 'theme/app_theme.dart';
import 'widgets/resume_workout_bar.dart';
import 'widgets/tutorial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: FossLiftApp()));
}

/// The app root. A [ConsumerWidget] only so that it can watch
/// [reminderSyncProvider]: something has to hold that subscription for the
/// life of the app, and the root is the one widget alive on every screen.
class FossLiftApp extends ConsumerWidget {
  const FossLiftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reminderSyncProvider);
    final palette = ref.watch(activePaletteProvider);
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
      builder: (context, child) => DeepLinkListener(
        router: appRouter,
        child: TutorialOverlay(
          child: ResumeWorkoutOverlay(child: child!),
        ),
      ),
    );
  }
}
