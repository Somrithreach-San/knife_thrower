import 'dart:async';
import 'package:flutter/material.dart';

/// Type of toast — controls icon and accent color.
enum GameToastType { info, success, error, warning }

/// Shows a styled mobile-game toast overlay from the top of the screen.
///
/// Usage:
/// ```dart
/// GameToast.show(context, 'Room code copied!', type: GameToastType.success);
/// ```
class GameToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    GameToastType type = GameToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Dismiss any existing toast immediately
    _dismiss();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _GameToastWidget(
        message: message,
        type: type,
        onDismiss: _dismiss,
      ),
    );

    _current = entry;
    overlay.insert(entry);

    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _GameToastWidget extends StatefulWidget {
  final String message;
  final GameToastType type;
  final VoidCallback onDismiss;

  const _GameToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_GameToastWidget> createState() => _GameToastWidgetState();
}

class _GameToastWidgetState extends State<_GameToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideY;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideY = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accentColor => switch (widget.type) {
        GameToastType.success => const Color(0xFF2CDFA2),
        GameToastType.error => const Color(0xFFFF5252),
        GameToastType.warning => const Color(0xFFFFB300),
        GameToastType.info => const Color(0xFF82B1FF),
      };

  IconData get _icon => switch (widget.type) {
        GameToastType.success => Icons.check_circle_rounded,
        GameToastType.error => Icons.error_rounded,
        GameToastType.warning => Icons.warning_amber_rounded,
        GameToastType.info => Icons.info_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 24,
      right: 24,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => FractionalTranslation(
          translation: Offset(0, _slideY.value),
          child: Opacity(opacity: _fade.value, child: child),
        ),
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                // Dark glassy game-style card
                color: const Color(0xFF0D1D36).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accent.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Icon(_icon, color: accent, size: 22),
                  const SizedBox(width: 10),
                  // Message
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // Dismiss X
                  const SizedBox(width: 8),
                  Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
