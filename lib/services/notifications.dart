import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/clock.dart';
import '../data/logic.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import 'reminders.dart';

const String _channelId = 'reminders';
const String _channelName = 'Reminders';
const String _channelDescription = 'Activity start, wrap-up and check-in reminders';
const String _smallIcon = 'ic_stat_rhythm';

/// Lets the background isolate nudge the running app to apply a queued
/// action straight away instead of waiting for the next 30 s tick.
const String _actionPort = 'rhythm.notificationActions';

/// Runs in a separate isolate when a notification button that doesn't open
/// the app is tapped (Yes / Complete / No / Skip) — even while the app is in
/// the foreground. It only queues the check-in; the main isolate applies it.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final now = const SystemClock().now();
  final action = pendingActionFor(actionId: response.actionId, payload: response.payload, now: now);
  if (action == null) return;
  await action.enqueue(PrefsStorage(), stamp: now);
  // The window is answered: drop its other reminders now, since the app may
  // not be running to reschedule (their IDs are deterministic).
  final plugin = FlutterLocalNotificationsPlugin();
  for (final kind in NotifKind.values) {
    try {
      await plugin.cancel(notificationId(action.actId, action.date, kind));
    } catch (_) {}
  }
  IsolateNameServer.lookupPortByName(_actionPort)?.send(null);
}

/// Local, offline reminders through `flutter_local_notifications` (§10).
class LocalReminders extends Reminders {
  LocalReminders(this.store);

  final AppStore store;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin? _android;

  bool _ready = false;
  bool? _allowed;
  bool _exact = true;
  int _seenRevision = -1;
  bool? _scheduledExact;
  Timer? _debounce;
  ReceivePort? _port;
  Future<void> _work = Future.value();

  @override
  final ValueNotifier<ReminderIntent?> intent = ValueNotifier(null);

  @override
  bool? get notificationsAllowed => _allowed;

