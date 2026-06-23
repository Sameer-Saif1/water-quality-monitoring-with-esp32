import 'package:flutter/material.dart';
import '../models/water_reading.dart';
import '../theme/app_theme.dart';

class StatusBanner extends StatelessWidget {
  final WaterStatus status;
  final bool isStale;
  final DateTime? lastUpdate;

  const StatusBanner({
    super.key,
    required this.status,
    required this.isStale,
    required this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    if (isStale) {
      return _Banner(
        color: AppColors.textMuted,
        icon: Icons.wifi_off_rounded,
        title: 'No recent data',
        subtitle: lastUpdate == null
            ? 'Waiting for first reading from the device'
            : 'Last update ${_timeAgo(lastUpdate!)}',
      );
    }

    switch (status) {
      case WaterStatus.good:
        return _Banner(
          color: AppColors.accent,
          icon: Icons.check_circle_rounded,
          title: 'Water quality normal',
          subtitle: 'All readings within healthy range',
        );
      case WaterStatus.warning:
        return _Banner(
          color: AppColors.warning,
          icon: Icons.warning_rounded,
          title: 'Outside normal range',
          subtitle: 'One or more readings need attention',
        );
      case WaterStatus.alert:
        return _Banner(
          color: AppColors.alert,
          icon: Icons.error_rounded,
          title: 'Water quality alert',
          subtitle: 'Reading is significantly out of range',
        );
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: AppText.body.copyWith(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
