import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/league_branding.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../services/permission_service.dart';
import '../models/policy.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/confirmation_dialog.dart';
import 'viewers/image_viewer_screen.dart';
import 'viewers/pdf_viewer_screen.dart';

enum PolicyViewerType {
  image,
  pdf,
  native,
}

const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
const _pdfExts = {'pdf'};

PolicyViewerType policyViewerTypeForExt(String ext) {
  final normalized = ext.toLowerCase();
  if (_imageExts.contains(normalized)) return PolicyViewerType.image;
  if (_pdfExts.contains(normalized)) return PolicyViewerType.pdf;
  return PolicyViewerType.native;
}

String extractPolicyExtensionFromUrl(String url) {
  try {
    final path = Uri.parse(url).path;
    final lastDot = path.lastIndexOf('.');
    if (lastDot != -1) return path.substring(lastDot + 1);
  } catch (_) {}
  return '';
}

class PolicyDetailScreen extends ConsumerStatefulWidget {
  final String policyId;

  const PolicyDetailScreen({super.key, required this.policyId});

  @override
  ConsumerState<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends ConsumerState<PolicyDetailScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _isDeleting = false;
  bool _isOpeningPolicy = false;

  /// Opens the policy in-app for supported types and uses native preview
  /// for other policy formats after downloading them locally.
  Future<void> _openPolicy(String url,
      {String? fileType, String? title}) async {
    final ext = (fileType ?? extractPolicyExtensionFromUrl(url)).toLowerCase();
    final viewerType = policyViewerTypeForExt(ext);

    if (viewerType == PolicyViewerType.image) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageViewerScreen(
            imageUrl: url,
            title: title ?? 'Image',
          ),
        ),
      );
      return;
    }

    if (viewerType == PolicyViewerType.pdf) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            pdfUrl: url,
            title: title ?? 'PDF',
          ),
        ),
      );
      return;
    }

    await _openWithNativePreview(
      url,
      fileType: ext,
      title: title ?? 'Policy',
    );
  }

  Future<void> _openWithNativePreview(
    String sourceUrl, {
    required String fileType,
    required String title,
  }) async {
    if (_isOpeningPolicy) return;

    setState(() => _isOpeningPolicy = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final extension = fileType.isEmpty ? 'bin' : fileType;
      final baseName = title.replaceAll(RegExp(r'[^\w\-. ]'), '_');
      final fileName = baseName.toLowerCase().endsWith('.$extension')
          ? baseName
          : '$baseName.$extension';
      final filePath = '${tempDir.path}/$fileName';

      await Dio().download(sourceUrl, filePath);
      final result = await OpenFilex.open(filePath);

      if (!mounted) return;
      if (result.type != ResultType.done) {
        AppUtils.showErrorSnackBar(
          context,
          'Could not preview this policy in app.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppUtils.showErrorSnackBar(
        context,
        'Could not open policy: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningPolicy = false);
      }
    }
  }

  bool _canManage(AppUser? user) {
    if (user == null) return false;
    return PermissionService.isAtLeast(user.role, UserRole.managerAdmin);
  }

  Future<void> _uploadNewVersion(Policy policy) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xlsx',
        'xls',
        'csv',
        'png',
        'jpg',
        'jpeg',
        'gif',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    // file.bytes can be null/empty on desktop — read from path as fallback.
    var bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Could not read file data.');
      }
      return;
    }

    final ext = file.name.split('.').last.toLowerCase();
    final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext);
    final maxSize = isImage ? 10 * 1024 * 1024 : 25 * 1024 * 1024;

    if (file.size > maxSize) {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'File too large. Max: ${isImage ? '10 MB' : '25 MB'}');
      }
      return;
    }

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final currentUser = await ref.read(currentUserProvider.future);
    if (orgId == null || currentUser == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final storage = StorageService();
      final authorizedFirestore = ref.read(authorizedFirestoreServiceProvider);

      final contentType = _contentType(ext);
      final now = DateTime.now();

      final fileUrl = await storage.uploadPolicy(
        orgId,
        policy.id,
        bytes,
        file.name,
        contentType,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      final versionEntry = {
        'url': fileUrl,
        'uploadedBy': currentUser.id,
        'uploadedByName': currentUser.displayName,
        'uploadedAt': now.toIso8601String(),
        'fileSize': file.size,
      };

      await authorizedFirestore.addPolicyVersion(
          currentUser, orgId, policy.id, versionEntry);

      if (mounted) {
        AppUtils.showSuccessSnackBar(context, 'New version uploaded.');
      }
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'Permission denied. You cannot upload versions.');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePolicy(Policy policy) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete Policy',
      message:
          'Are you sure you want to delete "${policy.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppGlassColors.rose,
    );

    if (confirmed != true) return;

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    if (orgId == null) return;

    setState(() => _isDeleting = true);

    try {
      final currentUser = ref.read(currentUserProvider).valueOrNull;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await ref
          .read(authorizedFirestoreServiceProvider)
          .deletePolicy(currentUser, orgId, policy.id);

      if (mounted) {
        AppUtils.showSuccessSnackBar(context, 'Policy deleted.');
        context.pop();
      }
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'Permission denied. You cannot delete this policy.');
        setState(() => _isDeleting = false);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Delete failed: $e');
        setState(() => _isDeleting = false);
      }
    }
  }

  String _contentType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'csv':
        return 'text/csv';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final policyAsync = ref.watch(policyProvider(widget.policyId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leaguesAsync = ref.watch(leaguesProvider);
    final leagues = leaguesAsync.valueOrNull ?? [];
    final policy = policyAsync.valueOrNull;
    final headerLeague = resolveHeaderLeague(leagues, policy?.leagueId);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Policy',
        leadingIcon: Icons.folder_copy_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        actions: [
          if (_canManage(currentUser) && policy != null)
            AppHeaderIconButton(
              icon: Icons.delete_outline,
              color: AppGlassColors.rose,
              tooltip: 'Delete',
              onPressed: () {
                if (!_isDeleting) _deletePolicy(policy);
              },
            ),
        ],
      ),
      child: policyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppGlassColors.rose)),
        ),
        data: (policy) {
          if (policy == null) {
            return const Center(
              child: Text(
                'Policy not found.',
                style: TextStyle(color: AppGlassColors.inkSecondary),
              ),
            );
          }

          final leagueName = policy.leagueId != null
              ? leagues
                  .where((l) => l.id == policy.leagueId)
                  .map((l) => l.name)
                  .firstOrNull
              : null;

          final versions = List<PolicyVersion>.from(policy.versions);

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              topContentPadding,
              16,
              bottomContentPadding,
            ),
            children: [
              AppGlassSurface(
                padding: const EdgeInsets.all(18),
                radius: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _fileColor(policy.fileType)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _fileColor(policy.fileType)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            _fileIcon(policy.fileType),
                            color: _fileColor(policy.fileType),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                policy.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppGlassColors.ink,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  _GlassBadge(
                                    policy.category,
                                    AppGlassColors.aqua,
                                  ),
                                  if (leagueName != null)
                                    _GlassBadge(
                                      leagueName,
                                      AppGlassColors.gold,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppGlassColors.border),
                    const SizedBox(height: 12),
                    _InfoRow('File type', policy.fileType.toUpperCase()),
                    _InfoRow(
                        'File size', AppUtils.formatFileSize(policy.fileSize)),
                    _InfoRow('Uploaded by', policy.uploadedByName),
                    _InfoRow('Created', AppUtils.formatDate(policy.createdAt)),
                    _InfoRow(
                        'Last updated', AppUtils.formatDate(policy.updatedAt)),
                    _InfoRow('Versions',
                        'v${versions.isEmpty ? 1 : versions.length}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _PolicyActionButton(
                icon: Icons.visibility_outlined,
                label: _isOpeningPolicy ? 'Opening...' : 'Open In App',
                isLoading: _isOpeningPolicy,
                onTap: _isOpeningPolicy
                    ? null
                    : () => _openPolicy(
                          policy.fileUrl,
                          fileType: policy.fileType,
                          title: policy.name,
                        ),
              ),
              if (_canManage(currentUser)) ...[
                const SizedBox(height: 10),
                _PolicyActionButton(
                  icon: Icons.upload_file,
                  label: _isUploading
                      ? 'Uploading ${(_uploadProgress * 100).toStringAsFixed(0)}%...'
                      : 'Upload New Version',
                  isLoading: _isUploading,
                  isSecondary: true,
                  onTap: _isUploading ? null : () => _uploadNewVersion(policy),
                ),
                if (_isUploading) ...[
                  const SizedBox(height: 10),
                  _InlineProgress(progress: _uploadProgress),
                ],
              ],
              if (versions.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text(
                  'Version History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppGlassColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                ...versions.reversed.toList().asMap().entries.map(
                  (entry) {
                    final v = entry.value;
                    final displayVersion = versions.length - entry.key;
                    final isLatest = entry.key == 0;
                    return _VersionTile(
                      version: v,
                      displayVersion: displayVersion,
                      isLatest: isLatest,
                      onTap: () => _openPolicy(
                        v.fileUrl,
                        fileType: policy.fileType,
                        title: '${policy.name} v$displayVersion',
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  IconData _fileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _fileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return AppGlassColors.rose;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return AppGlassColors.aqua;
      case 'docx':
      case 'doc':
        return AppGlassColors.gold;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return AppGlassColors.gold;
      default:
        return AppGlassColors.inkSecondary;
    }
  }
}

class _PolicyActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final bool isSecondary;
  final VoidCallback? onTap;

  const _PolicyActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isSecondary ? AppGlassColors.aqua : AppGlassColors.ink;

    return Opacity(
      opacity: onTap == null ? 0.72 : 1,
      child: AppGlassSurface(
        height: 56,
        padding: EdgeInsets.zero,
        radius: 24,
        onTap: onTap,
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InlineProgress extends StatelessWidget {
  final double progress;

  const _InlineProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 6,
        value: progress > 0 ? progress : null,
        backgroundColor: AppGlassColors.border,
        valueColor: const AlwaysStoppedAnimation<Color>(AppGlassColors.aqua),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  final PolicyVersion version;
  final int displayVersion;
  final bool isLatest;
  final VoidCallback onTap;

  const _VersionTile({
    required this.version,
    required this.displayVersion,
    required this.isLatest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      radius: 22,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isLatest
                  ? AppGlassColors.aqua.withValues(alpha: 0.16)
                  : AppGlassColors.inkMuted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLatest
                    ? AppGlassColors.aqua.withValues(alpha: 0.28)
                    : AppGlassColors.border,
              ),
            ),
            child: Center(
              child: Text(
                'v$displayVersion',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isLatest
                      ? AppGlassColors.aqua
                      : AppGlassColors.inkSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        version.uploadedByName.isNotEmpty
                            ? version.uploadedByName
                            : 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppGlassColors.ink,
                        ),
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 7),
                      _GlassBadge('Latest', AppGlassColors.aqua),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppUtils.formatDate(version.uploadedAt)} • ${AppUtils.formatFileSize(version.fileSize)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppGlassColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.open_in_new,
            size: 17,
            color: AppGlassColors.inkMuted,
          ),
        ],
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _GlassBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      radius: 12,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppGlassColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppGlassColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
