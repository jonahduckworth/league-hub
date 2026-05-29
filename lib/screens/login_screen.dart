import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_glass.dart';
import '../widgets/auth_flow_widgets.dart';
import '../widgets/glass_form_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithEmail(email, password);
      ref.invalidate(currentUserProvider);
      // Router will redirect automatically via auth guard
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Sign in failed. Please try again.';
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.64),
      builder: (ctx) => AuthDialogSurface(
        title: 'Reset Password',
        message:
            'Enter your email address and we\'ll send you a link to reset your password.',
        controller: resetEmailController,
        onCancel: () => Navigator.pop(ctx),
        onSubmit: () async {
          final email = resetEmailController.text.trim();
          if (email.isEmpty) {
            _showError('Please enter your email address.');
            return;
          }
          try {
            await ref.read(authServiceProvider).sendPasswordResetEmail(email);
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              AppUtils.showSuccessSnackBar(
                  context, 'Password reset email sent. Check your inbox.');
            }
          } on FirebaseAuthException catch (e) {
            _showError(_authErrorMessage(e.code));
          } catch (e) {
            _showError('Failed to send reset email. Please try again.');
          }
        },
      ),
    ).whenComplete(resetEmailController.dispose);
  }

  void _showError(String message) {
    if (!mounted) return;
    AppUtils.showErrorSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFlowScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeroHeader(
            title: 'League Hub',
            subtitle: 'Sign in to manage your leagues',
          ),
          const SizedBox(height: 38),
          GlassTextFormField(
            controller: _emailController,
            labelText: 'Email',
            leadingIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          GlassTextFormField(
            controller: _passwordController,
            labelText: 'Password',
            leadingIcon: Icons.lock_outlined,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signIn(),
            suffixIcon: glassPasswordToggle(
              obscure: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: AuthTextLink(
              label: 'Forgot password?',
              onTap: _showForgotPasswordDialog,
            ),
          ),
          const SizedBox(height: 14),
          GlassSubmitButton(
            label: 'Sign In',
            isLoading: _isLoading,
            onTap: _isLoading ? null : _signIn,
          ),
          const SizedBox(height: 24),
          const AuthDivider(),
          const SizedBox(height: 24),
          AuthSecondaryButton(
            label: 'Create League',
            icon: Icons.emoji_events_outlined,
            onTap: () => context.push('/create-league'),
          ),
          const SizedBox(height: 12),
          Center(
            child: AuthTextLink(
              label: 'Accept Invitation',
              onTap: () => context.push('/accept-invite'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'League admins can invite managers and staff after setup.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppGlassColors.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
