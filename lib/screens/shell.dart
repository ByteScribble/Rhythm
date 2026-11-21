import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/reminders.dart';
import '../theme/tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/toast.dart';
import 'insights_screen.dart';
import 'routine_screen.dart';
import 'sheets/checkin_sheet.dart';
import 'sheets/missed_sheet.dart';
import 'today_screen.dart';

/// Root of the app: bottom navigation, the 30-second ticker, lifecycle
/// handling and the missed-activity prompt.
class Shell extends StatefulWidget {
  const Shell({super.key});

  static const tickInterval = Duration(seconds: 30);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  static const _today = 0, _routine = 1, _insights = 2;

  int _tab = _today;
  Timer? _ticker;
  Timer? _firstPrompt;
  bool _prompting = false;
  AppStore? _store;
  Reminders? _reminders;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(Shell.tickInterval, (_) => _tick());
    // Let the first frame settle before asking about a missed activity.
    _firstPrompt = Timer(const Duration(milliseconds: 900), _maybePrompt);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store ??= StoreScope.read(context);
    if (_reminders == null) {
      _reminders = RemindersScope.read(context);
      _reminders!.intent.addListener(_onIntent);
      // A notification may have launched the app.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onIntent());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _firstPrompt?.cancel();
    _reminders?.intent.removeListener(_onIntent);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reminders?.refresh();
      _tick();
    } else if (state == AppLifecycleState.paused) {
      _store?.flush();
    }
  }

  Future<void> _tick() async {
    final store = _store;
    if (store == null) return;
    store.tick();
    await store.drainPendingActions();
    _maybePrompt();
  }

  bool get _onTop => ModalRoute.of(context)?.isCurrent ?? true;

  /// Asks about the most recently missed activity when Today is showing and
  /// nothing else is open (§6.4).
  Future<void> _maybePrompt() async {
    if (!mounted || _prompting || _tab != _today || !_onTop) return;
    final candidate = _store?.missedPrompt;
    if (candidate == null) return;
    _prompting = true;
    try {
      await showMissedSheet(context, candidate.activity.id);
    } finally {
      _prompting = false;
    }
  }

  /// A notification asked to show something: go to Today and, for a
  /// check-in, open its sheet.
  void _onIntent() {
    final intent = _reminders?.intent.value;
    if (intent == null || !mounted) return;
    _reminders!.intent.value = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _tab = _today);
    final store = _store!;
    if (!intent.checkin || store.activity(intent.actId) == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showCheckinSheet(
        context,
        intent.actId,
        date: intent.date == store.todayKey ? null : intent.date,
        partial: intent.partial,
      );
    });
  }

  void _select(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == _today) _maybePrompt();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      // Back: anywhere else → Today → leave the app.
      canPop: _tab == _today,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_today);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            Positioned.fill(
              // IndexedStack keeps hidden tabs' animations running, so turn
              // their tickers off here.
              child: IndexedStack(
                index: _tab,
                children: [
                  TickerMode(
                    enabled: _tab == _today,
                    child: TodayScreen(
                      onOpenRoutine: () => _select(_routine),
                      onOpenInsights: () => _select(_insights),
                    ),
                  ),
                  TickerMode(enabled: _tab == _routine, child: const RoutineScreen()),
                  TickerMode(enabled: _tab == _insights, child: const InsightsScreen()),
                ],
              ),
            ),
            Positioned(
              left: Sp.x16,
              right: Sp.x16,
              bottom: Sp.x20,
              child: Center(child: ToastView(controller: ToastScope.of(context))),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.fromLTRB(Sp.x28, Sp.x4, Sp.x28, safeBottom),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: Sp.x4,
              children: [
                _Tab(
                  icon: Icons.schedule_rounded,
                  label: 'Today',
                  selected: _tab == _today,
                  onTap: () => _select(_today),
                ),
                _Tab(
                  icon: Icons.format_list_bulleted_rounded,
                  label: 'Routine',
                  selected: _tab == _routine,
                  onTap: () => _select(_routine),
                ),
                _Tab(
                  icon: Icons.bar_chart_rounded,
                  label: 'Insights',
                  selected: _tab == _insights,
                  onTap: () => _select(_insights),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.text2;
    return Pressable(
      onTap: onTap,
      selected: selected,
      label: '$label tab',
      excludeChildSemantics: true,
      builder: (context, pressed) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, minHeight: 52),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: Sp.x4,
          children: [
            Icon(icon, size: 22, color: color),
            Text(
              label,
              maxLines: 1,
              style: AppText.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
