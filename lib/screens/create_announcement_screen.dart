import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/league_branding.dart';
import '../core/scope_defaults.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/hub.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/glass_form_widgets.dart';

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

  AnnouncementScope _scope = AnnouncementScope.league;
  String? _selectedLeagueId;
  String? _selectedHubId;
  String? _selectedTeamId;
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
    _selectedTeamId = a.teamId;
    _isPinned = a.isPinned;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLeagueId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a league.');
      return;
    }
    if ((_scope == AnnouncementScope.hub || _scope == AnnouncementScope.team) &&
        _selectedHubId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a hub.');
      return;
    }
    if (_scope == AnnouncementScope.team && _selectedTeamId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a team.');
      return;
    }

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final currentUser = await ref.read(currentUserProvider.future);
    if (orgId == null || currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final authorizedService = ref.read(authorizedFirestoreServiceProvider);
      final data = {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'scope': _scope.name,
        'leagueId': _selectedLeagueId,
        'hubId': _scope == AnnouncementScope.league ? null : _selectedHubId,
        'teamId': _scope == AnnouncementScope.team ? _selectedTeamId : null,
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
            'teamId': data['teamId'],
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
          leagueId: _selectedLeagueId,
          hubId: _scope == AnnouncementScope.league ? null : _selectedHubId,
          teamId: _scope == AnnouncementScope.team ? _selectedTeamId : null,
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
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leagues =
        manageableLeaguesForUser(currentUser, leaguesAsync.valueOrNull ?? []);
    if (_scope == AnnouncementScope.orgWide && !_isEditing) {
      _scope = AnnouncementScope.league;
    }
    final defaultLeagueId = singleManageableLeagueId(currentUser, leagues);
    if (_selectedLeagueId == null && defaultLeagueId != null) {
      _selectedLeagueId = defaultLeagueId;
    } else if (_selectedLeagueId != null &&
        leagues.isNotEmpty &&
        !leagues.any((league) => league.id == _selectedLeagueId)) {
      _selectedLeagueId = null;
      _selectedHubId = null;
      _selectedTeamId = null;
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
    final teamsAsync = _selectedLeagueId != null && _selectedHubId != null
        ? ref.watch(
            teamsProvider(
                (leagueId: _selectedLeagueId!, hubId: _selectedHubId!)),
          )
        : const AsyncValue<List<Team>>.data([]);
    final teams = teamsAsync.valueOrNull ?? [];
    if ((_scope == AnnouncementScope.hub || _scope == AnnouncementScope.team) &&
        _selectedHubId == null &&
        hubs.length == 1) {
      _selectedHubId = hubs.first.id;
    }
    if (_scope == AnnouncementScope.team &&
        _selectedTeamId == null &&
        teams.length == 1) {
      _selectedTeamId = teams.first.id;
    }
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
            const GlassFormSectionLabel('Scope'),
            const SizedBox(height: 8),
            GlassScopeSelector<AnnouncementScope>(
              selected: _scope,
              options: [
                if (_scope == AnnouncementScope.orgWide)
                  const GlassChoiceOption(
                    value: AnnouncementScope.orgWide,
                    label: 'Org-Wide',
                    icon: Icons.public,
                  ),
                const GlassChoiceOption(
                  value: AnnouncementScope.league,
                  label: 'League',
                  icon: Icons.emoji_events_outlined,
                ),
                const GlassChoiceOption(
                  value: AnnouncementScope.hub,
                  label: 'Hub',
                  icon: Icons.location_city_outlined,
                ),
                const GlassChoiceOption(
                  value: AnnouncementScope.team,
                  label: 'Team',
                  icon: Icons.groups_2_outlined,
                ),
              ],
              onChanged: (s) => setState(() {
                _scope = s;
                if (s == AnnouncementScope.league) {
                  _selectedHubId = null;
                  _selectedTeamId = null;
                } else if (s == AnnouncementScope.hub) {
                  _selectedTeamId = null;
                }
              }),
            ),
            if (_scope == AnnouncementScope.league ||
                _scope == AnnouncementScope.hub ||
                _scope == AnnouncementScope.team ||
                _scope == AnnouncementScope.orgWide) ...[
              const SizedBox(height: 16),
              const GlassFormSectionLabel('League'),
              const SizedBox(height: 8),
              GlassDropdownField<String>(
                value: _selectedLeagueId,
                hintText: 'Select league',
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
                  _selectedTeamId = null;
                }),
              ),
            ],
            if (_scope == AnnouncementScope.hub ||
                _scope == AnnouncementScope.team) ...[
              const SizedBox(height: 16),
              const GlassFormSectionLabel('Hub'),
              const SizedBox(height: 8),
              GlassDropdownField<String>(
                value: _selectedHubId,
                hintText: 'Select hub',
                items: hubs
                    .map((h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(
                            h.name,
                            style: const TextStyle(color: AppGlassColors.ink),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedHubId = v;
                  _selectedTeamId = null;
                }),
              ),
            ],
            if (_scope == AnnouncementScope.team) ...[
              const SizedBox(height: 16),
              const GlassFormSectionLabel('Team'),
              const SizedBox(height: 8),
              GlassDropdownField<String>(
                value: _selectedTeamId,
                hintText: 'Select team',
                items: teams
                    .map((team) => DropdownMenuItem(
                          value: team.id,
                          child: Text(
                            team.name,
                            style: const TextStyle(color: AppGlassColors.ink),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTeamId = v),
              ),
            ],
            const SizedBox(height: 20),
            const GlassFormSectionLabel('Title'),
            const SizedBox(height: 8),
            GlassTextFormField(
              controller: _titleCtrl,
              hintText: 'Announcement title',
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            const GlassFormSectionLabel('Body'),
            const SizedBox(height: 8),
            GlassTextFormField(
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
            GlassSubmitButton(
              label: _isEditing ? 'Update Announcement' : 'Post Announcement',
              isLoading: _isLoading,
              onTap: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
