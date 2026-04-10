import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/hub.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../services/storage_service.dart';

class UploadDocumentScreen extends ConsumerStatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  ConsumerState<UploadDocumentScreen> createState() =>
      _UploadDocumentScreenState();
}

class _UploadDocumentScreenState
    extends ConsumerState<UploadDocumentScreen> {
  final _nameCtrl = TextEditingController();

  String _category = 'Rosters';
  String? _selectedLeagueId;
  String? _selectedHubId;
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  bool _isUploading = false;
  double _progress = 0;

  static const _categories = [
    'Rosters',
    'Waivers',
    'Schedules',
    'Policies',
    'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _isImageExtension(String ext) =>
      ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext);

  int _maxFileSize(String ext) =>
      _isImageExtension(ext) ? 10 * 1024 * 1024 : 25 * 1024 * 1024;

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

  Future<void> _pickFile() async {
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
    final ext = file.name.split('.').last.toLowerCase();
    final maxSize = _maxFileSize(ext);

    if (file.size > maxSize) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context,
            'File too large. Max size for ${_isImageExtension(ext) ? 'images' : 'documents'}: '
            '${_isImageExtension(ext) ? '10 MB' : '25 MB'}');
      }
      return;
    }

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

    setState(() {
      _pickedFile = file;
      _fileBytes = bytes;
      if (_nameCtrl.text.isEmpty) {
        final parts = file.name.split('.');
        if (parts.length > 1) parts.removeLast();
        _nameCtrl.text = parts.join('.');
      }
    });
  }

  Future<void> _upload() async {
    final file = _pickedFile;
    final bytes = _fileBytes;

    if (file == null || bytes == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a file first.');
      return;
    }

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppUtils.showInfoSnackBar(context, 'Please enter a document name.');
      return;
    }

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final currentUser = await ref.read(currentUserProvider.future);
    if (orgId == null || currentUser == null) return;

    setState(() {
      _isUploading = true;
      _progress = 0;
    });

    try {
      final firestore = ref.read(firestoreServiceProvider);
      final authorizedFirestore = ref.read(authorizedFirestoreServiceProvider);
      final storage = StorageService();

      final docId = firestore.newDocumentId(orgId);
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = _contentType(ext);
      final now = DateTime.now();

      final fileUrl = await storage.uploadDocument(
        orgId,
        docId,
        bytes,
        file.name,
        contentType,
        onProgress: (p) => setState(() => _progress = p),
      );

      final versionEntry = {
        'url': fileUrl,
        'version': 1,
        'uploadedBy': currentUser.id,
        'uploadedByName': currentUser.displayName,
        'uploadedAt': now.toIso8601String(),
        'fileSize': file.size,
      };

      await authorizedFirestore.createDocument(
        currentUser,
        orgId,
        {
          'name': name,
          'fileUrl': fileUrl,
          'fileType': ext,
          'fileSize': file.size,
          'category': _category,
          'leagueId': _selectedLeagueId,
          'hubId': _selectedHubId,
          'uploadedBy': currentUser.id,
          'uploadedByName': currentUser.displayName,
          'versions': [versionEntry],
        },
        docId: docId,
      );

      if (mounted) {
        AppUtils.showSuccessSnackBar(context, 'Document uploaded successfully.');
        context.pop();
      }
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'Permission denied. You cannot upload documents.');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final leagues = leaguesAsync.valueOrNull ?? [];
    final hubsAsync = _selectedLeagueId != null
        ? ref.watch(hubsProvider(_selectedLeagueId!))
        : const AsyncValue<List<Hub>>.data([]);
    final hubs = hubsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Upload Document'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // File picker card
          GestureDetector(
            onTap: _isUploading ? null : _pickFile,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _pickedFile != null
                      ? AppColors.success
                      : AppColors.border,
                ),
              ),
              child: _pickedFile != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file,
                              size: 40, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  _pickedFile!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppUtils.formatFileSize(
                                      _pickedFile!.size),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.textMuted),
                            onPressed: _isUploading
                                ? null
                                : () => setState(() {
                                      _pickedFile = null;
                                      _fileBytes = null;
                                    }),
                          ),
                        ],
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file,
                            size: 36, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text(
                          'Tap to select a file',
                          style:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'PDF, DOCX, XLSX, images • Docs: 25 MB, Images: 10 MB',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Document name
          _SectionLabel('Document Name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameCtrl,
            enabled: !_isUploading,
            decoration: _inputDecoration('Enter document name'),
          ),
          const SizedBox(height: 16),

          // Category
          _SectionLabel('Category'),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: _inputDecoration(''),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                isDense: true,
                items: _categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _isUploading
                    ? null
                    : (v) => setState(() => _category = v ?? _category),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // League (optional)
          _SectionLabel('League (Optional)'),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: _inputDecoration(
                _selectedLeagueId == null ? 'No specific league' : ''),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedLeagueId,
                isExpanded: true,
                isDense: true,
                hint: const Text('No specific league'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('No specific league')),
                  ...leagues.map((l) => DropdownMenuItem<String?>(
                      value: l.id, child: Text(l.name))),
                ],
                onChanged: _isUploading
                    ? null
                    : (v) => setState(() {
                          _selectedLeagueId = v;
                          _selectedHubId = null;
                        }),
              ),
            ),
          ),

          if (_selectedLeagueId != null && hubs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionLabel('Hub (Optional)'),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: _inputDecoration(
                  _selectedHubId == null ? 'No specific hub' : ''),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedHubId,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('No specific hub'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('No specific hub')),
                    ...hubs.map((h) => DropdownMenuItem<String?>(
                        value: h.id, child: Text(h.name))),
                  ],
                  onChanged: _isUploading
                      ? null
                      : (v) => setState(() => _selectedHubId = v),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Progress indicator
          if (_isUploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _progress > 0
                  ? 'Uploading... ${(_progress * 100).toStringAsFixed(0)}%'
                  : 'Preparing upload...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
          ],

          // Upload button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _upload,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Upload Document',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}