  @override
  bool get exactAllowed => _exact;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings(_smallIcon)),
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
      );
      _android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await _android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ));

      final port = _port = ReceivePort();
      IsolateNameServer.removePortNameMapping(_actionPort);
      IsolateNameServer.registerPortWithName(port.sendPort, _actionPort);
      port.listen((_) => store.drainPendingActions());

      // Cold start from a notification tap or a button that opens the app.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) _onResponse(response);

      _ready = true;
      await refresh();
      store.addListener(_onStoreChanged);
      _seenRevision = store.revision;
      await _reschedule();
    } catch (e) {
      // The app works fully without reminders.
      debugPrint('Rhythm: notifications unavailable ($e)');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _port?.close();
    IsolateNameServer.removePortNameMapping(_actionPort);
    store.removeListener(_onStoreChanged);
    intent.dispose();
    super.dispose();
  }

  // ---------- permissions (§10.5) ----------

  @override
  Future<void> refresh() async {
    if (!_ready) return;
    try {
      final allowed = await _android?.areNotificationsEnabled();
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      final changed = allowed != _allowed || exact != _exact;
      _allowed = allowed;
      _exact = exact;
      if (changed) notifyListeners();
      // Resume also absorbs DST and time-zone changes.
      _queueReschedule();
    } catch (e) {
      debugPrint('Rhythm: could not read notification permissions ($e)');
    }
  }

  @override
  Future<void> requestPermissionOnce() async {
    // Not ready (still starting, or unavailable): leave it for the next time.
    if (!_ready || store.settings.askedNotifyPermission) return;
    await store.updateSettings(store.settings.copyWith(askedNotifyPermission: true));
    await requestPermission();
  }

  @override
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Rhythm: permission request failed ($e)');
    }
    await refresh();
  }

  @override
  Future<void> requestExactAlarms() async {
    if (!_ready) return;
    try {
      // Opens a system screen; `refresh` on resume picks up the answer.
      await _android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Rhythm: exact-alarm request failed ($e)');
    }
    await refresh();
  }

  // ---------- taps (§10.4) ----------

  /// Body taps and buttons that open the app ("Start", "Partially").
  void _onResponse(NotificationResponse response) {
    final target = _Payload.tryParse(response.payload);
    if (target == null) return;
    final actionId = response.actionId;
    if (actionId == null || actionId.isEmpty) {
      // A tap on a check-in for today opens its sheet; anything else, Today.
      final checkin = target.kind == NotifKind.end.name && target.date == store.todayKey;
      intent.value = ReminderIntent(actId: target.actId, date: target.date, checkin: checkin);
    } else if (actionId == NotifAction.partial) {
      intent.value =
          ReminderIntent(actId: target.actId, date: target.date, checkin: true, partial: true);
    } else if (actionId == NotifAction.start) {
      intent.value = ReminderIntent(actId: target.actId, date: target.date);
    } else {
      // Normally delivered to the background handler; handle it here too.
      final now = store.now;
      final action = pendingActionFor(actionId: actionId, payload: response.payload, now: now);
      if (action != null) {
        unawaited(action
            .enqueue(store.storage, stamp: now)
            .then((_) => store.drainPendingActions()));
      }
    }
  }

  // ---------- scheduling (§10.2, §10.3) ----------

  void _onStoreChanged() {
    if (store.revision == _seenRevision) return;
    _seenRevision = store.revision;
    _queueReschedule();
  }

  void _queueReschedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reschedule);
  }

  Future<void> _reschedule() {
    return _work = _work.then((_) async {
      if (!_ready) return;
      try {
        await _clearResolved();
        final plan = planNotifications(
          activities: store.activities,
          logs: store.logs,
          enabled: store.settings.notify,
          now: store.now,
        );
        final wanted = {for (final n in plan) n.id: n};
        final payloads = {for (final n in plan) n.id: _Payload.of(n).encode()};
        final modeChanged = _scheduledExact != _exact;

        // Cancel pending requests only (never `cancelAll`, which would also
        // clear notifications already on screen). Requests that are still
        // right — same id, text and payload (which includes the fire time) —
        // stay as they are.
        final keep = <int>{};
        for (final p in await _plugin.pendingNotificationRequests()) {
          final n = wanted[p.id];
          if (!modeChanged &&
              n != null &&
              p.payload == payloads[p.id] &&
              p.title == n.title &&
              p.body == n.body) {
            keep.add(p.id);
          } else {
            await _plugin.cancel(p.id);
          }
        }

        final mode = _exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;
        for (final n in plan) {
          if (keep.contains(n.id)) continue;
          try {
            await _plugin.zonedSchedule(
              n.id,
              n.title,
              n.body,
              // Same instant, expressed in UTC: no native time-zone lookup.
              tz.TZDateTime.from(n.at, tz.UTC),
              NotificationDetails(android: _details(n.kind)),
              androidScheduleMode: mode,
              payload: payloads[n.id],
            );
          } catch (e) {
            debugPrint('Rhythm: could not schedule "${n.title}" ($e)');
          }
        }
        _scheduledExact = _exact;
      } catch (e) {
        debugPrint('Rhythm: rescheduling failed ($e)');
      }
    });
  }

  /// Removes shown notifications whose activity now has a log or is gone.
  /// Android doesn't return a shown notification's payload, so they are
  /// matched by their deterministic IDs.
  Future<void> _clearResolved() async {
    final active = await _android?.getActiveNotifications() ?? const [];
    if (active.isEmpty) return;
    final live = liveNotificationIds(
      activities: store.activities,
      logs: store.logs,
      now: store.now,
    );
    for (final n in active) {
      final id = n.id;
      if (id != null && n.channelId == _channelId && !live.contains(id)) {
        await _plugin.cancel(id);
      }
    }
  }

  AndroidNotificationDetails _details(NotifKind kind) {
    // Buttons that only record an answer never open the app.
    AndroidNotificationAction quiet(String id, String title) => AndroidNotificationAction(
          id,
          title,
          showsUserInterface: false,
          cancelNotification: true,
        );
    AndroidNotificationAction opens(String id, String title) => AndroidNotificationAction(
          id,
          title,
          showsUserInterface: true,
          cancelNotification: true,
        );
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.primary,
      category: AndroidNotificationCategory.reminder,
      actions: switch (kind) {
        NotifKind.start => [
            opens(NotifAction.start, 'Start'),
            quiet(NotifAction.skip, 'Skip'),
          ],
        NotifKind.nearEnd => [quiet(NotifAction.done, 'Complete')],
        NotifKind.end => [
            quiet(NotifAction.done, 'Yes'),
            opens(NotifAction.partial, 'Partially'),
            quiet(NotifAction.skip, 'No'),
          ],
      },
    );
  }
}

/// Notification payload: which activity window it is about. `kind` and `at`
/// (fire time, ms since epoch) let a reschedule tell what is unchanged.
class _Payload {
  const _Payload(this.actId, this.date, this.kind, this.at);

  _Payload.of(PlannedNotification n)
      : this(n.actId, n.date, n.kind.name, n.at.millisecondsSinceEpoch);

  final String actId;
  final String date;
  final String? kind;
  final int? at;

  String encode() => jsonEncode({'actId': actId, 'date': date, 'kind': kind, 'at': at});

  static _Payload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final actId = j['actId'], date = j['date'], kind = j['kind'], at = j['at'];
      if (actId is! String || date is! String) return null;
      return _Payload(actId, date, kind is String ? kind : null, at is int ? at : null);
    } catch (_) {
      return null;
    }
  }
}
