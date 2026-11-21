import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'screens/shell.dart';
import 'services/reminders.dart';
import 'theme/tokens.dart';
import 'widgets/toast.dart';

/// Transparent system bars with dark icons (edge-to-edge).
const SystemUiOverlayStyle systemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

class RhythmApp extends StatefulWidget {
  const RhythmApp({super.key, required this.store, required this.reminders});

  final AppStore store;
  final Reminders reminders;

  @override
  State<RhythmApp> createState() => _RhythmAppState();
}

class _RhythmAppState extends State<RhythmApp> {
  final ToastController _toasts = ToastController();

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: RemindersScope(
        reminders: widget.reminders,
        child: ToastScope(
          controller: _toasts,
          child: MaterialApp(
            title: 'Rhythm',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: systemBars,
              // Layouts are checked up to a 1.3× font scale.
              child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
            ),
            home: const Shell(),
          ),
        ),
      ),
    );
  }
}
