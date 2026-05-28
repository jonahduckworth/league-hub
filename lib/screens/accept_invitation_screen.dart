import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils.dart';
import '../models/invitation.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../services/firestore_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/auth_flow_widgets.dart';
import '../widgets/glass_form_widgets.dart';

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
  final _emailController = TextEditingController();
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
    _emailController.dispose();
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
      _emailController.clear();
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
          _emailController.text = invite.email;
          if (invite.displayName != null && invite.displayName!.isNotEmpty) {
            _nameController.text = invite.displayName!;
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
    AppUtils.showErrorSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return AppGlassRouteBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTopBar(
              title: 'Accept Invitation',
              icon: Icons.mark_email_read_outlined,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppGlassSurface(
                      padding: const EdgeInsets.all(16),
                      radius: 22,
                      child: const Row(
                        children: [
                          Icon(
                            Icons.mail_outline,
                            color: AppGlassColors.aqua,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Enter the invite code shared by your league admin.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppGlassColors.inkSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassTextFormField(
                      controller: _tokenController,
                      labelText: 'Invite Code',
                      leadingIcon: Icons.key_outlined,
                      enabled: _invitation == null,
                      autocorrect: false,
                      suffixIcon: _invitation != null
                          ? const Icon(Icons.check_circle,
                              color: AppGlassColors.aqua)
                          : null,
                    ),
                    if (_lookupError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lookupError!,
                        style: const TextStyle(
                          color: AppGlassColors.rose,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_invitation == null)
                      GlassSubmitButton(
                        label: 'Look Up Invitation',
                        isLoading: _lookingUp,
                        onTap: _lookingUp ? null : _lookupInvitation,
                      ),
                    if (_invitation != null) ...[
                      _buildInvitationPreview(_invitation!),
                      const SizedBox(height: 24),
                      const GlassFormSectionLabel('Create your account'),
                      const SizedBox(height: 12),
                      GlassTextFormField(
                        controller: _nameController,
                        labelText: 'Display Name *',
                        leadingIcon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      GlassTextFormField(
                        controller: _emailController,
                        labelText: 'Email',
                        leadingIcon: Icons.email_outlined,
                        enabled: false,
                      ),
                      const SizedBox(height: 14),
                      GlassTextFormField(
                        controller: _passwordController,
                        labelText: 'Password *',
                        leadingIcon: Icons.lock_outlined,
                        obscureText: _obscurePassword,
                        suffixIcon: glassPasswordToggle(
                          obscure: _obscurePassword,
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassTextFormField(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm Password *',
                        leadingIcon: Icons.lock_outlined,
                        obscureText: _obscureConfirm,
                        suffixIcon: glassPasswordToggle(
                          obscure: _obscureConfirm,
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 22),
                      GlassSubmitButton(
                        label: 'Create Account',
                        isLoading: _submitting,
                        onTap: _submitting ? null : _createAccount,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationPreview(Invitation invite) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AppGlassSurface(
        padding: const EdgeInsets.all(16),
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: AppGlassColors.aqua, size: 20),
                SizedBox(width: 8),
                Text(
                  'Invitation Found',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppGlassColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PreviewRow(label: 'Email', value: invite.email),
            const SizedBox(height: 6),
            _PreviewRow(label: 'Role', value: invite.roleLabel),
            const SizedBox(height: 6),
            _PreviewRow(label: 'Invited by', value: invite.invitedByName),
            if (invite.hubIds.isNotEmpty) ...[
              const SizedBox(height: 6),
              _PreviewRow(
                  label: 'Hubs',
                  value:
                      '${invite.hubIds.length} hub${invite.hubIds.length == 1 ? '' : 's'} assigned'),
            ],
          ],
        ),
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
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppGlassColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
