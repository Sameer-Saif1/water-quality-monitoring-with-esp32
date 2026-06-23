import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/responsive_container.dart';
import 'add_user_screen.dart';

class UserManagementScreen extends StatelessWidget {
  final AuthService authService;
  final String currentAdminUid;

  const UserManagementScreen({
    super.key,
    required this.authService,
    required this.currentAdminUid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add user'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddUserScreen(authService: authService),
            ),
          );
        },
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: authService.allUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Couldn\'t load users.\n${snapshot.error}',
                style: AppText.body.copyWith(color: AppColors.alert),
                textAlign: TextAlign.center,
              ),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Text('No users yet. Tap "Add user" to invite someone.',
                  style: AppText.body.copyWith(color: AppColors.textMuted)),
            );
          }

          return Center(
            child: ResponsiveContainer(
              maxWidth: 760,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final u = users[i];
                  final isSelf = u.uid == currentAdminUid;
                  return _UserTile(
                    user: u,
                    isSelf: isSelf,
                    onToggleStatus: isSelf
                        ? null
                        : () => authService.setUserStatus(
                              u.uid,
                              u.isActive
                                  ? AccountStatus.disabled
                                  : AccountStatus.active,
                            ),
                    onToggleRole: isSelf
                        ? null
                        : () => authService.setUserRole(
                              u.uid,
                              u.isAdmin ? AppRole.user : AppRole.admin,
                            ),
                    onDelete: isSelf
                        ? null
                        : () => _confirmDelete(context, authService, u),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AuthService authService,
    AppUser user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove user?', style: AppText.title),
        content: Text(
          'This removes ${user.email} from the app\'s user list. '
          'Their sign-in will no longer work in the app. This can\'t be undone here.',
          style: AppText.body.copyWith(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: AppColors.alert)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authService.deleteUserProfile(user.uid);
    }
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final bool isSelf;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onToggleRole;
  final VoidCallback? onDelete;

  const _UserTile({
    required this.user,
    required this.isSelf,
    this.onToggleStatus,
    this.onToggleRole,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accentDim,
            child: Text(
              (user.displayName.isNotEmpty ? user.displayName : user.email)[0]
                  .toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName.isNotEmpty
                            ? user.displayName
                            : user.email,
                        style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text('(you)', style: AppText.caption),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(user.email,
                    style: AppText.caption, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RoleBadge(role: user.role),
                    const SizedBox(width: 8),
                    StatusBadge(status: user.status),
                  ],
                ),
              ],
            ),
          ),
          if (!isSelf)
            PopupMenuButton<String>(
              color: AppColors.surfaceRaised,
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                switch (value) {
                  case 'toggle_status':
                    onToggleStatus?.call();
                    break;
                  case 'toggle_role':
                    onToggleRole?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Text(
                    user.isActive ? 'Disable access' : 'Enable access',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_role',
                  child: Text(
                    user.isAdmin ? 'Remove admin' : 'Make admin',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Remove user', style: TextStyle(color: AppColors.alert)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
