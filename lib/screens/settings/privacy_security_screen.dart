import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/design_system.dart';
import '../../core/league_branding.dart';
import '../../core/utils.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';

class PrivacySecurityScreen extends ConsumerWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Privacy & Security',
        leadingIcon: Icons.lock_outline,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          topContentPadding,
          16,
          bottomContentPadding,
        ),
        children: [
          _SettingsSection(
            title: 'ACCOUNT SECURITY',
            children: [
              _SecurityTile(
                icon: Icons.lock_outlined,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePasswordDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'DATA & PRIVACY',
            children: [
              _SecurityTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How League Hub handles your information',
                onTap: () => _openExternalLink(
                  context,
                  Uri.parse('https://leaguehub.ca/privacy'),
                ),
              ),
              const Divider(height: 1, color: AppGlassColors.border),
              _SecurityTile(
                icon: Icons.gavel_outlined,
                title: 'Terms & Community Guidelines',
                subtitle: 'Rules for safe and respectful communication',
                onTap: () => _openExternalLink(
                  context,
                  Uri.parse('https://leaguehub.ca/terms'),
                ),
              ),
              const Divider(height: 1, color: AppGlassColors.border),
              _SecurityTile(
                icon: Icons.support_agent_outlined,
                title: 'Support',
                subtitle: 'Get help with your account or organization',
                onTap: () => _openExternalLink(
                  context,
                  Uri.parse('https://leaguehub.ca/support'),
                ),
              ),
              const Divider(height: 1, color: AppGlassColors.border),
              _SecurityTile(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                subtitle: 'Permanently remove your League Hub account',
                titleColor: AppColors.danger,
                iconColor: AppColors.danger,
                onTap: () => _confirmDeleteAccount(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalLink(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      AppUtils.showErrorSnackBar(context, 'Unable to open ${uri.host}');
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final passwordController = TextEditingController();
    var deleting = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete your account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently removes your sign-in and personal profile. '
                'Messages and organization records may be retained without your active account where needed for league operations.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                enabled: !deleting,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  hintText: 'Confirm your identity',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: deleting
                  ? null
                  : () async {
                      final password = passwordController.text;
                      if (password.isEmpty) {
                        AppUtils.showErrorSnackBar(
                          context,
                          'Enter your current password',
                        );
                        return;
                      }
                      setState(() => deleting = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final email = user?.email;
                        if (user == null || email == null) {
                          throw FirebaseAuthException(
                            code: 'no-current-user',
                            message: 'No signed-in account was found.',
                          );
                        }
                        await user.reauthenticateWithCredential(
                          EmailAuthProvider.credential(
                            email: email,
                            password: password,
                          ),
                        );
                        await FirebaseFunctions.instanceFor(
                          region: 'us-central1',
                        ).httpsCallable('deleteOwnAccount').call<void>();
                        await FirebaseAuth.instance.signOut();
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } on FirebaseAuthException catch (error) {
                        setState(() => deleting = false);
                        if (context.mounted) {
                          AppUtils.showErrorSnackBar(
                            context,
                            error.code == 'wrong-password' ||
                                    error.code == 'invalid-credential'
                                ? 'That password is incorrect'
                                : error.message ??
                                    'Unable to verify your account',
                          );
                        }
                      } on FirebaseFunctionsException catch (error) {
                        setState(() => deleting = false);
                        if (context.mounted) {
                          AppUtils.showErrorSnackBar(
                            context,
                            error.message ?? 'Unable to delete your account',
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      barrierColor: Colors.black.withValues(alpha: 0.54),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AppGlassSurface(
          radius: 30,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(
                  color: AppGlassColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _GlassDialogField(
                controller: currentPassCtrl,
                labelText: 'Current Password',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              _GlassDialogField(
                controller: newPassCtrl,
                labelText: 'New Password',
                icon: Icons.password_outlined,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              _GlassDialogField(
                controller: confirmPassCtrl,
                labelText: 'Confirm New Password',
                icon: Icons.check_circle_outline,
                obscureText: true,
              ),
              const SizedBox(height: 22),
              _DialogActions(
                confirmLabel: 'Update',
                onCancel: () => Navigator.pop(ctx),
                onConfirm: () async {
                  if (newPassCtrl.text.length < 6) {
                    AppUtils.showErrorSnackBar(
                      context,
                      'Password must be at least 6 characters',
                    );
                    return;
                  }
                  if (newPassCtrl.text != confirmPassCtrl.text) {
                    AppUtils.showErrorSnackBar(
                      context,
                      'Passwords do not match',
                    );
                    return;
                  }
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null && user.email != null) {
                      final cred = EmailAuthProvider.credential(
                        email: user.email!,
                        password: currentPassCtrl.text,
                      );
                      await user.reauthenticateWithCredential(cred);
                      await user.updatePassword(newPassCtrl.text);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      AppUtils.showSuccessSnackBar(
                        context,
                        'Password updated successfully',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppUtils.showErrorSnackBar(context, 'Failed: $e');
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      currentPassCtrl.dispose();
      newPassCtrl.dispose();
      confirmPassCtrl.dispose();
    });
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppGlassColors.inkMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        AppGlassSurface(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SecurityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor ?? AppGlassColors.aqua, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? AppGlassColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppGlassColors.inkMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppGlassColors.inkMuted,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _GlassDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final bool obscureText;

  const _GlassDialogField({
    required this.controller,
    required this.labelText,
    required this.icon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 18,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppGlassColors.aqua,
            selectionColor: Color(0x3367E8D4),
            selectionHandleColor: AppGlassColors.aqua,
          ),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          cursorColor: AppGlassColors.aqua,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
            floatingLabelStyle: const TextStyle(
              color: AppGlassColors.aqua,
              fontWeight: FontWeight.w800,
            ),
            prefixIcon: Icon(icon, color: AppGlassColors.inkSecondary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _DialogActions({
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppGlassColors.aqua,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppGlassSurface(
            height: 48,
            padding: EdgeInsets.zero,
            radius: 18,
            onTap: onConfirm,
            child: Center(
              child: Text(
                confirmLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppGlassColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
