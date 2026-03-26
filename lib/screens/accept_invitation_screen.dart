import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/invitation.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/firestore_service.dart';
import '../services/authorized_firestore_service.dart';

class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key});

  @override
  ConsumerState<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState
    extends ConsumerState<AcceptInvitationScreen> {
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _lookingUp = false;
  bool _submitting = false;

  Invitation? _invitation;
  String? _lookupError;

  @override
  void dispose() {
    _tokenController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _lookupInvitation() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _lookingUp = true;
      _lookupError = null;
      _invitation = null;
    });

    try {
      final svc = FirestoreService();
      final invite = await svc.getInvitationByToken(token);
      if (!mounted) return;
      if (invite == null) {
        setState(() {
          _lookupError = 'No valid invitation found for that code. '
              'Please check the code and try again.';
          _lookingUp = false;
        });
      } else {
        setState(() {
          _invitation = invite;
          _lookingUp = false;
          if (invite.email.isNotEmpty) {
            // Pre-fill name if provided
            if (invite.displayName != null && invite.displayName!.isNotEmpty) {
              _nameController.text = invite.displayName!;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lookupError = 'Failed to look up invitation: $e';
          _lookingUp = false;
        });
      }
    }
  }

  Future<void> _createAccount() async {
    final invite = _invitation;
    if (invite == null) return;

    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty) {
      _showError('Please enter your display name.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final authSvc = ref.read(authServiceProvider);
      await authSvc.createAccountFromInvite(
        invite.email,
        password,
        name,
        invite,
      );

      // Mark invitation as accepted using authorized service
      final authorizedSvc = ref.read(authorizedFirestoreServiceProvider);
      await authorizedSvc.acceptInvitation(
        invite.orgId,
        invite.id,
        invitedAt: invite.createdAt,
      );

      if (mounted) context.go('/');
    } on PermissionDeniedException catch (e) {
      _showError('Permission denied: $e');
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } catch (e) {
      _showError('Failed to create account: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address.';
      default:
        return 'Failed to create account. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Accept Invitation'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Enter the invite code shared by your organization admin.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tokenController,
              autocorrect: false,
              enabled: _invitation == null,
              decoration: InputDecoration(
                labelText: 'Invite Code',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: _invitation != null
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : null,
              ),
            ),
            if (_lookupError != null) ...[
              const SizedBox(height: 8),
              Text(_lookupError!,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            if (_invitation == null)
              ElevatedButton(
                onPressed: _lookingUp ? null : _lookupInvitation,
                child: _lookingUp
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Look Up Invitation'),
              ),
            if (_invitation != null) ...[
              _buildInvitationPreview(_invitation!),
              const SizedBox(height: 24),
              const Text(
                'Create Your Account',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  hintText: _invitation!.email,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _createAccount,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Create Account',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationPreview(Invitation invite) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              const Text('Invitation Found',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          _PreviewRow(label: 'Email', value: invite.email),
          const SizedBox(height: 6),
          _PreviewRow(label: 'Role', value: invite.roleLabel),
          const SizedBox(height: 6),
          _PreviewRow(
              label: 'Invited by', value: invite.invitedByName),
          if (invite.hubIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            _PreviewRow(
                label: 'Hubs',
                value:
                    '${invite.hubIds.length} hub${invite.hubIds.length == 1 ? '' : 's'} assigned'),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text('$label:',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
        ),
      ],
    );
  }
}
