import 'package:flutter/widgets.dart';

/// A request, coming from a notification, to show something in the app.
class ReminderIntent {
  const ReminderIntent({required this.actId, required this.date, this.checkin = false, this.partial = false});

  final String actId;

  /// `yyyy-MM-dd` of the activity window.
  final String date;

  /// Open the Check-in sheet for the activity.
  final bool checkin;

  /// …in partial mode.
  final bool partial;
}

/// What the UI needs from the reminder system. The real implementation is
/// `LocalReminders` (services/notifications.dart); tests use [NoReminders].
abstract class Reminders extends ChangeNotifier {
  /// Whether the system lets the app post notifications; null = not known yet.
  bool? get notificationsAllowed;

  /// Whether exact alarms may be scheduled. When false, reminders can arrive
  /// a few minutes late.
  bool get exactAllowed;

  /// Set when a notification asks the app to open something; the shell
  /// consumes it and sets it back to null.
  ValueNotifier<ReminderIntent?> get intent;

  /// Asks for notification permission the first time the user adds an
  /// activity or template (never at cold start).
  Future<void> requestPermissionOnce();

  /// Asks for notification permission now (Settings switch).
  Future<void> requestPermission();

  Future<void> requestExactAlarms();

  /// Re-reads permission state (on resume).
  Future<void> refresh();
}

class NoReminders extends Reminders {
  @override
  bool? get notificationsAllowed => true;

  @override
  bool get exactAllowed => true;

  @override
  final ValueNotifier<ReminderIntent?> intent = ValueNotifier(null);

  @override
  Future<void> requestPermissionOnce() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> requestExactAlarms() async {}

  @override
  Future<void> refresh() async {}
}

class RemindersScope extends InheritedNotifier<Reminders> {
  const RemindersScope({super.key, required Reminders reminders, required super.child})
      : super(notifier: reminders);

  /// Subscribes the caller to permission changes.
  static Reminders of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RemindersScope>()!.notifier!;

  static Reminders read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RemindersScope>()!.notifier!;
}
