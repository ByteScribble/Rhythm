import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/clock.dart';
import 'data/store.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(systemBars);

  final store = AppStore(clock: const SystemClock(), storage: PrefsStorage());
  await store.load();
  // Check-ins made from notification buttons while the app was closed.
  await store.drainPendingActions();

  final reminders = LocalReminders(store);
  runApp(RhythmApp(store: store, reminders: reminders));
  // After the first frame is on its way: channel, launch details, scheduling.
  await reminders.init();
}
