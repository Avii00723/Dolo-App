import 'package:flutter/material.dart';

/// Reusable widget to display backend/app unavailability message.
/// Can be used as:
/// - A full-screen overlay via [showBackendDownDialog()]
/// - An inline banner via [BackendDownBanner.banner()]
/// - A snackbar via [showBackendDownSnackBar()]
class BackendDownBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool showRetryButton;
  final Duration dismissAfter;

  const BackendDownBanner({
    Key? key,
    this.message = 'App is temporarily unavailable. It will resume shortly.',
    this.onRetry,
    this.showRetryButton = false,
    this.dismissAfter = const Duration(seconds: 0),
  }) : super(key: key);

  /// Creates a banner widget to embed in screens.
  static Widget banner({
    String message = 'App is temporarily unavailable. It will resume shortly.',
    VoidCallback? onRetry,
    bool showRetryButton = false,
  }) {
    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (showRetryButton && onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: banner(
        message: message,
        onRetry: onRetry,
        showRetryButton: showRetryButton,
      ),
    );
  }
}

/// Shows a full-screen dialog with backend-down message.
void showBackendDownDialog(
  BuildContext context, {
  String message = 'App is temporarily unavailable. It will resume shortly.',
  VoidCallback? onRetry,
  bool barrierDismissible = false,
}) {
  showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orange),
          SizedBox(width: 8),
          Text('App Unavailable'),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 14),
      ),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
      ],
    ),
  );
}

/// Shows a snackbar with backend-down message.
void showBackendDownSnackBar(
  BuildContext context, {
  String message = 'App is temporarily unavailable. It will resume shortly.',
  VoidCallback? onRetry,
  Duration duration = const Duration(seconds: 5),
}) {
  final snackBar = SnackBar(
    content: Row(
      children: [
        const Icon(Icons.cloud_off, color: Colors.white, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message),
        ),
      ],
    ),
    backgroundColor: Colors.grey[800],
    duration: duration,
    action: onRetry != null
        ? SnackBarAction(
            label: 'Retry',
            onPressed: onRetry,
          )
        : null,
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

/// Wraps a widget with a backend-down banner overlay.
/// Used to show banner at the top of a screen when backend is down.
class WithBackendDownBanner extends StatefulWidget {
  final Widget child;
  final bool isBackendDown;
  final String? customMessage;
  final VoidCallback? onRetry;

  const WithBackendDownBanner({
    Key? key,
    required this.child,
    this.isBackendDown = false,
    this.customMessage,
    this.onRetry,
  }) : super(key: key);

  @override
  State<WithBackendDownBanner> createState() => _WithBackendDownBannerState();
}

class _WithBackendDownBannerState extends State<WithBackendDownBanner> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isBackendDown)
          BackendDownBanner.banner(
            message: widget.customMessage ??
                'App is temporarily unavailable. It will resume shortly.',
            onRetry: widget.onRetry,
            showRetryButton: widget.onRetry != null,
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
