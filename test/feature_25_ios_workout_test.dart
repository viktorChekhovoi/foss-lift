import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/services/deep_links.dart';
import 'package:foss_lift/services/reminders.dart';
import 'package:foss_lift/services/rest_tone.dart';
import 'package:foss_lift/services/workout_shade.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/state/session_snapshot.dart';
import 'package:foss_lift/util/capabilities.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

class _Tone implements RestTone {
  int count = 0;
  @override
  Future<void> play() async => count++;
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  final pending = <int, Map>{};
  late Future<bool> Function() grant;
  late DateTime now;
  late _Tone tone;
  late ProviderContainer scope;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    now = DateTime.now().toUtc();
    calls = [];
    pending.clear();
    grant = () async => true;
    tone = _Tone();
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'requestPermissions':
          return await grant();
        case 'zonedSchedule':
          final alert = call.arguments as Map;
          pending[alert['id'] as int] = alert;
        case 'cancel':
          pending.remove(call.arguments);
        case 'pendingNotificationRequests':
          return pending.values.toList();
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(notifications, null);
    debugDefaultTargetPlatformOverride = null;
  });

  ProviderContainer phoneScope(AppDatabase db, {bool mirrorSession = false}) {
    final container = containerFor(
      db,
      mirrorSession: mirrorSession,
      overrides: [
        capabilitiesProvider.overrideWithValue(Capabilities.ios),
        clockProvider.overrideWithValue(() => now),
        appLocalizationsProvider.overrideWithValue(l10nFor()),
        appOnScreenProvider.overrideWithValue(() => true),
        restToneProvider.overrideWithValue(tone),
        pendingShadeActionsProvider.overrideWithValue(
          PendingShadeActions(read: () async => null, write: (_) async {}),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ActiveWorkoutController> start() async {
    final db = memoryDb();
    addTearDown(db.close);
    scope = phoneScope(db);
    final ctl = scope.read(activeWorkoutProvider.notifier);
    await ctl.start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
    return ctl;
  }

  List<Map> scheduled() => [
    for (final call in calls)
      if (call.method == 'zonedSchedule') call.arguments as Map,
  ];
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  const activity = MethodChannel('com.fosslift.foss_lift/workout_activity');
  Map? card;
  void showActivity(ProviderContainer phone) {
    messenger.setMockMethodCallHandler(activity, (call) async {
      if (call.method == 'sync') card = call.arguments as Map?;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(activity, null));
    phone.listen(workoutActivitySyncProvider, (_, _) {}, fireImmediately: true);
  }

  Future<void> tapControl(Map displayed, String action) async {
    final reply = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      activity.name,
      activity.codec.encodeMethodCall(
        MethodCall('performAction', {
          'session': displayed['session'],
          'target': displayed['target'],
          'action': action,
          'restEndsAt': displayed['restEndsAt'],
        }),
      ),
      reply.complete,
    );
    final envelope = await reply.future;
    expect(
      envelope,
      isNotNull,
      reason: 'The Live Activity can reach the session without a screen',
    );
    activity.codec.decodeEnvelope(envelope!);
  }

  test(
    'the island logs the displayed set, controls its rest, and ignores stale taps',
    () async {
      final ctl = await start();
      showActivity(scope);
      await scope.pump();
      await flush();
      final first = card!;
      expect((first['setButtons'] as List).map((b) => b['label']), [
        l10nFor().shadeDone,
        l10nFor().shadeMissed,
      ]);
      await tapControl(first, 'set_done');
      final rows = scope.read(activeWorkoutProvider)!.exercises.first.warmups;
      expect(rows.first.logged, rows.first.goal);
      final resting = card!;
      expect((resting['restButtons'] as List).map((b) => b['id']), [
        'rest_skip',
        'rest_sub',
        'rest_add',
      ]);
      final end = resting['restEndsAt'] as int;
      await tapControl(resting, 'rest_add');
      expect(card!['restEndsAt'], end + 15000);
      await tapControl(resting, 'rest_sub');
      expect(
        card!['restEndsAt'],
        end + 15000,
        reason: 'That rest has since changed',
      );
      await tapControl(card!, 'rest_sub');
      expect(card!['restEndsAt'], end);
      await tapControl(card!, 'rest_skip');
      expect(card!['restEndsAt'], isNull);
      await tapControl(first, 'set_done');
      expect(rows[1].logged, isNull);
      await tapControl({...card!, 'session': -1}, 'set_done');
      expect(rows[1].logged, isNull);
      await tapControl(card!, 'set_missed');
      expect(rows[1].logged, rows[1].goal - 1);
      final afterMiss = card!;
      now = DateTime.fromMillisecondsSinceEpoch(
        afterMiss['restEndsAt'] as int,
      ).add(const Duration(seconds: 1));
      await tapControl(afterMiss, 'set_done');
      expect(
        card!['target'],
        isNot(afterMiss['target']),
        reason: 'The expired rest exposes the next set while suspended',
      );
      expect(scheduled(), isNotEmpty);
      await ctl.discard();
    },
  );

  test(
    'a button wakes a cold session and persists the result before replying',
    () async {
      await start();
      showActivity(scope);
      await scope.pump();
      await flush();
      final displayed = card!;
      final db = scope.read(databaseProvider);
      await db.saveLiveSession(
        encodeSession(scope.read(activeWorkoutProvider)!),
        at: now,
      );
      final cold = phoneScope(db, mirrorSession: true);
      showActivity(cold);
      await tapControl(displayed, 'set_done');
      final saved = decodeSession((await db.loadLiveSession())!.payload)!;
      expect(saved.exercises.first.warmups.first.done, isTrue);
      expect(saved.restEndsAt, isNotNull);
      expect(
        pending.values.single['payload'],
        saved.restEndsAt!.millisecondsSinceEpoch.toString(),
      );
      await cold.read(activeWorkoutProvider.notifier).discard();
    },
  );

  test(
    'iPhone routine reminders can be scheduled and removed alongside a rest alert',
    () async {
      final ctl = await start();
      ctl.startRest(60, null);
      await flush();
      final rest = pending.keys.single;
      final service = ReminderService();
      expect(await service.requestPermission(), isTrue);
      final channel = (
        name: l10nFor().reminderChannelName,
        description: l10nFor().reminderChannelDescription,
      );
      await service.sync(
        [
          (
            reminder: RoutineReminder(
              routineId: 1,
              name: 'Push',
              scheduleDays: kEveryDayMask,
              reminderMinutes: 720,
            ),
            title: 'Push',
            body: l10nFor().reminderBody,
          ),
        ],
        channel: channel,
        now: now,
      );
      expect(pending.keys, unorderedEquals([rest, 1]));
      await service.sync([], channel: channel, now: now);
      expect(pending.keys, [rest]);
      await ctl.discard();
    },
  );

  test('many training reminders leave space for the rest sound', () async {
    final ctl = await start();
    ctl.startRest(60, null);
    await flush();
    final rest = pending.keys.single;
    final service = ReminderService();
    await service.sync(
      [
        for (var id = 70; id >= 1; id--)
          (
            reminder: RoutineReminder(
              routineId: id,
              name: 'Routine $id',
              scheduleDays: kEveryDayMask,
              reminderMinutes: 60 + id,
            ),
            title: 'Routine $id',
            body: l10nFor().reminderBody,
          ),
      ],
      channel: (
        name: l10nFor().reminderChannelName,
        description: l10nFor().reminderChannelDescription,
      ),
      now: DateTime(now.year, now.month, now.day + 2),
    );
    expect(
      pending.keys,
      unorderedEquals([rest, for (var id = 1; id <= 63; id++) id]),
    );
    await ctl.discard();
  });

  test(
    'iPhone offers a background rest alert and the Live Activity opens the workout',
    () {
      expect(Capabilities.ios.backgroundAlerts, isTrue);
      expect(routeForLink(Uri.parse('fosslift://session')), '/session');
    },
  );

  testWidgets(
    'logging a set on the board arms the alert and undoing the set cancels it',
    (tester) async {
      final ctl = (await tester.runAsync(start))!;
      await tester.pumpWidget(appUnder(scope, const WorkoutScreen()));
      final row = find.byKey(const ValueKey('w0-0-Bench Press'));
      final result = find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('set-result')),
      );
      await tester.ensureVisible(result);
      await tester.tap(result);
      await tester.pump();
      expect(pending.values.single['title'], l10nFor().restAlarmTitle);
      final set = scope
          .read(activeWorkoutProvider)!
          .exercises
          .first
          .warmups
          .first;
      final tapsToUndo = set.logged! + 1;
      for (var i = 0; i < tapsToUndo; i++) {
        await tester.tap(result);
        await tester.pump();
      }
      expect(set.logged, isNull);
      expect(pending, isEmpty);
      expect(tone.count, 0);
      await tester.runAsync(ctl.discard);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  for (final legacy in [false, true]) {
    test(
      legacy
          ? 'a rest saved by the shipped build gets its remaining alert'
          : 'a cold launch preserves the existing alert and its original deadline',
      () async {
        final ctl = await start();
        ctl.startRest(90, null);
        await flush();
        final session = scope.read(activeWorkoutProvider)!;
        final payload =
            jsonDecode(encodeSession(session)) as Map<String, dynamic>;
        if (legacy) {
          payload.remove('restEndsAt');
          pending.clear();
        }
        final db = scope.read(databaseProvider);
        await db.saveLiveSession(jsonEncode(payload), at: now);
        calls.clear();
        final restored = phoneScope(db, mirrorSession: true);
        await restored.read(activeWorkoutProvider.notifier).restore();
        await flush();
        expect(pending, hasLength(1));
        expect(restored.read(activeWorkoutProvider)!.restLeft, closeTo(90, 1));
        if (legacy) {
          expect(scheduled(), hasLength(1));
        } else {
          expect(
            restored
                .read(activeWorkoutProvider)!
                .restEndsAt!
                .millisecondsSinceEpoch,
            session.restEndsAt!.millisecondsSinceEpoch,
          );
          expect(scheduled(), isEmpty);
          expect(calls.where((call) => call.method == 'cancel'), isEmpty);
        }
        expect(tone.count, 0);
      },
    );
  }

  test(
    'the Lock Screen follows a workout, its rest deadline and the end of the session',
    () async {
      const activity = MethodChannel('com.fosslift.foss_lift/workout_activity');
      final updates = <MethodCall>[];
      messenger.setMockMethodCallHandler(activity, (call) async {
        if (call.method == 'sync') updates.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(activity, null));
      final ctl = await start();
      scope.listen(
        workoutActivitySyncProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await scope.pump();
      await flush();
      expect(updates.single.arguments['workout'], 'Push');
      expect(updates.single.arguments['movement'], contains('Bench Press'));
      expect(updates.single.arguments['restEndsAt'], isNull);
      final session = updates.single.arguments['session'];

      ctl.logNextAtGoal();
      await scope.pump();
      await flush();
      final remaining = scope.read(activeWorkoutProvider)!.restLeft;
      final end = now.add(Duration(seconds: remaining));
      expect(remaining, greaterThan(0));
      expect(updates.last.arguments['session'], session);
      expect(updates.last.arguments['restEndsAt'], end.millisecondsSinceEpoch);
      final count = updates.length;
      now = now.add(const Duration(seconds: 2));
      ctl.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await scope.pump();
      await flush();
      expect(
        updates.length,
        count,
        reason:
            'the Lock Screen counts from the same deadline while Dart sleeps',
      );

      await ctl.finish();
      await scope.pump();
      await flush();
      expect(updates.last.arguments, isNull);
      expect(calls.last.method, 'cancel');
    },
  );

  test(
    'one audible deadline survives suspension and returning does not ring twice',
    () async {
      final ctl = await start();
      ctl.startRest(60, null);
      await flush();
      final alert = scheduled().single;
      expect(alert['title'], l10nFor().restAlarmTitle);
      expect(alert['body'], contains('Bench Press'));
      expect(
        alert['platformSpecifics'],
        containsPair('sound', 'rest_done.wav'),
      );
      expect(alert['platformSpecifics'], containsPair('presentSound', true));
      expect(
        calls.singleWhere((c) => c.method == 'requestPermissions').arguments,
        containsPair('sound', true),
      );
      calls.clear();
      ctl.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 61));
      ctl.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(tone.count, 0);
      expect(
        calls,
        isEmpty,
        reason: 'a resumed timer must leave system delivery alone',
      );
    },
  );

  test('nudging and replacing move one alert, skipping cancels it', () async {
    final ctl = await start();
    ctl.startRest(90, null);
    await flush();
    ctl.nudgeRest(15);
    await flush();
    ctl.startRest(30, null);
    await flush();
    final alerts = scheduled();
    expect(alerts, hasLength(3));
    expect(alerts.map((a) => a['id']).toSet(), hasLength(1));
    final dates = alerts
        .map((a) => DateTime.parse(a['scheduledDateTime'] as String))
        .toList();
    expect(dates[1].difference(dates[0]).inSeconds, 15);
    expect(dates[2].difference(dates[0]).inSeconds, -60);
    calls.clear();
    ctl.stopRest();
    await flush();
    expect(calls.last.method, 'cancel');
    expect(calls.last.arguments, alerts.first['id']);
    expect(tone.count, 1);
  });

  test(
    'discard during the permission prompt cannot leave a pending alarm',
    () async {
      final ctl = await start();
      final answer = Completer<bool>();
      grant = () => answer.future;
      ctl.startRest(60, null);
      await flush();
      expect(calls.any((c) => c.method == 'requestPermissions'), isTrue);
      await ctl.discard();
      answer.complete(true);
      await flush();
      expect(scheduled(), isEmpty);
      expect(tone.count, 0);
    },
  );

  test('declining notifications still gives one in-app cue', () async {
    grant = () async => false;
    final ctl = await start();
    ctl.startRest(60, null);
    await flush();
    expect(calls.any((c) => c.method == 'requestPermissions'), isTrue);
    expect(scheduled(), isEmpty);
    now = now.add(const Duration(seconds: 61));
    ctl.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(tone.count, 1);
  });
}
