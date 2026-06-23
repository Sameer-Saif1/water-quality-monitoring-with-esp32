import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';

class RoleBadge extends StatelessWidget {
  final AppRole role;
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == AppRole.admin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isAdmin ? AppColors.adminBadge : AppColors.accentDim)
            .withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isAdmin ? AppColors.adminBadge : AppColors.accentDim)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'USER',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: isAdmin ? AppColors.adminBadge : AppColors.accent,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final AccountStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == AccountStatus.active;
    final color = isActive ? AppColors.accent : AppColors.alert;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          isActive ? 'Active' : 'Disabled',
          style: AppText.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
