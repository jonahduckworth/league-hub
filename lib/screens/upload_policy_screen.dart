import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/league_branding.dart';
import '../core/scope_defaults.dart';
import '../core/utils.dart';
import '../models/hub.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';

class UploadPolicyScreen extends ConsumerStatefulWidget {
  const UploadPolicyScreen({super.key});

  @override
  ConsumerState<UploadPolicyScreen> createState() => _UploadPolicyScreenState();
}

enum _PolicyScope { league, hub, team }

class _UploadPolicyScreenState extends ConsumerState<UploadPolicyScreen> {
  final _nameCtrl = TextEditingController();

  String _category = 'Policy';
  _PolicyScope _scope = _PolicyScope.league;
  String? _selectedLeagueId;
  String? _selectedHubId;
  String? _selectedTeamId;
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  bool _isUploading = false;
  double _progress = 0;

  static const _categories = [
    'Policy',
    'Protocol',
    'Code of Conduct',
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
        AppUtils.showErrorSnackBar(
            context,
            'File too large. Max size for ${_isImageExtension(ext) ? 'images' : 'policies'}: '
            '${_isImageExtension(ext) ? '10 MB' : '25 MB'}');
      }
      return;
    }

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
      AppUtils.showInfoSnackBar(context, 'Please enter a policy name.');
      return;
    }
    if (_selectedLeagueId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a league.');
      return;
    }
    if ((_scope == _PolicyScope.hub || _scope == _PolicyScope.team) &&
        _selectedHubId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a hub.');
      return;
    }
    if (_scope == _PolicyScope.team && _selectedTeamId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a team.');
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

      final policyId = firestore.newPolicyId(orgId);
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = _contentType(ext);
      final now = DateTime.now();

      final fileUrl = await storage.uploadPolicy(
        orgId,
        policyId,
        bytes,
        file.name,
        contentType,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      final versionEntry = {
        'url': fileUrl,
        'version': 1,
        'uploadedBy': currentUser.id,
        'uploadedByName': currentUser.displayName,
        'uploadedAt': now.toIso8601String(),
        'fileSize': file.size,
      };

      await authorizedFirestore.createPolicy(
        currentUser,
        orgId,
        {
          'name': name,
          'fileUrl': fileUrl,
          'fileType': ext,
          'fileSize': file.size,
          'category': _category,
          'leagueId': _selectedLeagueId,
          'hubId': _scope == _PolicyScope.league ? null : _selectedHubId,
          'teamId': _scope == _PolicyScope.team ? _selectedTeamId : null,
          'uploadedBy': currentUser.id,
          'uploadedByName': currentUser.displayName,
          'versions': [versionEntry],
        },
        policyId: policyId,
      );

      if (mounted) {
        AppUtils.showSuccessSnackBar(context, 'Policy uploaded successfully.');
        context.pop();
      }
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'Permission denied. You cannot upload policies.');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leagues =
        manageableLeaguesForUser(currentUser, leaguesAsync.valueOrNull ?? []);
    final defaultLeagueId = singleManageableLeagueId(currentUser, leagues);
    if (_selectedLeagueId == null && defaultLeagueId != null) {
      _selectedLeagueId = defaultLeagueId;
    } else if (_selectedLeagueId != null &&
        leagues.isNotEmpty &&
        !leagues.any((league) => league.id == _selectedLeagueId)) {
      _selectedLeagueId = null;
      _selectedHubId = null;
      _selectedTeamId = null;
      _scope = _PolicyScope.league;
    }
    final hubsAsync = _selectedLeagueId != null
        ? ref.watch(hubsProvider(_selectedLeagueId!))
        : const AsyncValue<List<Hub>>.data([]);
    final hubs = hubsAsync.valueOrNull ?? [];
    final teamsAsync = _selectedLeagueId != null && _selectedHubId != null
        ? ref.watch(
            teamsProvider(
                (leagueId: _selectedLeagueId!, hubId: _selectedHubId!)),
          )
        : const AsyncValue<List<Team>>.data([]);
    final teams = teamsAsync.valueOrNull ?? [];
    if ((_scope == _PolicyScope.hub || _scope == _PolicyScope.team) &&
        _selectedHubId == null &&
        hubs.length == 1) {
      _selectedHubId = hubs.first.id;
    }
    if (_scope == _PolicyScope.team &&
        _selectedTeamId == null &&
        teams.length == 1) {
      _selectedTeamId = teams.first.id;
    }
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final topContentPadding = appShellTopPadding(context, extra: 12);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Upload Policy',
        leadingIcon: Icons.folder_copy_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        backIcon: Icons.close,
      ),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          16,
          topContentPadding,
          16,
          bottomContentPadding,
        ),
        children: [
          _FilePickerCard(
            file: _pickedFile,
            isUploading: _isUploading,
            onPickFile: _pickFile,
            onClear: () => setState(() {
              _pickedFile = null;
              _fileBytes = null;
            }),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Policy Name'),
          const SizedBox(height: 8),
          _GlassTextField(
            controller: _nameCtrl,
            enabled: !_isUploading,
            hintText: 'Enter policy name',
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Category'),
          const SizedBox(height: 8),
          _GlassDropdownField<String>(
            value: _category,
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: _isUploading
                ? null
                : (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('League'),
          const SizedBox(height: 8),
          _GlassDropdownField<String>(
            value: _selectedLeagueId,
            hintText: 'Select league',
            items: leagues
                .map(
                  (l) => DropdownMenuItem<String>(
                    value: l.id,
                    child: Text(l.name),
                  ),
                )
                .toList(),
            onChanged: _isUploading
                ? null
                : (v) => setState(() {
                      _selectedLeagueId = v;
                      _selectedHubId = null;
                      _selectedTeamId = null;
                      _scope = _PolicyScope.league;
                    }),
          ),
          if (_selectedLeagueId != null) ...[
            const SizedBox(height: 18),
            const _SectionLabel('Policy Scope'),
            const SizedBox(height: 8),
            _ScopePicker(
              selected: _scope,
              onChanged: _isUploading
                  ? null
                  : (scope) => setState(() {
                        _scope = scope;
                        if (scope == _PolicyScope.league) {
                          _selectedHubId = null;
                          _selectedTeamId = null;
                        } else if (scope == _PolicyScope.hub) {
                          _selectedTeamId = null;
                        }
                      }),
            ),
          ],
          if ((_scope == _PolicyScope.hub || _scope == _PolicyScope.team) &&
              _selectedLeagueId != null) ...[
            const SizedBox(height: 18),
            const _SectionLabel('Hub'),
            const SizedBox(height: 8),
            _GlassDropdownField<String>(
              value: _selectedHubId,
              hintText: 'Select hub',
              items: hubs
                  .map(
                    (h) => DropdownMenuItem<String>(
                      value: h.id,
                      child: Text(h.name),
                    ),
                  )
                  .toList(),
              onChanged: _isUploading
                  ? null
                  : (v) => setState(() {
                        _selectedHubId = v;
                        _selectedTeamId = null;
                      }),
            ),
          ],
          if (_scope == _PolicyScope.team && _selectedHubId != null) ...[
            const SizedBox(height: 18),
            const _SectionLabel('Team'),
            const SizedBox(height: 8),
            _GlassDropdownField<String>(
              value: _selectedTeamId,
              hintText: 'Select team',
              items: teams
                  .map(
                    (team) => DropdownMenuItem<String>(
                      value: team.id,
                      child: Text(team.name),
                    ),
                  )
                  .toList(),
              onChanged: _isUploading
                  ? null
                  : (v) => setState(() => _selectedTeamId = v),
            ),
          ],
          if (_isUploading) ...[
            const SizedBox(height: 20),
            _UploadProgress(progress: _progress),
          ],
          const SizedBox(height: 24),
          _GlassSubmitButton(
            label: _isUploading ? 'Uploading...' : 'Upload Policy',
            isLoading: _isUploading,
            onTap: _isUploading ? null : _upload,
          ),
        ],
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  final PlatformFile? file;
  final bool isUploading;
  final VoidCallback onPickFile;
  final VoidCallback onClear;

  const _FilePickerCard({
    required this.file,
    required this.isUploading,
    required this.onPickFile,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selectedFile = file;

    return AppGlassSurface(
      height: 128,
      padding: const EdgeInsets.all(16),
      radius: 26,
      onTap: isUploading ? null : onPickFile,
      child: selectedFile == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file,
                  size: 36,
                  color: AppGlassColors.inkSecondary,
                ),
                SizedBox(height: 8),
                Text(
                  'Tap to select a file',
                  style: TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'PDF, DOCX, XLSX, images • Files: 25 MB, Images: 10 MB',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppGlassColors.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppGlassColors.aqua.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppGlassColors.aqua.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_outlined,
                    color: AppGlassColors.aqua,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedFile.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppGlassColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppUtils.formatFileSize(selectedFile.size),
                        style: const TextStyle(
                          color: AppGlassColors.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove file',
                  onPressed: isUploading ? null : onClear,
                  icon: const Icon(
                    Icons.close,
                    color: AppGlassColors.inkSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;

  const _GlassTextField({
    required this.controller,
    required this.hintText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
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
            selectionColor: Color(0x5567E8D4),
            selectionHandleColor: AppGlassColors.aqua,
          ),
        ),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          cursorColor: AppGlassColors.aqua,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }
}

class _ScopePicker extends StatelessWidget {
  final _PolicyScope selected;
  final ValueChanged<_PolicyScope>? onChanged;

  const _ScopePicker({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (_PolicyScope.league, 'League', Icons.emoji_events_outlined),
      (_PolicyScope.hub, 'Hub', Icons.location_on_outlined),
      (_PolicyScope.team, 'Team', Icons.groups_2_outlined),
    ];

    return Row(
      children: List.generate(options.length, (index) {
        final (scope, label, icon) = options[index];
        final isSelected = selected == scope;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == options.length - 1 ? 0 : 8,
            ),
            child: AppGlassSurface(
              height: 54,
              padding: EdgeInsets.zero,
              radius: 18,
              onTap: onChanged == null ? null : () => onChanged!(scope),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppGlassColors.aqua.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? AppGlassColors.aqua.withValues(alpha: 0.34)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: isSelected
                          ? AppGlassColors.aqua
                          : AppGlassColors.inkMuted,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? AppGlassColors.ink
                              : AppGlassColors.inkMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GlassDropdownField<T> extends StatelessWidget {
  final T? value;
  final String? hintText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _GlassDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
          ),
        ),
        child: DropdownButtonFormField<T>(
          key: ValueKey<Object?>(value),
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF132238),
          borderRadius: BorderRadius.circular(18),
          iconEnabledColor: AppGlassColors.inkSecondary,
          iconDisabledColor: AppGlassColors.inkMuted,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          hint: hintText == null
              ? null
              : Text(
                  hintText!,
                  style: const TextStyle(
                    color: AppGlassColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          decoration: const InputDecoration(
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.fromLTRB(16, 14, 14, 14),
          ),
        ),
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  final double progress;

  const _UploadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final hasProgress = progress > 0;

    return AppGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: hasProgress ? progress : null,
              backgroundColor: AppGlassColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppGlassColors.aqua),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            hasProgress
                ? 'Uploading... ${(progress * 100).toStringAsFixed(0)}%'
                : 'Preparing upload...',
            style: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _GlassSubmitButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.72 : 1,
      child: AppGlassSurface(
        key: const ValueKey('upload-policy-submit-button'),
        height: 58,
        padding: EdgeInsets.zero,
        radius: 24,
        onTap: onTap,
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppGlassColors.ink,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
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
          fontWeight: FontWeight.w800,
          color: AppGlassColors.inkMuted,
        ),
      );
}
