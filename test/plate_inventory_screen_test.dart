import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/plate_inventory_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';

/// The plate rack editor. What matters here is that it opens on the standard
/// gym without anything having been configured, and that an edit turns that
/// standard rack into one of the user's own.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() {
    container.dispose();
    return db.close();
  });

  /// Pumps the screen. Reads hit real SQLite, which never completes under the
  /// faked clock of a widget test — so the container is primed inside
  /// `runAsync` and the tree is pumped afterwards.
  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      // Opens (and seeds) the database while there is still a real clock to do
      // it on. The screen itself does not wait for this — `plateSettingsProvider`
      // answers with the standard rack from the first frame.
      await db.watchPlateSetup().first;
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const PlateInventoryScreen(),
      ),
    ));
    await tester.pump();
  }

  /// Whatever is on disk right now, resolved the way the screen resolves it.
  Future<PlateSettings> stored(WidgetTester tester) async {
    late PlateSettings out;
    await tester.runAsync(() async {
      final raw = await db.watchPlateSetup().first;
      out = resolvePlateSettings(
          unit: 'kg', inventory: raw.inventory, barKg: raw.barKg);
    });
    return out;
  }

  testWidgets('opens on a standard gym nobody had to configure',
      (tester) async {
    await open(tester);

    expect(find.text('Bar weight'), findsOneWidget);
    expect(find.text('20 kg'), findsNWidgets(2),
        reason: 'the bar itself, and the pair of 20s in the rack');
    expect(find.text('25 kg'), findsOneWidget);
    expect(find.text('1.25 kg'), findsOneWidget,
        reason: 'and not "1.3 kg", which is not a plate anybody owns');
    expect(find.text('Add a plate size'), findsOneWidget);
  });

  testWidgets('adding a pair of plates writes the whole rack', (tester) async {
    await open(tester);

    // Two at a time: the + on the 25s.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    final rack = (await stored(tester)).plates;
    expect(rack.first, (kg: 25.0, count: 4));
    expect(rack, hasLength(7),
        reason: 'the rest of the standard rack came along with it');
  });

  testWidgets('and taking the last pair off drops the size', (tester) async {
    await open(tester);

    // The 25s start at one pair, so − is the last one.
    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    final rack = (await stored(tester)).plates;
    expect(rack.any((p) => p.kg == 25), isFalse);
    expect(rack, hasLength(6));
  });

  testWidgets('a plate size can be dropped entirely', (tester) async {
    await open(tester);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    final rack = (await stored(tester)).plates;
    expect(rack, hasLength(6));
    expect(rack.any((p) => p.kg == 25), isFalse);
  });

  testWidgets('the bar is edited in the unit on screen', (tester) async {
    await open(tester);

    await tester.tap(find.text('Bar weight'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect((await stored(tester)).barKg, 15);
  });
}
