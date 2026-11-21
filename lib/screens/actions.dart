import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/reminders.dart';
import '../widgets/toast.dart';

/// User actions shared by several screens: each changes the store and
/// confirms with a toast.
///
/// Grab one with [AppActions.of] *before* awaiting a sheet or route, so the
/// result can still be applied if the widget that opened it has gone.
class AppActions {
  AppActions.of(BuildContext context)
      : store = StoreScope.read(context),
        toast = ToastScope.of(context),
        reminders = RemindersScope.read(context);

  final AppStore store;
  final ToastController toast;
  final Reminders reminders;

  /// Records a check-in and offers Undo, which puts back whatever was there.
  void logCheckin(String id, LogStatus status, {int? amount, String? note, String? date}) {
    final a = store.activity(id);
    if (a == null) return;
    final previous = store.logFor(id, date: date);
    unawaited(store.logStatus(id, status, amount: amount, note: note, date: date));
    if (status == LogStatus.done) HapticFeedback.lightImpact();
    toast.show(
      switch (status) {
        LogStatus.done => 'Nice — ${a.name} complete',
        LogStatus.partial => '${a.name} saved as partial',
        LogStatus.skipped => '${a.name} skipped',
      },
      onUndo: () => store.setLog(id, previous, date: date),
    );
  }

  void clearCheckin(String id, {String? date}) {
    unawaited(store.setLog(id, null, date: date));
    toast.show('Check-in cleared');
  }

  void startEarly(String id) {
    store.startEarly(id);
    toast.show('Started early — enjoy');
  }

  void addTemplate(Template template) {
    unawaited(store.addTemplate(template));
    toast.show('Template added');
    unawaited(reminders.requestPermissionOnce());
  }

  void duplicate(String id) {
    unawaited(store.duplicateActivity(id));
    toast.show('Duplicated');
  }

  void delete(String id) {
    final victim = store.activity(id);
    if (victim == null) return;
    unawaited(store.deleteActivity(id));
    toast.show('${victim.name} deleted', onUndo: () => store.restoreActivity(victim));
  }

  void loadSample() {
    unawaited(store.loadDemo());
    toast.show('Sample routine loaded');
  }

  void eraseAll() {
    unawaited(store.eraseAll());
    toast.show('All data erased');
  }
}
