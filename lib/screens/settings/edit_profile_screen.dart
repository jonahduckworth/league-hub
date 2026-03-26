import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/storage_service.dart';
import '../../widgets/avatar_widget.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _initControllers() {
    if (_initialized) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _initialized = true;
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    // Check permission — users can only edit their own photo.
    final permissionSvc = ref.read(permissionServiceProvider);
    if (!permissionSvc.canEditProfile(user, user.id)) {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'You can only change your own profile photo');
      }
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final bytes = await picked.readAsBytes();
      final storage = StorageService();
      final orgId = user.orgId ?? 'default';
      final path = 'orgs/$orgId/avatars/${user.id}.jpg';

      final downloadUrl = await storage.uploadBytes(
        bytes: bytes,
        path: path,
        contentType: 'image/jpeg',
      );

      await ref
          .read(firestoreServiceProvider)
          .updateUserFields(user.id, {'avatarUrl': downloadUrl});

      ref.invalidate(currentUserProvider);

      if (mounted) {
        AppUtils.showSuccessSnackBar(context, 'Profile photo updated');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Failed to upload photo: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();

      final updates = <String, dynamic>{};
      if (newName != user.displayName) updates['displayName'] = newName;
      if (newEmail != user.email) updates['email'] = newEmail;

      if (updates.isNotEmpty) {
        // For profile self-edits, use raw FirestoreService with permission check
        try {
          final permissionSvc = ref.read(permissionServiceProvider);
          final canEdit = permissionSvc.canEditProfile(user, user.id);
          if (!canEdit) {
            if (mounted) {
              AppUtils.showErrorSnackBar(
                  context, 'You do not have permission to edit this profile');
            }
            return;
          }
        } catch (e) {
          // If permission check fails, continue with attempt (may fail at Firestore)
        }

        await ref
            .read(firestoreServiceProvider)
            .updateUserFields(user.id, updates);

        // Update Firebase Auth display name if changed.
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null && newName != user.displayName) {
          await firebaseUser.updateDisplayName(newName);
        }

        ref.invalidate(currentUserProvider);

        if (mounted) {
          AppUtils.showSuccessSnackBar(context, 'Profile updated successfully');
        }
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Failed to update profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _initControllers();
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AvatarWidget(
                      name: user?.displayName ?? '',
                      imageUrl: user?.avatarUrl,
                      size: 80,
                      backgroundColor: AppColors.primary,
                    ),
                    if (_isUploadingPhoto)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 16),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: user?.roleLabel ?? '',
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                readOnly: true,
                enabled: false,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showChangePasswordDialog(),
                  icon: const Icon(Icons.lock_outlined),
                  label: const Text('Change Password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
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
              final newPass = newPasswordController.text;
              final confirmPass = confirmPasswordController.text;
              if (newPass.isEmpty || newPass.length < 6) {
                AppUtils.showErrorSnackBar(
                    context, 'Password must be at least 6 characters');
                return;
              }
              if (newPass != confirmPass) {
                AppUtils.showErrorSnackBar(context, 'Passwords do not match');
                return;
              }
              try {
                final firebaseUser = FirebaseAuth.instance.currentUser;
                if (firebaseUser != null && firebaseUser.email != null) {
                  final cred = EmailAuthProvider.credential(
                    email: firebaseUser.email!,
                    password: currentPasswordController.text,
                  );
                  await firebaseUser.reauthenticateWithCredential(cred);
                  await firebaseUser.updatePassword(newPass);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  AppUtils.showSuccessSnackBar(
                      context, 'Password updated successfully');
                }
              } catch (e) {
                if (mounted) {
                  AppUtils.showErrorSnackBar(
                      context, 'Failed to update password: $e');
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
