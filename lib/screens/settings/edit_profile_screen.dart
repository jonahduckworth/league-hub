import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/league_branding.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';
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
  String? _loadedUserId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _syncControllers(AppUser? user) {
    if (!_initialized) {
      _initializeControllers(user);
      return;
    }

    if (user == null || user.id == _loadedUserId) return;
    if (_nameController.text.isNotEmpty || _emailController.text.isNotEmpty) {
      return;
    }

    _nameController.text = user.displayName;
    _emailController.text = user.email;
    _loadedUserId = user.id;
  }

  void _initializeControllers(AppUser? user) {
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _loadedUserId = user?.id;
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
    final user = ref.watch(currentUserProvider).valueOrNull;
    _syncControllers(user);
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context, extra: 28);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Edit Profile',
        leadingIcon: Icons.person_outline,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        actions: [
          _HeaderTextAction(
            label: 'Save',
            isLoading: _isLoading,
            onTap: _isLoading ? null : _save,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            topContentPadding,
            16,
            bottomContentPadding,
          ),
          children: [
            Center(
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AppGlassSurface(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(8),
                      radius: 52,
                      child: Center(
                        child: AvatarWidget(
                          name: user?.displayName ?? '',
                          imageUrl: user?.avatarUrl,
                          size: 84,
                          backgroundColor:
                              AppGlassColors.aqua.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppGlassColors.pageWarm,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppGlassColors.aqua.withValues(alpha: 0.34),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _isUploadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  color: AppGlassColors.aqua,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: AppGlassColors.ink,
                                size: 17,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _GlassTextFormField(
              controller: _nameController,
              labelText: 'Display Name',
              icon: Icons.person_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _GlassTextFormField(
              controller: _emailController,
              labelText: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
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
            _GlassTextFormField(
              initialValue: user?.roleLabel ?? '',
              labelText: 'Role',
              icon: Icons.badge_outlined,
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 22),
            AppGlassSurface(
              height: 58,
              padding: EdgeInsets.zero,
              radius: 22,
              onTap: _showChangePasswordDialog,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: AppGlassColors.aqua,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Change Password',
                    style: TextStyle(
                      color: AppGlassColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                controller: currentPasswordController,
                labelText: 'Current Password',
                icon: Icons.lock_outline,
              ),
              const SizedBox(height: 12),
              _GlassDialogField(
                controller: newPasswordController,
                labelText: 'New Password',
                icon: Icons.password_outlined,
              ),
              const SizedBox(height: 12),
              _GlassDialogField(
                controller: confirmPasswordController,
                labelText: 'Confirm New Password',
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
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
                      onTap: () async {
                        final newPass = newPasswordController.text;
                        final confirmPass = confirmPasswordController.text;
                        if (newPass.isEmpty || newPass.length < 6) {
                          AppUtils.showErrorSnackBar(context,
                              'Password must be at least 6 characters');
                          return;
                        }
                        if (newPass != confirmPass) {
                          AppUtils.showErrorSnackBar(
                              context, 'Passwords do not match');
                          return;
                        }
                        try {
                          final firebaseUser =
                              FirebaseAuth.instance.currentUser;
                          if (firebaseUser != null &&
                              firebaseUser.email != null) {
                            final cred = EmailAuthProvider.credential(
                              email: firebaseUser.email!,
                              password: currentPasswordController.text,
                            );
                            await firebaseUser
                                .reauthenticateWithCredential(cred);
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
                      child: const Center(
                        child: Text(
                          'Update',
                          style: TextStyle(
                            color: AppGlassColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }
}

class _HeaderTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _HeaderTextAction({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.58 : 1,
      child: AppGlassSurface(
        width: 64,
        height: 40,
        padding: EdgeInsets.zero,
        radius: 20,
        onTap: onTap,
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppGlassColors.aqua,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlassTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String labelText;
  final IconData icon;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  const _GlassTextFormField({
    required this.labelText,
    required this.icon,
    this.controller,
    this.initialValue,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final fieldColor = enabled ? AppGlassColors.ink : AppGlassColors.inkMuted;

    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 22,
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
        child: TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          enabled: enabled,
          readOnly: readOnly,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          cursorColor: AppGlassColors.aqua,
          style: TextStyle(
            color: fieldColor,
            fontSize: 16,
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
            prefixIcon: Icon(
              icon,
              color: enabled
                  ? AppGlassColors.inkSecondary
                  : AppGlassColors.inkMuted,
            ),
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            errorStyle: const TextStyle(
              color: AppGlassColors.rose,
              fontWeight: FontWeight.w700,
            ),
          ),
          validator: validator,
        ),
      ),
    );
  }
}

class _GlassDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;

  const _GlassDialogField({
    required this.controller,
    required this.labelText,
    required this.icon,
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
          obscureText: true,
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
