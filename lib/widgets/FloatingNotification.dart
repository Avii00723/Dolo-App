import 'dart:async';
import 'package:flutter/material.dart';

class FloatingNotification {
  static OverlayEntry? _floatingOverlay;

  static void show(
    BuildContext context, {
    required bool isSuccess,
    required String title,
    required String subtitle,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dismiss any existing overlay
    dismiss();

    _floatingOverlay = OverlayEntry(
      builder: (context) => _FloatingNotificationWidget(
        isSuccess: isSuccess,
        title: title,
        subtitle: subtitle,
        onDismiss: dismiss,
      ),
    );

    Overlay.of(context).insert(_floatingOverlay!);

    // Auto-dismiss
    Timer(duration, dismiss);
  }

  static void dismiss() {
    _floatingOverlay?.remove();
    _floatingOverlay = null;
  }
}

class _FloatingNotificationWidget extends StatefulWidget {
  final bool isSuccess;
  final String title;
  final String subtitle;
  final VoidCallback onDismiss;

  const _FloatingNotificationWidget({
    required this.isSuccess,
    required this.title,
    required this.subtitle,
    required this.onDismiss,
  });

  @override
  State<_FloatingNotificationWidget> createState() =>
      _FloatingNotificationWidgetState();
}

class _FloatingNotificationWidgetState
    extends State<_FloatingNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse(from: 1.0);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        widget.isSuccess ? const Color(0xFF1A1A2E) : const Color(0xFF2D0A0A);
    final Color accentColor =
        widget.isSuccess ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final Color iconBgColor =
        widget.isSuccess ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final IconData iconData =
        widget.isSuccess ? Icons.check_rounded : Icons.error_outline_rounded;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withOpacity(0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.18),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Icon bubble
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconBgColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: iconBgColor.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(iconData, color: iconBgColor, size: 22),
                      ),
                      const SizedBox(width: 14),

                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Dismiss X button
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.5),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
