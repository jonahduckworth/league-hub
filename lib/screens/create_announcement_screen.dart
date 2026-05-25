import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/league_branding.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/hub.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';

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
    final a =
        announcements.where((x) => x.id == widget.announcementId).firstOrNull;
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
        'leagueId':
            _scope == AnnouncementScope.orgWide ? null : _selectedLeagueId,
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
    if (currentUser?.role == UserRole.managerAdmin &&
        _scope == AnnouncementScope.orgWide) {
      _scope = AnnouncementScope.league;
    }

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
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final topContentPadding = appShellTopPadding(context, extra: 12);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);

    return AppShellScaffold(
      header: AppShellHeader(
        title: _isEditing ? 'Edit Announcement' : 'New Announcement',
        leadingIcon: Icons.campaign_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        backIcon: Icons.close,
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
            const _SectionLabel('Scope'),
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
              const SizedBox(height: 16),
              const _SectionLabel('League'),
              const SizedBox(height: 8),
              _GlassDropdownField<String>(
                value: _selectedLeagueId,
                hint: 'Select league',
                items: leagues
                    .map((l) => DropdownMenuItem(
                          value: l.id,
                          child: Text(
                            l.name,
                            style: const TextStyle(color: AppGlassColors.ink),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedLeagueId = v;
                  _selectedHubId = null;
                }),
              ),
            ],
            if (_scope == AnnouncementScope.hub) ...[
              const SizedBox(height: 16),
              const _SectionLabel('Hub'),
              const SizedBox(height: 8),
              _GlassDropdownField<String>(
                value: _selectedHubId,
                hint: 'Select hub',
                items: hubs
                    .map((h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(
                            h.name,
                            style: const TextStyle(color: AppGlassColors.ink),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedHubId = v),
              ),
            ],
            const SizedBox(height: 20),
            const _SectionLabel('Title'),
            const SizedBox(height: 8),
            _GlassTextField(
              controller: _titleCtrl,
              hintText: 'Announcement title',
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            const _SectionLabel('Body'),
            const SizedBox(height: 8),
            _GlassTextField(
              controller: _bodyCtrl,
              hintText: 'Write your announcement...',
              minLines: 6,
              maxLines: 8,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Body is required' : null,
            ),
            const SizedBox(height: 20),
            AppGlassSurface(
              padding: const EdgeInsets.all(16),
              radius: 22,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppGlassColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppGlassColors.gold.withValues(alpha: 0.26),
                      ),
                    ),
                    child: const Icon(
                      Icons.push_pin_outlined,
                      color: AppGlassColors.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pin this announcement',
                          style: TextStyle(
                            color: AppGlassColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Pinned posts appear at the top',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppGlassColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isPinned,
                    activeTrackColor:
                        AppGlassColors.gold.withValues(alpha: 0.58),
                    activeThumbColor: AppGlassColors.gold,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                    inactiveThumbColor: AppGlassColors.inkMuted,
                    onChanged: (v) => setState(() => _isPinned = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Opacity(
              opacity: _isLoading ? 0.72 : 1,
              child: AppGlassSurface(
                height: 58,
                radius: 22,
                padding: EdgeInsets.zero,
                onTap: _isLoading ? null : _submit,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppGlassColors.aqua,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'Update Announcement'
                              : 'Post Announcement',
                          style: const TextStyle(
                            color: AppGlassColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
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
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppGlassColors.inkMuted,
          letterSpacing: 0.2,
        ),
      );
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  const _GlassTextField({
    required this.controller,
    required this.hintText,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 20,
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
          minLines: minLines,
          maxLines: maxLines,
          textInputAction: textInputAction,
          cursorColor: AppGlassColors.aqua,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            isDense: true,
            filled: false,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            hintStyle: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
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

class _GlassDropdownField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _GlassDropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
          ),
        ),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: AppGlassColors.pageMid,
          iconEnabledColor: AppGlassColors.inkMuted,
          decoration: const InputDecoration(
            isDense: true,
            filled: false,
            fillColor: Colors.transparent,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          hint: Text(
            hint,
            style: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
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
      if (isSuperOrOwner) (AnnouncementScope.orgWide, 'Org-Wide', Icons.public),
      (AnnouncementScope.league, 'League', Icons.emoji_events_outlined),
      (AnnouncementScope.hub, 'Hub', Icons.location_city_outlined),
    ];

    return Row(
      children: List.generate(options.length, (index) {
        final entry = options[index];
        final (scope, label, icon) = entry;
        final isSelected = selected == scope;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == options.length - 1 ? 0 : 8,
            ),
            child: AppGlassSurface(
              height: 86,
              radius: 20,
              padding: EdgeInsets.zero,
              onTap: () => onChanged(scope),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppGlassColors.aqua.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppGlassColors.aqua.withValues(alpha: 0.34)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 21,
                      color: isSelected
                          ? AppGlassColors.aqua
                          : AppGlassColors.inkMuted,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? AppGlassColors.ink
                              : AppGlassColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
