import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class ToastData {
  const ToastData(this.message, this.onUndo);

  final String message;
  final VoidCallback? onUndo;
}

/// One toast at a time; auto-hides after 3.2 s.
class ToastController extends ChangeNotifier {
  ToastData? _current;
  bool _visible = false;
  Timer? _timer;

  /// The latest toast (kept while it fades out).
  ToastData? get current => _current;
  bool get visible => _visible;

  void show(String message, {VoidCallback? onUndo}) {
    _timer?.cancel();
    _current = ToastData(message, onUndo);
    _visible = true;
    _timer = Timer(Motion.toast, hide);
    notifyListeners();
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  void undo() {
    final action = _current?.onUndo;
    hide();
    action?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Makes the [ToastController] available below it.
class ToastScope extends InheritedWidget {
  const ToastScope({super.key, required this.controller, required super.child});

  final ToastController controller;

  static ToastController of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ToastScope>()!.controller;

  @override
  bool updateShouldNotify(ToastScope oldWidget) => controller != oldWidget.controller;
}

/// The dark pill itself. Place it above the bottom navigation.
class ToastView extends StatelessWidget {
  const ToastView({super.key, required this.controller});

  final ToastController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.current;
        final visible = controller.visible;
        final d = Motion.of(context, Motion.base);
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            duration: d,
            curve: Motion.curve,
            offset: visible ? Offset.zero : const Offset(0, .5),
            child: AnimatedOpacity(
              duration: d,
              opacity: visible ? 1 : 0,
              child: data == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      container: true,
                      liveRegion: visible,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(Sp.x16, 6, data.onUndo == null ? Sp.x16 : Sp.x4, 6),
                        decoration: const BoxDecoration(
                          color: AppColors.toastBg,
                          borderRadius: Rad.controlAll,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  data.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.secondary.copyWith(color: AppColors.onPrimary),
                                ),
                              ),
                            ),
                            if (data.onUndo != null)
                              Semantics(
                                button: true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: controller.undo,
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                    padding: const EdgeInsets.symmetric(horizontal: Sp.x12),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Undo',
                                      style: AppText.secondary.copyWith(
                                        color: AppColors.toastAction,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
