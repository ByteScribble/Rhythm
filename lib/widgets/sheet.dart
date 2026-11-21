import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'toast.dart';

/// Shows [builder]'s content in the app's bottom sheet (§9.5): top radius 28,
/// drag handle, swipe to dismiss, at most 92 % of the screen. Any toast is
/// hidden first. Completes with the popped value, or null when dismissed.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  ToastScope.of(context).hide();
  final reduced = Motion.reduced(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
    ),
    constraints: BoxConstraints(maxHeight: .92 * MediaQuery.sizeOf(context).height),
    sheetAnimationStyle: AnimationStyle(
      duration: reduced ? Duration.zero : Motion.sheetIn,
      reverseDuration: reduced ? Duration.zero : Motion.sheetOut,
      curve: Motion.curve,
      reverseCurve: Motion.exit,
    ),
    builder: (context) => _SheetBody(child: builder(context)),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Sp.x20,
        0,
        Sp.x20,
        Sp.x24 + mq.viewPadding.bottom + mq.viewInsets.bottom,
      ),
      child: child,
    );
  }
}

/// Standard vertical stack inside a sheet (20 px gaps).
class SheetColumn extends StatelessWidget {
  const SheetColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Sp.x20,
        children: children,
      );
}
