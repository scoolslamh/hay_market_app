import 'package:flutter/material.dart';

/// أنواع الإشعارات
enum NotificationType { success, error, warning, info }

/// نظام إشعارات احترافي يظهر في أعلى الشاشة مع Fade animation
class AppNotification {
  static OverlayEntry? _currentEntry;

  // ══════════════════════════════════════
  // الدالة الرئيسية
  // ══════════════════════════════════════
  static void show(
    BuildContext context,
    String message, {
    NotificationType type = NotificationType.success,
    Duration duration = const Duration(seconds: 2),
  }) {
    // إزالة الإشعار الحالي إن وجد
    _dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (_) => _NotificationWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: _dismiss,
      ),
    );

    overlay.insert(_currentEntry!);
  }

  static void _dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  // ══════════════════════════════════════
  // دوال مختصرة
  // ══════════════════════════════════════
  static void success(BuildContext context, String message) =>
      show(context, message, type: NotificationType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: NotificationType.error);

  static void warning(BuildContext context, String message) =>
      show(context, message, type: NotificationType.warning);

  static void info(BuildContext context, String message) =>
      show(context, message, type: NotificationType.info);
}

// ══════════════════════════════════════
// Widget الإشعار مع Animation
// ══════════════════════════════════════
class _NotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Fade animation
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // Slide من الأعلى للأسفل
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // ظهور
    _controller.forward();

    // اختفاء بعد المدة المحددة
    Future.delayed(widget.duration, () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════
  // ألوان وأيقونات حسب النوع
  // ══════════════════════════════════════
  Color get _backgroundColor {
    switch (widget.type) {
      case NotificationType.success:
        return const Color(0xFF2E7D32);
      case NotificationType.error:
        return const Color(0xFFC62828);
      case NotificationType.warning:
        return const Color(0xFFE65100);
      case NotificationType.info:
        return const Color(0xFF1565C0);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.error:
        return Icons.error_rounded;
      case NotificationType.warning:
        return Icons.warning_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            // السماح بالإغلاق بالسحب
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < 0) {
                _controller.reverse().then((_) => widget.onDismiss());
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _backgroundColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // الأيقونة
                    Icon(_icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    // النص
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Tajawal',
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // زر إغلاق
                    GestureDetector(
                      onTap: () =>
                          _controller.reverse().then((_) => widget.onDismiss()),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
