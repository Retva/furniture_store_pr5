import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Следит за действиями пользователя и вызывает [onTimeout] после паузы.
/// За [warningBefore] до конца показывает предупреждение через [onWarning].
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.timeout,
    required this.warningBefore,
    required this.onTimeout,
    required this.onWarning,
    required this.onWarningCancel,
    this.onActivity,
    required this.child,
    this.enabled = true,
  });

  final Duration timeout;
  final Duration warningBefore;
  final VoidCallback onTimeout;
  final VoidCallback onWarning;
  final VoidCallback onWarningCancel;
  final VoidCallback? onActivity;
  final Widget child;
  final bool enabled;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _idleTimer;
  Timer? _warningTimer;
  bool _warningShown = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    if (widget.enabled) _restart();
  }

  @override
  void didUpdateWidget(InactivityWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _restart();
      } else {
        _cancel();
      }
    }
  }

  bool _onKey(KeyEvent event) {
    if (widget.enabled) _restart();
    return false;
  }

  void _restart() {
    if (!widget.enabled) return;
    widget.onActivity?.call();
    if (_warningShown) {
      _warningShown = false;
      widget.onWarningCancel();
    }
    _idleTimer?.cancel();
    _warningTimer?.cancel();

    final warnAt = widget.timeout - widget.warningBefore;
    if (warnAt > Duration.zero) {
      _warningTimer = Timer(warnAt, () {
        _warningShown = true;
        widget.onWarning();
      });
    }
    _idleTimer = Timer(widget.timeout, widget.onTimeout);
  }

  void _cancel() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();
    _idleTimer = null;
    _warningTimer = null;
    if (_warningShown) {
      _warningShown = false;
      widget.onWarningCancel();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
