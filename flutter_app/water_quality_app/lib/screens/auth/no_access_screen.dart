import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

/// Shown when a user is successfully authenticated with Firebase Auth but
/// either has no Firestore profile document, or their profile is marked
/// `disabled`. This is the fail-closed gate: being authenticated is not
/// enough to use the app — there must also be an active profile.
class NoAccessScreen extends StatelessWidget {
  final AuthService authService;
  final String email;
  final bool isDisabled;

  const NoAccessScreen({
    super.key,
    required this.authService,
    required this.email,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ResponsiveContainer(
              maxWidth: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Icon(
                      isDisabled
                          ? Icons.block_rounded
                          : Icons.hourglass_top_rounded,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isDisabled ? 'Access disabled' : 'No access yet',
                    style: AppText.heading,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isDisabled
                        ? 'Your account ($email) has been disabled by an administrator.'
                        : 'Your account ($email) is signed in, but doesn\'t '
                          'have an active profile yet. Ask your administrator '
                          'to grant you access.',
                    style: AppText.body.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () => authService.signOut(),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
  }
}
