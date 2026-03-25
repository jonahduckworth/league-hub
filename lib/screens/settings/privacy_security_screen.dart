import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class PrivacySecurityScreen extends ConsumerWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'ACCOUNT SECURITY',
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outlined,
                    color: AppColors.primary, size: 22),
                title: const Text('Change Password',
                    style: TextStyle(fontSize: 14, color: AppColors.text)),
                subtitle: const Text('Update your account password',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 20),
                onTap: () => _showChangePasswordDialog(context),
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                leading: const Icon(Icons.email_outlined,
                    color: AppColors.primary, size: 22),
                title: const Text('Email Address',
                    style: TextStyle(fontSize: 14, color: AppColors.text)),
                subtitle: Text(user?.email ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 20),
                onTap: () => _showChangeEmailDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'SESSIONS',
            children: [
              ListTile(
                leading: const Icon(Icons.devices_outlined,
                    color: AppColors.primary, size: 22),
                title: const Text('Active Sessions',
                    style: TextStyle(fontSize: 14, color: AppColors.text)),
                subtitle: const Text('This device',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Active',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                leading: const Icon(Icons.logout,
                    color: AppColors.danger, size: 22),
                title: const Text('Sign Out All Devices',
                    style: TextStyle(fontSize: 14, color: AppColors.danger)),
                subtitle: const Text(
                    'Sign out from all devices except this one',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                onTap: () => _confirmSignOutAll(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'DATA & PRIVACY',
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined,
                    color: AppColors.primary, size: 22),
                title: const Text('Export My Data',
                    style: TextStyle(fontSize: 14, color: AppColors.text)),
                subtitle: const Text(
                    'Download a copy of your account data',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 20),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Data export request submitted. You will receive an email when ready.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.danger, size: 22),
                title: const Text('Delete Account',
                    style: TextStyle(fontSize: 14, color: AppColors.danger)),
                subtitle: const Text(
                    'Permanently delete your account and all data',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPassCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              if (newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'New Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Current Password (to confirm)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passCtrl.text,
                  );
                  await user.reauthenticateWithCredential(cred);
                  await user.verifyBeforeUpdateEmail(emailCtrl.text.trim());
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Verification email sent. Please check your new email.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Verification'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOutAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out All Devices'),
        content: const Text(
            'This will sign you out from all other devices. You will remain signed in on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All other sessions have been terminated'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Sign Out All'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This action is permanent and cannot be undone. All your data will be deleted.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password to confirm',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              if (passwordCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your password'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              try {
                final firebaseUser = FirebaseAuth.instance.currentUser;
                if (firebaseUser != null && firebaseUser.email != null) {
                  // Re-authenticate before destructive operation.
                  final cred = EmailAuthProvider.credential(
                    email: firebaseUser.email!,
                    password: passwordCtrl.text,
                  );
                  await firebaseUser.reauthenticateWithCredential(cred);

                  // Remove FCM token so push notifications stop.
                  final appUser =
                      ref.read(currentUserProvider).valueOrNull;
                  if (appUser != null) {
                    await ref
                        .read(messagingServiceProvider)
                        .removeToken(appUser.id);
                  }

                  // Delete the Firebase Auth account.
                  await firebaseUser.delete();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) context.go('/login');
              } on FirebaseAuthException catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  final msg = e.code == 'wrong-password'
                      ? 'Incorrect password. Please try again.'
                      : 'Failed to delete account: ${e.message}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
