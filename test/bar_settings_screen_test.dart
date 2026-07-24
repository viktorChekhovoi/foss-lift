import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/bar_settings_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';

/// The default bar: what it opens on, and that it is typed in the unit on
/// screen and stored in kilograms.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> open(WidgetTester tester, {String unit = 'kg'}) async {
    await tester.runAsync(() async {
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      if (unit != 'kg') await db.setWeightUnit(unit);
      await db.watchPlateSetup().first;
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(kDefaultPalette),
        home: const BarSettingsScreen(),
      ),
    ));
    await tester.pump();
  }

  Future<double?> storedBar(WidgetTester tester) async {
    double? out;
    await tester.runAsync(() async {
      out = (await db.watchPlateSetup().first).barKg;
    });
    return out;
  }

  testWidgets('opens on the standard bar, unconfigured', (tester) async {
    await open(tester);

    expect(find.text('20 kg'), findsOneWidget);
    expect(find.text('the standard bar'), findsOneWidget);
    expect(await storedBar(tester), isNull,
        reason: 'showing a default is not the same as having stored one');
  });

  testWidgets('is typed in the unit on screen and kept in kilograms',
      (tester) async {
    await open(tester);

    await tester.tap(find.text('Bar weight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(await storedBar(tester), 15);
  });

  testWidgets('a pounds gym types 45 and gets a 45 lb bar', (tester) async {
    await open(tester, unit: 'lb');

    await tester.tap(find.text('Bar weight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '35');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(await storedBar(tester), closeTo(15.876, 0.001),
        reason: '35 lb in canonical kilograms');
  });
}
