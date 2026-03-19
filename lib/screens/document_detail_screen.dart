import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/document.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/storage_service.dart';

class DocumentDetailScreen extends ConsumerStatefulWidget {
  final String docId;

  const DocumentDetailScreen({super.key, required this.docId});

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState
    extends ConsumerState<DocumentDetailScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _isDeleting = false;

  bool _canManage(AppUser? user) {
    return user?.role == UserRole.superAdmin ||
        user?.role == UserRole.managerAdmin ||
        user?.role == UserRole.platformOwner;
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document.')),
      );
    }
  }

  Future<void> _uploadNewVersion(Document doc) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xlsx', 'xls', 'csv',
        'png', 'jpg', 'jpeg', 'gif',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ext = file.name.split('.').last.toLowerCase();
    final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext);
    final maxSize = isImage ? 10 * 1024 * 1024 : 25 * 1024 * 1024;

    if (file.size > maxSize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'File too large. Max: ${isImage ? '10 MB' : '25 MB'}'),
          backgroundColor: AppColors.danger,
        ));
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
      final firestore = ref.read(firestoreServiceProvider);

      final contentType = _contentType(ext);
      final now = DateTime.now();

      final fileUrl = await storage.uploadDocument(
        orgId,
        doc.id,
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

      await firestore.addDocumentVersion(orgId, doc.id, versionEntry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('New version uploaded.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteDocument(Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text(
            'Are you sure you want to delete "${doc.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    if (orgId == null) return;

    setState(() => _isDeleting = true);

    try {
      await ref
          .read(firestoreServiceProvider)
          .deleteDocument(orgId, doc.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Document deleted.'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: AppColors.danger,
        ));
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
    final docAsync =
        ref.watch(documentProvider(widget.docId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leaguesAsync = ref.watch(leaguesProvider);
    final leagues = leaguesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Document'),
        actions: [
          if (_canManage(currentUser))
            docAsync.whenData((doc) {
              if (doc == null) return const SizedBox.shrink();
              return IconButton(
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_outline),
                onPressed:
                    _isDeleting ? null : () => _deleteDocument(doc),
                tooltip: 'Delete',
              );
            }).valueOrNull ??
                const SizedBox.shrink(),
        ],
      ),
      body: docAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (doc) {
          if (doc == null) {
            return const Center(child: Text('Document not found.'));
          }

          final leagueName = doc.leagueId != null
              ? leagues
                  .where((l) => l.id == doc.leagueId)
                  .map((l) => l.name)
                  .firstOrNull
              : null;

          final versions = List<DocumentVersion>.from(doc.versions);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card
              _Card(
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
                            color: _fileColor(doc.fileType)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _fileIcon(doc.fileType),
                            color: _fileColor(doc.fileType),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _Badge(
                                      doc.category,
                                      AppColors.primary),
                                  if (leagueName != null)
                                    _Badge(leagueName,
                                        AppColors.accent),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 12),
                    _InfoRow('File type',
                        doc.fileType.toUpperCase()),
                    _InfoRow('File size',
                        AppUtils.formatFileSize(doc.fileSize)),
                    _InfoRow('Uploaded by', doc.uploadedByName),
                    _InfoRow('Created',
                        AppUtils.formatDate(doc.createdAt)),
                    _InfoRow('Last updated',
                        AppUtils.formatDate(doc.updatedAt)),
                    _InfoRow('Versions',
                        'v${versions.isEmpty ? 1 : versions.length}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Open button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openDocument(doc.fileUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open / Download'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Upload new version (admins only)
              if (_canManage(currentUser)) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () => _uploadNewVersion(doc),
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_isUploading
                        ? 'Uploading ${(_uploadProgress * 100).toStringAsFixed(0)}%...'
                        : 'Upload New Version'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                if (_isUploading) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress > 0
                          ? _uploadProgress
                          : null,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                ],
              ],

              // Version history
              if (versions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Version History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                ...versions.reversed.toList().asMap().entries.map(
                  (entry) {
                    final v = entry.value;
                    final displayVersion =
                        versions.length - entry.key;
                    final isLatest = entry.key == 0;
                    return _VersionTile(
                      version: v,
                      displayVersion: displayVersion,
                      isLatest: isLatest,
                      onTap: () => _openDocument(v.fileUrl),
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
        return AppColors.danger;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return AppColors.success;
      case 'docx':
      case 'doc':
        return AppColors.primaryLight;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _VersionTile extends StatelessWidget {
  final DocumentVersion version;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLatest
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isLatest
                    ? AppColors.primary
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'v$displayVersion',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isLatest
                        ? Colors.white
                        : AppColors.textSecondary,
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
                      Text(
                        version.uploadedByName.isNotEmpty
                            ? version.uploadedByName
                            : 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                      ),
                      if (isLatest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Latest',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppUtils.formatDate(version.uploadedAt)} • ${AppUtils.formatFileSize(version.fileSize)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
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
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
