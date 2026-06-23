import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'auth/no_access_screen.dart';
import 'auth/splash_screen.dart';
import 'dashboard/home_shell.dart';

/// The single source of truth for what the user sees, based on two
/// independent streams:
///   1. Firebase Auth state (signed in / out)
///   2. The signed-in user's Firestore profile (role + active/disabled)
///
/// Access is fail-closed: being authenticated alone is NOT enough. A user
/// must be authenticated AND have an `active` profile document to reach
/// the app. No self-signup path exists anywhere in this widget tree.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return LoginScreen(authService: _authService);
        }

        // Signed in — now resolve their profile/access level.
        return StreamBuilder<AppUser?>(
          stream: _authService.currentUserProfileStream(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            // IMPORTANT: check for a stream error explicitly. Without this,
            // a genuine error (e.g. a Firestore permission-denied from a
            // misconfigured security rule) looks identical to "no profile
            // exists" and silently shows the generic no-access screen with
            // no indication anything actually went wrong.
            if (profileSnapshot.hasError) {
              return _ProfileLoadErrorScreen(
                authService: _authService,
                error: profileSnapshot.error.toString(),
              );
            }

            final profile = profileSnapshot.data;

            if (profile == null) {
              return NoAccessScreen(
                authService: _authService,
                email: user.email ?? '',
                isDisabled: false,
              );
            }

            if (!profile.isActive) {
              return NoAccessScreen(
                authService: _authService,
                email: user.email ?? '',
                isDisabled: true,
              );
            }

            return HomeShell(authService: _authService, profile: profile);
          },
        );
      },
    );
  }
}

/// Shown only when the profile stream genuinely errors (e.g. a Firestore
/// permission-denied) — distinct from NoAccessScreen, which is for the
/// normal/expected "no profile yet or disabled" case. Surfacing the raw
/// error here is deliberate: it's what makes a misconfigured security rule
/// debuggable instead of silently indistinguishable from "no access."
class _ProfileLoadErrorScreen extends StatelessWidget {
  final AuthService authService;
  final String error;

  const _ProfileLoadErrorScreen({
    required this.authService,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'Couldn\'t load your account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  error,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => authService.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
