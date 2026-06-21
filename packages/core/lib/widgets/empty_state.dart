import 'package:flutter/material.dart';
import '../theme.dart';

/// Phase 5: Reusable empty / error / offline state widget.
/// Big icon + Hindi headline + sub-text + optional retry button.
/// Used by: home (no active ride), search (no drivers), and after errors.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final bool isError;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.isError = false,
  });

  /// Convenience: standard "no internet" state.
  factory EmptyState.noInternet({VoidCallback? onRetry}) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'इंटरनेट नहीं है',
        subtitle: 'नेट चेक करें और दोबारा कोशिश करें',
        actionLabel: onRetry == null ? null : 'दोबारा कोशिश करें',
        onAction: onRetry,
        iconColor: Colors.red.shade400,
      );

  /// Convenience: standard "nothing here" state.
  factory EmptyState.nothing({
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      EmptyState(
        icon: Icons.inbox_rounded,
        title: title,
        subtitle: subtitle,
        actionLabel: actionLabel,
        onAction: onAction,
        iconColor: muted,
      );

  /// Convenience: standard error state.
  factory EmptyState.error({
    required String message,
    VoidCallback? onRetry,
  }) =>
      EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'कुछ गड़बड़ हो गई',
        subtitle: message,
        actionLabel: onRetry == null ? null : 'दोबारा कोशिश करें',
        onAction: onRetry,
        iconColor: Colors.red.shade400,
        isError: true,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (iconColor ?? blue).withOpacity(0.10),
              ),
              child: Icon(icon, size: 48, color: iconColor ?? blue),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError ? Colors.red.shade700 : ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 14, height: 1.4),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A subtle banner shown at the top of the screen when offline.
/// Drops in via [Scaffold.body] wrapper.
class OfflineBanner extends StatelessWidget {
  final bool isOffline;
  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    return Material(
      color: Colors.red.shade600,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'इंटरनेट नहीं है — कुछ काम नहीं होगा',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
