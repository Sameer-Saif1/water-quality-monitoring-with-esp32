import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

class AddUserScreen extends StatefulWidget {
  final AuthService authService;
  const AddUserScreen({super.key, required this.authService});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  AppRole _role = AppRole.user;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;
  _CreatedAccount? _created;

  @override
  void initState() {
    super.initState();
    _passwordController.text = _generateTempPassword();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _generateTempPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
    final rand = Random.secure();
    return List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      await widget.authService.adminCreateUser(
        email: email,
        tempPassword: password,
        displayName: _nameController.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      setState(() {
        _created = _CreatedAccount(email: email, password: password);
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _messageFor(e.code));
    } catch (e) {
      setState(() => _error = 'Could not create the account. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'The temporary password is too weak.';
      default:
        return 'Could not create the account. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add user')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ResponsiveContainer(
              maxWidth: 480,
              child: _created != null
                  ? _SuccessView(account: _created!)
                  : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create an account for someone. They\'ll use this email and '
            'temporary password to sign in, then can change their password '
            'from the Profile tab.',
            style: AppText.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.textMuted),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: AppText.displayFontFamily,
            ),
            decoration: InputDecoration(
              labelText: 'Temporary password',
              prefixIcon: const Icon(Icons.password_rounded, color: AppColors.textMuted),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Regenerate',
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
                    onPressed: () => setState(
                        () => _passwordController.text = _generateTempPassword()),
                  ),
                  IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ],
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) return 'Use at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                RadioListTile<AppRole>(
                  value: AppRole.user,
                  groupValue: _role,
                  onChanged: (v) => setState(() => _role = v!),
                  activeColor: AppColors.accent,
                  title: const Text('User',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text('Can view live readings, history, and alerts',
                      style: AppText.caption),
                ),
                const Divider(height: 1),
                RadioListTile<AppRole>(
                  value: AppRole.admin,
                  groupValue: _role,
                  onChanged: (v) => setState(() => _role = v!),
                  activeColor: AppColors.accent,
                  title: const Text('Admin',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text('Can also manage users and access',
                      style: AppText.caption),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.alert.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.alert.withValues(alpha: 0.4)),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.alert)),
            ),
          ],

          const SizedBox(height: 22),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                  )
                : const Text('Create account'),
          ),
        ],
      ),
    );
  }
}

class _CreatedAccount {
  final String email;
  final String password;
  _CreatedAccount({required this.email, required this.password});
}

class _SuccessView extends StatelessWidget {
  final _CreatedAccount account;
  const _SuccessView({required this.account});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          margin: const EdgeInsets.only(bottom: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.accent, size: 32),
        ),
        const Text('Account created', style: AppText.heading, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Share these credentials with the user. They should change their '
          'password after signing in for the first time.',
          style: AppText.body.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _CredentialRow(label: 'Email', value: account.email),
        const SizedBox(height: 10),
        _CredentialRow(label: 'Temporary password', value: account.password, mono: true),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _CredentialRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.label),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: mono ? AppText.displayFontFamily : null,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textMuted),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}
