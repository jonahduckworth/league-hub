import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/hub.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  /// Pass an existing announcement ID when editing.
  final String? announcementId;

  const CreateAnnouncementScreen({super.key, this.announcementId});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState
    extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  AnnouncementScope _scope = AnnouncementScope.orgWide;
  String? _selectedLeagueId;
  String? _selectedHubId;
  bool _isPinned = false;
  bool _isLoading = false;
  bool _populated = false;

  bool get _isEditing => widget.announcementId != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  /// Pre-populate fields when editing.
  void _populate(List<Announcement> announcements) {
    if (_populated || !_isEditing) return;
    final a = announcements
        .where((x) => x.id == widget.announcementId)
        .firstOrNull;
    if (a == null) return;
    _populated = true;
    _titleCtrl.text = a.title;
    _bodyCtrl.text = a.body;
    _scope = a.scope;
    _selectedLeagueId = a.leagueId;
    _selectedHubId = a.hubId;
    _isPinned = a.isPinned;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_scope == AnnouncementScope.league && _selectedLeagueId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a league.');
      return;
    }
    if (_scope == AnnouncementScope.hub && _selectedHubId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a hub.');
      return;
    }

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final currentUser = await ref.read(currentUserProvider.future);
    if (orgId == null || currentUser == null) return;

    // Manager Admin can only post for league/hub scope, not org-wide.
    if (currentUser.role == UserRole.managerAdmin &&
        _scope == AnnouncementScope.orgWide) {
      if (mounted) {
        AppUtils.showInfoSnackBar(
            context, 'Manager Admins cannot post org-wide announcements.');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authorizedService = ref.read(authorizedFirestoreServiceProvider);
      final data = {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'scope': _scope.name,
        'leagueId': _scope == AnnouncementScope.orgWide ? null : _selectedLeagueId,
        'hubId': _scope == AnnouncementScope.hub ? _selectedHubId : null,
        'authorId': currentUser.id,
        'authorName': currentUser.displayName,
        'authorRole': currentUser.roleLabel,
        'isPinned': _isPinned,
        'attachments': [],
      };

      if (_isEditing) {
        await authorizedService.updateAnnouncement(
          currentUser,
          orgId,
          widget.announcementId!,
          {
            'title': data['title'],
            'body': data['body'],
            'scope': data['scope'],
            'leagueId': data['leagueId'],
            'hubId': data['hubId'],
            'isPinned': data['isPinned'],
          },
          authorId: currentUser.id,
        );
      } else {
        await authorizedService.createAnnouncement(
          currentUser,
          orgId,
          data,
          scope: _scope,
          hubId: _scope == AnnouncementScope.hub ? _selectedHubId : null,
        );
        // Push notification will be sent via FCM when notification service is integrated.
      }

      if (mounted) {
        AppUtils.showSuccessSnackBar(context,
            _isEditing ? 'Announcement updated.' : 'Announcement posted.');
        context.pop();
      }
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(context,
            'Permission denied. You cannot create or edit announcements.');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final leagues = leaguesAsync.valueOrNull ?? [];
    final userAsync = ref.watch(currentUserProvider);
    final currentUser = userAsync.valueOrNull;
    final isSuperOrOwner = currentUser?.role == UserRole.superAdmin ||
        currentUser?.role == UserRole.platformOwner;

    // Pre-populate on edit.
    if (_isEditing) {
      final announcements = ref.watch(announcementsProvider).valueOrNull ?? [];
      _populate(announcements);
    }

    // Hub list for selected league.
    final hubsAsync = _selectedLeagueId != null
        ? ref.watch(hubsProvider(_selectedLeagueId!))
        : const AsyncValue<List<Hub>>.data([]);
    final hubs = hubsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Announcement' : 'New Announcement'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Scope picker ──────────────────────────────────────────────
            _SectionLabel('Scope'),
            const SizedBox(height: 8),
            _ScopePicker(
              selected: _scope,
              isSuperOrOwner: isSuperOrOwner,
              onChanged: (s) => setState(() {
                _scope = s;
                _selectedLeagueId = null;
                _selectedHubId = null;
              }),
            ),
            if (_scope == AnnouncementScope.league ||
                _scope == AnnouncementScope.hub) ...[
              const SizedBox(height: 12),
              _SectionLabel('League'),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: _inputDecoration(
                    _selectedLeagueId == null ? 'Select league' : ''),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLeagueId,
                    isExpanded: true,
                    isDense: true,
                    hint: const Text('Select league'),
                    items: leagues
                        .map((l) => DropdownMenuItem(
                            value: l.id, child: Text(l.name)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedLeagueId = v;
                      _selectedHubId = null;
                    }),
                  ),
                ),
              ),
            ],
            if (_scope == AnnouncementScope.hub) ...[
              const SizedBox(height: 12),
              _SectionLabel('Hub'),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: _inputDecoration(
                    _selectedHubId == null ? 'Select hub' : ''),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedHubId,
                    isExpanded: true,
                    isDense: true,
                    hint: const Text('Select hub'),
                    items: hubs
                        .map((h) => DropdownMenuItem(
                            value: h.id, child: Text(h.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedHubId = v),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────────────
            _SectionLabel('Title'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleCtrl,
              decoration: _inputDecoration('Announcement title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // ── Body ──────────────────────────────────────────────────────
            _SectionLabel('Body'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bodyCtrl,
              decoration: _inputDecoration('Write your announcement…'),
              maxLines: 6,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Body is required' : null,
            ),
            const SizedBox(height: 20),

            // ── Pin toggle ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pin this announcement',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pinned posts appear at the top',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textMuted)),
                value: _isPinned,
                activeTrackColor: AppColors.warning,
                onChanged: (v) => setState(() => _isPinned = v),
              ),
            ),
            const SizedBox(height: 28),

            // ── Submit ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isEditing ? 'Update Announcement' : 'Post Announcement',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary));
}

class _ScopePicker extends StatelessWidget {
  final AnnouncementScope selected;
  final bool isSuperOrOwner;
  final ValueChanged<AnnouncementScope> onChanged;

  const _ScopePicker({
    required this.selected,
    required this.isSuperOrOwner,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      if (isSuperOrOwner)
        (AnnouncementScope.orgWide, 'Org-Wide', Icons.public),
      (AnnouncementScope.league, 'League', Icons.emoji_events_outlined),
      (AnnouncementScope.hub, 'Hub', Icons.location_city_outlined),
    ];

    return Row(
      children: options.map((entry) {
        final (scope, label, icon) = entry;
        final isSelected = selected == scope;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(scope),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
