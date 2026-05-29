import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/league_branding.dart';
import '../../core/picked_file.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/chat_room.dart';
import '../../models/league.dart';
import '../../models/hub.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/authorized_firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/entity_avatar.dart';
import '../../widgets/glass_form_widgets.dart';

class ManageLeaguesScreen extends ConsumerWidget {
  const ManageLeaguesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final org = ref.watch(organizationProvider).valueOrNull;
    final leagues = leaguesAsync.valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context, extra: 98);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Manage Leagues & Hubs',
        leadingIcon: Icons.location_city_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.logoUrl?.isNotEmpty == true
            ? headerLeague?.name
            : null,
        showBackButton: true,
        backFallbackLocation: '/settings',
      ),
      floatingActionButton: _GlassAddButton(
        label: 'Add League',
        onTap: org == null ? null : () => context.push('/settings/leagues/new'),
      ),
      child: leaguesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppGlassColors.aqua),
        ),
        error: (e, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            topContentPadding,
            16,
            appShellBottomPadding(context, extra: 24),
          ),
          children: [
            _GlassMessageCard(
              icon: Icons.error_outline,
              title: 'Could not load leagues',
              message: '$e',
              color: AppGlassColors.rose,
            ),
          ],
        ),
        data: (leagues) {
          if (leagues.isEmpty) {
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                topContentPadding,
                16,
                bottomContentPadding,
              ),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No leagues yet',
                  subtitle: 'Tap the button below to add your first league.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              topContentPadding,
              16,
              bottomContentPadding,
            ),
            itemCount: leagues.length,
            itemBuilder: (_, i) =>
                _LeagueTile(league: leagues[i], orgId: org?.id ?? ''),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add League screen
// ---------------------------------------------------------------------------

class AddLeagueScreen extends ConsumerStatefulWidget {
  const AddLeagueScreen({super.key});

  @override
  ConsumerState<AddLeagueScreen> createState() => _AddLeagueScreenState();
}

class _AddLeagueScreenState extends ConsumerState<AddLeagueScreen> {
  final _nameCtrl = TextEditingController();
  final _abbrevCtrl = TextEditingController();
  bool _saving = false;
  final _identity = _IdentitySelection(defaultIconName: 'league');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrevCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(organizationProvider).valueOrNull;

    return _StructureFormScaffold(
      title: 'New League',
      heading: 'Create a league',
      icon: Icons.emoji_events_outlined,
      actionLabel: 'Create League',
      saving: _saving,
      onSubmit: org == null ? null : _save,
      child: Column(
        children: [
          _FormCard(
            children: [
              GlassTextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                labelText: 'League Name',
                hintText: 'e.g. Hockey Super League',
              ),
              const SizedBox(height: 14),
              GlassTextFormField(
                controller: _abbrevCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                labelText: 'Abbreviation',
                hintText: 'HSL',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _IdentityPicker(
            title: 'League logo',
            subtitle: 'Choose an icon or upload a logo for this league.',
            selection: _identity,
            fallbackIcon: Icons.emoji_events_outlined,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final org = ref.read(organizationProvider).valueOrNull;
    final name = _nameCtrl.text.trim();
    final abbrev = _abbrevCtrl.text.trim();
    if (org == null) return;
    if (name.isEmpty || abbrev.isEmpty) return;
    setState(() => _saving = true);
    try {
      final rawDb = ref.read(firestoreServiceProvider);
      final authDb = ref.read(authorizedFirestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      final id = rawDb.newLeagueId(org.id);
      final logoUrl = await _uploadIdentityLogo(
        orgId: org.id,
        entityType: 'leagues',
        entityId: id,
        currentUserId: currentUser.id,
        pickedFile: _identity.pickedImage,
      );
      final league = League(
        id: id,
        orgId: org.id,
        name: name,
        abbreviation: abbrev,
        logoUrl: logoUrl,
        iconName: logoUrl == null ? _identity.iconName : null,
        createdAt: DateTime.now(),
      );
      await authDb.createLeague(currentUser, org.id, league);
      await authDb.createChatRoom(
        currentUser,
        org.id,
        '$name – General',
        ChatRoomType.league,
        leagueId: id,
        roomIconName: league.iconName,
        roomImageUrl: league.logoUrl,
      );
      if (mounted) context.pop();
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to create leagues');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Could not create league: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class EditLeagueScreen extends ConsumerStatefulWidget {
  final String leagueId;
  final League? initialLeague;

  const EditLeagueScreen({
    super.key,
    required this.leagueId,
    this.initialLeague,
  });

  @override
  ConsumerState<EditLeagueScreen> createState() => _EditLeagueScreenState();
}

class _EditLeagueScreenState extends ConsumerState<EditLeagueScreen> {
  final _nameCtrl = TextEditingController();
  final _abbrevCtrl = TextEditingController();
  bool _saving = false;
  bool _seeded = false;
  _IdentitySelection? _identity;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrevCtrl.dispose();
    super.dispose();
  }

  void _seed(League league) {
    if (_seeded) return;
    _nameCtrl.text = league.name;
    _abbrevCtrl.text = league.abbreviation;
    _identity = _IdentitySelection(
      defaultIconName: 'league',
      initialImageUrl: league.logoUrl,
      initialIconName: league.iconName,
    );
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(organizationProvider).valueOrNull;
    final leaguesAsync = ref.watch(leaguesProvider);

    return leaguesAsync.when(
      loading: () => const _ShellLoadingScaffold(title: 'Edit League'),
      error: (e, _) => _LoadErrorScaffold(message: 'Could not load league: $e'),
      data: (leagues) {
        final league = widget.initialLeague ??
            leagues.cast<League?>().firstWhere(
                  (league) => league?.id == widget.leagueId,
                  orElse: () => null,
                );
        if (league == null) {
          return const _LoadErrorScaffold(message: 'League not found.');
        }
        _seed(league);
        final identity = _identity!;

        return _StructureFormScaffold(
          title: 'Edit League',
          heading: 'Update league details',
          icon: Icons.emoji_events_outlined,
          actionLabel: 'Save League',
          saving: _saving,
          onSubmit: org == null ? null : () => _save(org.id, league),
          child: Column(
            children: [
              _FormCard(
                children: [
                  GlassTextFormField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    labelText: 'League Name',
                    hintText: 'e.g. Hockey Super League',
                  ),
                  const SizedBox(height: 14),
                  GlassTextFormField(
                    controller: _abbrevCtrl,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    labelText: 'Abbreviation',
                    hintText: 'HSL',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _IdentityPicker(
                title: 'League logo',
                subtitle: 'Keep the current logo or choose a new look.',
                selection: identity,
                fallbackIcon: Icons.emoji_events_outlined,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(String orgId, League league) async {
    final identity = _identity;
    final name = _nameCtrl.text.trim();
    final abbrev = _abbrevCtrl.text.trim();
    if (identity == null) return;
    if (name.isEmpty || abbrev.isEmpty) return;
    setState(() => _saving = true);
    try {
      final authDb = ref.read(authorizedFirestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;
      final logoUrl = await _uploadIdentityLogo(
        orgId: orgId,
        entityType: 'leagues',
        entityId: league.id,
        currentUserId: currentUser.id,
        pickedFile: identity.pickedImage,
      );
      final effectiveLogoUrl = logoUrl ?? identity.effectiveImageUrl;
      await authDb.updateLeagueFields(currentUser, orgId, league.id, {
        'name': name,
        'abbreviation': abbrev,
        'logoUrl': effectiveLogoUrl,
        'iconName':
            effectiveLogoUrl == null ? identity.effectiveIconName : null,
      });
      if (mounted) context.pop();
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to edit leagues');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Could not save league: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// League tile (expands to show hubs)
// ---------------------------------------------------------------------------

class _LeagueTile extends ConsumerWidget {
  final League league;
  final String orgId;
  const _LeagueTile({required this.league, required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubsAsync = ref.watch(hubsProvider(league.id));

    return AppGlassSurface(
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.zero,
      radius: 24,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.04),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          iconColor: AppGlassColors.inkMuted,
          collapsedIconColor: AppGlassColors.inkMuted,
          leading: EntityAvatar(
            name: league.abbreviation,
            imageUrl: league.logoUrl,
            iconName: league.iconName,
            fallbackIcon: Icons.emoji_events_outlined,
            textFallback: league.abbreviation,
            size: 42,
            color: AppGlassColors.aqua,
          ),
          title: Text(league.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppGlassColors.ink)),
          subtitle: hubsAsync.maybeWhen(
            data: (hubs) => Text(
              '${hubs.length} hub${hubs.length == 1 ? '' : 's'}',
              style:
                  const TextStyle(fontSize: 12, color: AppGlassColors.inkMuted),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppGlassColors.inkMuted, size: 20),
                tooltip: 'Edit League',
                onPressed: () => context.push(
                  '/settings/leagues/${league.id}/edit',
                  extra: league,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_location_alt_outlined,
                    color: AppGlassColors.aqua, size: 20),
                tooltip: 'Add Hub',
                onPressed: () => context.push(
                  '/settings/leagues/${league.id}/hubs/new',
                  extra: league,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppGlassColors.rose, size: 20),
                tooltip: 'Delete League',
                onPressed: () => _confirmDelete(context, ref, orgId, league),
              ),
            ],
          ),
          children: [
            hubsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppGlassColors.aqua,
                    ),
                  )),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppGlassColors.rose))),
              data: (hubs) {
                if (hubs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: AppGlassSurface(
                      padding: const EdgeInsets.all(12),
                      radius: 16,
                      child: const Text(
                        'No hubs yet. Tap + to add one.',
                        style: TextStyle(
                          color: AppGlassColors.inkMuted,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return Column(
                    children: hubs
                        .map((hub) =>
                            _HubTile(hub: hub, league: league, orgId: orgId))
                        .toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String orgId, League league) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Delete League',
      message:
          'Delete "${league.name}"? This will also remove all its hubs and teams.',
      confirmLabel: 'Delete',
      confirmColor: AppColors.danger,
    );
    if (ok == true) {
      try {
        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser == null) return;
        await ref
            .read(authorizedFirestoreServiceProvider)
            .deleteLeagueCascade(currentUser, orgId, league.id);
      } on PermissionDeniedException {
        if (context.mounted) {
          AppUtils.showErrorSnackBar(
              context, 'You do not have permission to delete leagues');
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Add Hub screen
// ---------------------------------------------------------------------------

class AddHubScreen extends ConsumerStatefulWidget {
  final String leagueId;
  final League? initialLeague;
  const AddHubScreen({
    super.key,
    required this.leagueId,
    this.initialLeague,
  });

  @override
  ConsumerState<AddHubScreen> createState() => _AddHubScreenState();
}

class _AddHubScreenState extends ConsumerState<AddHubScreen> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;
  _IdentitySelection? _identity;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(organizationProvider).valueOrNull;
    final leagueAsync = ref.watch(leaguesProvider);

    return leagueAsync.when(
      loading: () => const _ShellLoadingScaffold(title: 'New Hub'),
      error: (e, _) => _LoadErrorScaffold(message: 'Could not load league: $e'),
      data: (leagues) {
        final league = widget.initialLeague ??
            leagues.cast<League?>().firstWhere(
                  (league) => league?.id == widget.leagueId,
                  orElse: () => null,
                );
        if (league == null) {
          return const _LoadErrorScaffold(message: 'League not found.');
        }

        final identity = _identity ??= _IdentitySelection(
          defaultIconName: 'hub',
          inheritedImageUrl: league.logoUrl,
          inheritedIconName: league.iconName,
          inheritedLabel: 'Use league logo',
        );

        return _StructureFormScaffold(
          title: 'New Hub',
          heading: 'Add a hub',
          icon: Icons.location_on_outlined,
          actionLabel: 'Create Hub',
          saving: _saving,
          onSubmit: org == null ? null : () => _save(org.id, league),
          child: Column(
            children: [
              _FormCard(
                children: [
                  GlassTextFormField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    labelText: 'Hub Name',
                    hintText: 'e.g. Calgary',
                  ),
                  const SizedBox(height: 14),
                  GlassTextFormField(
                    controller: _locationCtrl,
                    textInputAction: TextInputAction.done,
                    labelText: 'Location',
                    hintText: 'Calgary, AB',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _IdentityPicker(
                title: 'Hub logo',
                subtitle: 'Use the league logo or choose a hub-specific look.',
                selection: identity,
                fallbackIcon: Icons.location_on_outlined,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(String orgId, League league) async {
    final identity = _identity;
    final name = _nameCtrl.text.trim();
    if (identity == null) return;
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final rawDb = ref.read(firestoreServiceProvider);
      final authDb = ref.read(authorizedFirestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      final id = rawDb.newHubId(orgId, league.id);
      final logoUrl = await _uploadIdentityLogo(
        orgId: orgId,
        entityType: 'hubs',
        entityId: id,
        currentUserId: currentUser.id,
        pickedFile: identity.pickedImage,
      );
      final effectiveLogoUrl = logoUrl ?? identity.effectiveImageUrl;
      final hub = Hub(
        id: id,
        leagueId: league.id,
        orgId: orgId,
        name: name,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        logoUrl: effectiveLogoUrl,
        iconName: effectiveLogoUrl == null ? identity.effectiveIconName : null,
        createdAt: DateTime.now(),
      );
      await authDb.createHub(currentUser, orgId, league.id, hub);
      await authDb.createChatRoom(
        currentUser,
        orgId,
        '$name – General',
        ChatRoomType.league,
        leagueId: league.id,
        hubId: id,
        roomIconName: hub.iconName,
        roomImageUrl: hub.logoUrl,
      );
      if (mounted) context.pop();
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to create hubs');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Could not create hub: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class EditHubScreen extends ConsumerStatefulWidget {
  final String leagueId;
  final String hubId;
  final League? initialLeague;
  final Hub? initialHub;

  const EditHubScreen({
    super.key,
    required this.leagueId,
    required this.hubId,
    this.initialLeague,
    this.initialHub,
  });

  @override
  ConsumerState<EditHubScreen> createState() => _EditHubScreenState();
}

class _EditHubScreenState extends ConsumerState<EditHubScreen> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;
  bool _seeded = false;
  _IdentitySelection? _identity;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _seed(Hub hub, League league) {
    if (_seeded) return;
    _nameCtrl.text = hub.name;
    _locationCtrl.text = hub.location ?? '';
    _identity = _IdentitySelection(
      defaultIconName: 'hub',
      initialImageUrl: hub.logoUrl,
      initialIconName: hub.iconName,
      inheritedImageUrl: league.logoUrl,
      inheritedIconName: league.iconName,
      inheritedLabel: 'Use league logo',
    )..useInherited = false;
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(organizationProvider).valueOrNull;
    final leaguesAsync = ref.watch(leaguesProvider);
    final hubsAsync = ref.watch(hubsProvider(widget.leagueId));

    if (leaguesAsync.isLoading || hubsAsync.isLoading) {
      return const _ShellLoadingScaffold(title: 'Edit Hub');
    }
    if (leaguesAsync.hasError) {
      return _LoadErrorScaffold(
          message: 'Could not load league: ${leaguesAsync.error}');
    }
    if (hubsAsync.hasError) {
      return _LoadErrorScaffold(
          message: 'Could not load hub: ${hubsAsync.error}');
    }

    final leagues = leaguesAsync.valueOrNull ?? const <League>[];
    final hubs = hubsAsync.valueOrNull ?? const <Hub>[];
    final league = widget.initialLeague ??
        leagues.cast<League?>().firstWhere(
              (league) => league?.id == widget.leagueId,
              orElse: () => null,
            );
    final hub = widget.initialHub ??
        hubs.cast<Hub?>().firstWhere(
              (hub) => hub?.id == widget.hubId,
              orElse: () => null,
            );
    if (league == null || hub == null) {
      return const _LoadErrorScaffold(message: 'Hub not found.');
    }
    _seed(hub, league);
    final identity = _identity!;

    return _StructureFormScaffold(
      title: 'Edit Hub',
      heading: 'Update hub details',
      icon: Icons.location_on_outlined,
      actionLabel: 'Save Hub',
      saving: _saving,
      onSubmit: org == null ? null : () => _save(org.id, league, hub),
      child: Column(
        children: [
          _FormCard(
            children: [
              GlassTextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                labelText: 'Hub Name',
                hintText: 'e.g. Calgary',
              ),
              const SizedBox(height: 14),
              GlassTextFormField(
                controller: _locationCtrl,
                textInputAction: TextInputAction.done,
                labelText: 'Location',
                hintText: 'Calgary, AB',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _IdentityPicker(
            title: 'Hub logo',
            subtitle: 'Keep this hub logo, inherit the league, or choose new.',
            selection: identity,
            fallbackIcon: Icons.location_on_outlined,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String orgId, League league, Hub hub) async {
    final identity = _identity;
    final name = _nameCtrl.text.trim();
    if (identity == null) return;
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final authDb = ref.read(authorizedFirestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;
      final logoUrl = await _uploadIdentityLogo(
        orgId: orgId,
        entityType: 'hubs',
        entityId: hub.id,
        currentUserId: currentUser.id,
        pickedFile: identity.pickedImage,
      );
      final effectiveLogoUrl = logoUrl ?? identity.effectiveImageUrl;
      await authDb.updateHubFields(currentUser, orgId, league.id, hub.id, {
        'name': name,
        'location': _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        'logoUrl': effectiveLogoUrl,
        'iconName':
            effectiveLogoUrl == null ? identity.effectiveIconName : null,
      });
      if (mounted) context.pop();
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to edit hubs');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Could not save hub: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Hub tile (expands to show teams)
// ---------------------------------------------------------------------------

class _HubTile extends ConsumerWidget {
  final Hub hub;
  final League league;
  final String orgId;
  const _HubTile(
      {required this.hub, required this.league, required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync =
        ref.watch(teamsProvider((leagueId: league.id, hubId: hub.id)));

    return AppGlassSurface(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: EdgeInsets.zero,
      radius: 20,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.04),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          iconColor: AppGlassColors.inkMuted,
          collapsedIconColor: AppGlassColors.inkMuted,
          leading: EntityAvatar(
            name: hub.name,
            imageUrl: hub.logoUrl,
            iconName: hub.iconName,
            fallbackIcon: Icons.location_on_outlined,
            size: 34,
            color: AppGlassColors.aqua,
          ),
          title: Text(hub.name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppGlassColors.ink)),
          subtitle: hub.location != null
              ? Text(hub.location!,
                  style: const TextStyle(
                      fontSize: 12, color: AppGlassColors.inkMuted))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              teamsAsync.maybeWhen(
                data: (teams) => Text(
                  '${teams.length}t',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppGlassColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppGlassColors.inkMuted, size: 18),
                tooltip: 'Edit Hub',
                onPressed: () => context.push(
                  '/settings/leagues/${league.id}/hubs/${hub.id}/edit',
                  extra: (league: league, hub: hub),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.group_add_outlined,
                    color: AppGlassColors.aqua, size: 18),
                tooltip: 'Add Team',
                onPressed: () => context.push(
                  '/settings/leagues/${league.id}/hubs/${hub.id}/teams/new',
                  extra: (league: league, hub: hub),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppGlassColors.rose, size: 18),
                tooltip: 'Delete Hub',
                onPressed: () =>
                    _confirmDelete(context, ref, orgId, league.id, hub),
              ),
            ],
          ),
          children: [
            teamsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppGlassColors.aqua,
                    ),
                  )),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppGlassColors.rose))),
              data: (teams) {
                if (teams.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Text('No teams yet. Tap + to add one.',
                        style: TextStyle(
                            color: AppGlassColors.inkMuted,
                            fontStyle: FontStyle.italic,
                            fontSize: 12),
                        textAlign: TextAlign.center),
                  );
                }
                return Column(
                    children: teams
                        .map((t) => _TeamRow(
                              team: t,
                              onDelete: () async {
                                try {
                                  final currentUser =
                                      ref.read(currentUserProvider).value;
                                  if (currentUser == null) return;
                                  await ref
                                      .read(authorizedFirestoreServiceProvider)
                                      .deleteTeam(currentUser, orgId, league.id,
                                          hub.id, t.id);
                                } on PermissionDeniedException {
                                  // Permission denied, but dismissible already triggered
                                }
                              },
                            ))
                        .toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String orgId,
      String leagueId, Hub hub) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Delete Hub',
      message: 'Delete "${hub.name}"? All its teams will also be removed.',
      confirmLabel: 'Delete',
      confirmColor: AppColors.danger,
    );
    if (ok == true) {
      try {
        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser == null) return;
        await ref
            .read(authorizedFirestoreServiceProvider)
            .deleteHubCascade(currentUser, orgId, leagueId, hub.id);
      } on PermissionDeniedException {
        if (context.mounted) {
          AppUtils.showErrorSnackBar(
              context, 'You do not have permission to delete hubs');
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Add Team screen
// ---------------------------------------------------------------------------

class AddTeamScreen extends ConsumerStatefulWidget {
  final String leagueId;
  final String hubId;
  final League? initialLeague;
  final Hub? initialHub;

  const AddTeamScreen({
    super.key,
    required this.leagueId,
    required this.hubId,
    this.initialLeague,
    this.initialHub,
  });

  @override
  ConsumerState<AddTeamScreen> createState() => _AddTeamScreenState();
}

class _AddTeamScreenState extends ConsumerState<AddTeamScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _divCtrl = TextEditingController();
  bool _saving = false;
  _IdentitySelection? _identity;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _divCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(organizationProvider).valueOrNull;
    final leaguesAsync = ref.watch(leaguesProvider);
    final hubsAsync = ref.watch(hubsProvider(widget.leagueId));

    if (leaguesAsync.isLoading || hubsAsync.isLoading) {
      return const _ShellLoadingScaffold(title: 'New Team');
    }
    if (leaguesAsync.hasError) {
      return _LoadErrorScaffold(
          message: 'Could not load league: ${leaguesAsync.error}');
    }
    if (hubsAsync.hasError) {
      return _LoadErrorScaffold(
          message: 'Could not load hub: ${hubsAsync.error}');
    }

    final leagues = leaguesAsync.valueOrNull ?? const <League>[];
    final hubs = hubsAsync.valueOrNull ?? const <Hub>[];
    final league = widget.initialLeague ??
        leagues.cast<League?>().firstWhere(
              (league) => league?.id == widget.leagueId,
              orElse: () => null,
            );
    final hub = widget.initialHub ??
        hubs.cast<Hub?>().firstWhere(
              (hub) => hub?.id == widget.hubId,
              orElse: () => null,
            );
    if (league == null || hub == null) {
      return const _LoadErrorScaffold(message: 'Team parent not found.');
    }

    final identity = _identity ??= _IdentitySelection(
      defaultIconName: 'team',
      inheritedImageUrl: hub.logoUrl ?? league.logoUrl,
      inheritedIconName: hub.iconName ?? league.iconName,
      inheritedLabel: hub.logoUrl != null || hub.iconName != null
          ? 'Use hub logo'
          : 'Use league logo',
    );

    return _StructureFormScaffold(
      title: 'New Team',
      heading: 'Add a team',
      icon: Icons.groups_2_outlined,
      actionLabel: 'Create Team',
      saving: _saving,
      onSubmit: org == null ? null : () => _save(org.id, league, hub),
      child: Column(
        children: [
          _FormCard(
            children: [
              GlassTextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                labelText: 'Team Name',
                hintText: 'e.g. Calgary U11 AA',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlassTextFormField(
                      controller: _ageCtrl,
                      textInputAction: TextInputAction.next,
                      labelText: 'Age Group',
                      hintText: 'U11',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassTextFormField(
                      controller: _divCtrl,
                      textInputAction: TextInputAction.done,
                      labelText: 'Division',
                      hintText: 'AA',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _IdentityPicker(
            title: 'Team logo',
            subtitle:
                'Use the hub or league logo, or choose one for this team.',
            selection: identity,
            fallbackIcon: Icons.groups_2_outlined,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String orgId, League league, Hub hub) async {
    final identity = _identity;
    final name = _nameCtrl.text.trim();
    if (identity == null) return;
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final rawDb = ref.read(firestoreServiceProvider);
      final authDb = ref.read(authorizedFirestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      final id = rawDb.newTeamId(orgId, league.id, hub.id);
      final logoUrl = await _uploadIdentityLogo(
        orgId: orgId,
        entityType: 'teams',
        entityId: id,
        currentUserId: currentUser.id,
        pickedFile: identity.pickedImage,
      );
      final effectiveLogoUrl = logoUrl ?? identity.effectiveImageUrl;
      final team = Team(
        id: id,
        hubId: hub.id,
        leagueId: league.id,
        orgId: orgId,
        name: name,
        ageGroup: _ageCtrl.text.trim().isEmpty ? null : _ageCtrl.text.trim(),
        division: _divCtrl.text.trim().isEmpty ? null : _divCtrl.text.trim(),
        logoUrl: effectiveLogoUrl,
        iconName: effectiveLogoUrl == null ? identity.effectiveIconName : null,
        createdAt: DateTime.now(),
      );
      await authDb.createTeam(currentUser, orgId, league.id, hub.id, team);
      if (mounted) context.pop();
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to create teams');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Could not create team: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class EditTeamScreen extends ConsumerStatefulWidget {
  final String teamId;
  final String leagueId;
  final String hubId;

  const EditTeamScreen({
    super.key,
    required this.teamId,
    required this.leagueId,
    required this.hubId,
  });

  @override
  ConsumerState<EditTeamScreen> createState() => _EditTeamScreenState();
}

class _EditTeamScreenState extends ConsumerState<EditTeamScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _divCtrl = TextEditingController();
  bool _saving = false;
  bool _seeded = false;
  _IdentitySelection? _identity;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _divCtrl.dispose();
    super.dispose();
  }

  void _seed(Team team, League league, Hub hub) {
    if (_seeded) return;
    _nameCtrl.text = team.name;
    _ageCtrl.text = team.ageGroup ?? '';
    _divCtrl.text = team.division ?? '';
    _identity = _IdentitySelection(
      defaultIconName: 'team',
      initialImageUrl: team.logoUrl,
      initialIconName: team.iconName,
      inheritedImageUrl: hub.logoUrl ?? league.logoUrl,
      inheritedIconName: hub.iconName ?? league.iconName,
      inheritedLabel: hub.logoUrl != null || hub.iconName != null
          ? 'Use hub logo'
          : 'Use league logo',
    )..useInherited = false;
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(organizationProvider).valueOrNull;
    final leaguesAsync = ref.watch(leaguesProvider);
    final hubsAsync = ref.watch(hubsProvider(widget.leagueId));
    final teamsAsync = ref
        .watch(teamsProvider((leagueId: widget.leagueId, hubId: widget.hubId)));

    if (leaguesAsync.isLoading || hubsAsync.isLoading || teamsAsync.isLoading) {
      return const _ShellLoadingScaffold(title: 'Edit Team');
    }
    if (leaguesAsync.hasError) {
      return _LoadErrorScaffold(
          message: 'Could not load league: ${leaguesAsync.error}');
    }
    if (hubsAsync.hasError) {
      return _LoadErrorScaffold(
          message: 'Could not load hub: ${hubsAsync.error}');
    }
    if (teamsAsync.hasError) {
      return _LoadErrorScaffold(
          message: 'Could not load team: ${teamsAsync.error}');
    }

    final league = (leaguesAsync.valueOrNull ?? const <League>[])
        .cast<League?>()
        .firstWhere((league) => league?.id == widget.leagueId,
            orElse: () => null);
    final hub = (hubsAsync.valueOrNull ?? const <Hub>[])
        .cast<Hub?>()
        .firstWhere((hub) => hub?.id == widget.hubId, orElse: () => null);
    final team = (teamsAsync.valueOrNull ?? const <Team>[])
        .cast<Team?>()
        .firstWhere((team) => team?.id == widget.teamId, orElse: () => null);
    if (league == null || hub == null || team == null) {
      return const _LoadErrorScaffold(message: 'Team not found.');
    }
    _seed(team, league, hub);
    final identity = _identity!;

    return _StructureFormScaffold(
      title: 'Edit Team',
      heading: 'Update team details',
      icon: Icons.groups_2_outlined,
      actionLabel: 'Save Team',
      saving: _saving,
      onSubmit: org == null ? null : () => _save(org.id, league, hub, team),
      child: Column(
        children: [
          _FormCard(
            children: [
              GlassTextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                labelText: 'Team Name',
                hintText: 'e.g. Calgary U11 AA',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlassTextFormField(
                      controller: _ageCtrl,
                      textInputAction: TextInputAction.next,
                      labelText: 'Age Group',
                      hintText: 'U11',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassTextFormField(
                      controller: _divCtrl,
                      textInputAction: TextInputAction.done,
                      labelText: 'Division',
                      hintText: 'AA',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _IdentityPicker(
            title: 'Team logo',
            subtitle: 'Keep this team logo, inherit a parent, or choose new.',
            selection: identity,
            fallbackIcon: Icons.groups_2_outlined,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String orgId, League league, Hub hub, Team team) async {
    final identity = _identity;
    final name = _nameCtrl.text.trim();
    if (identity == null) return;
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final authDb = ref.read(authorizedFirestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;
      final logoUrl = await _uploadIdentityLogo(
        orgId: orgId,
        entityType: 'teams',
        entityId: team.id,
        currentUserId: currentUser.id,
        pickedFile: identity.pickedImage,
      );
      final effectiveLogoUrl = logoUrl ?? identity.effectiveImageUrl;
      await authDb
          .updateTeamFields(currentUser, orgId, league.id, hub.id, team.id, {
        'name': name,
        'ageGroup': _ageCtrl.text.trim().isEmpty ? null : _ageCtrl.text.trim(),
        'division': _divCtrl.text.trim().isEmpty ? null : _divCtrl.text.trim(),
        'logoUrl': effectiveLogoUrl,
        'iconName':
            effectiveLogoUrl == null ? identity.effectiveIconName : null,
      });
      if (mounted) context.pop();
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to edit teams');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Could not save team: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Team row (swipe to delete)
// ---------------------------------------------------------------------------

class _TeamRow extends StatelessWidget {
  final Team team;
  final VoidCallback onDelete;
  const _TeamRow({required this.team, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () => context.push(
          '/teams/${team.id}?leagueId=${team.leagueId}&hubId=${team.hubId}',
        ),
        child: Dismissible(
          key: Key(team.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppGlassColors.rose.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: AppGlassColors.rose),
          ),
          confirmDismiss: (_) => showConfirmationDialog(
            context,
            title: 'Delete Team',
            message: 'Delete "${team.name}"?',
            confirmLabel: 'Delete',
            confirmColor: AppColors.danger,
          ),
          onDismissed: (_) => onDelete(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                EntityAvatar(
                  name: team.name,
                  imageUrl: team.logoUrl,
                  iconName: team.iconName,
                  fallbackIcon: Icons.groups_outlined,
                  size: 28,
                  color: AppGlassColors.aqua,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(team.name,
                      style: const TextStyle(
                          fontSize: 13, color: AppGlassColors.ink)),
                ),
                if (team.ageGroup != null || team.division != null)
                  Text(
                    [team.ageGroup, team.division]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 11, color: AppGlassColors.inkMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassAddButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _GlassAddButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 24,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 18, 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: AppGlassColors.aqua, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppGlassColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _GlassMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppGlassColors.inkSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellLoadingScaffold extends ConsumerWidget {
  final String title;

  const _ShellLoadingScaffold({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerLeague =
        resolveHeaderLeague(ref.watch(leaguesProvider).valueOrNull ?? [], null);

    return AppShellScaffold(
      header: AppShellHeader(
        title: title,
        leadingIcon: Icons.account_tree_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.logoUrl?.isNotEmpty == true
            ? headerLeague?.name
            : null,
        showBackButton: true,
        backFallbackLocation: '/settings/leagues',
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppGlassColors.aqua),
      ),
    );
  }
}

class _StructureFormScaffold extends ConsumerWidget {
  final String title;
  final String heading;
  final IconData icon;
  final String actionLabel;
  final bool saving;
  final VoidCallback? onSubmit;
  final Widget child;

  const _StructureFormScaffold({
    required this.title,
    required this.heading,
    required this.icon,
    required this.actionLabel,
    required this.saving,
    required this.onSubmit,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerLeague =
        resolveHeaderLeague(ref.watch(leaguesProvider).valueOrNull ?? [], null);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context, extra: 106);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AppShellScaffold(
      header: AppShellHeader(
        title: title,
        leadingIcon: icon,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.logoUrl?.isNotEmpty == true
            ? headerLeague?.name
            : null,
        showBackButton: true,
        backFallbackLocation: '/settings/leagues',
      ),
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              topContentPadding,
              16,
              bottomContentPadding,
            ),
            children: [
              AppGlassSurface(
                padding: const EdgeInsets.all(14),
                radius: 24,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppGlassColors.aqua.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppGlassColors.aqua.withValues(alpha: 0.26),
                        ),
                      ),
                      child: Icon(icon, color: AppGlassColors.aqua, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppGlassColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 16,
            child: GlassSubmitButton(
              label: actionLabel,
              isLoading: saving,
              onTap: onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;

  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _LoadErrorScaffold extends StatelessWidget {
  final String message;

  const _LoadErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      header: const AppShellHeader(
        title: 'Manage Structure',
        leadingIcon: Icons.account_tree_outlined,
        showBackButton: true,
        backFallbackLocation: '/settings/leagues',
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          appShellTopPadding(context),
          16,
          appShellBottomPadding(context, extra: 24),
        ),
        children: [
          _GlassMessageCard(
            icon: Icons.error_outline,
            title: 'Could not load this page',
            message: message,
            color: AppGlassColors.rose,
          ),
        ],
      ),
    );
  }
}

class _IdentitySelection {
  final String defaultIconName;
  final String? inheritedImageUrl;
  final String? inheritedIconName;
  final String? inheritedLabel;
  String? imageUrl;
  String? iconName;
  PickedFileBytes? pickedImage;
  bool useInherited;

  _IdentitySelection({
    required this.defaultIconName,
    String? initialImageUrl,
    String? initialIconName,
    this.inheritedImageUrl,
    this.inheritedIconName,
    this.inheritedLabel,
  })  : imageUrl = initialImageUrl,
        iconName = initialIconName ?? defaultIconName,
        useInherited = inheritedImageUrl != null || inheritedIconName != null;

  String? get effectiveInheritedImageUrl =>
      useInherited ? inheritedImageUrl : null;

  String? get effectiveImageUrl => useInherited ? inheritedImageUrl : imageUrl;

  String? get effectiveIconName {
    if (pickedImage != null) return null;
    if (effectiveImageUrl != null && effectiveImageUrl!.isNotEmpty) {
      return null;
    }
    if (useInherited) return inheritedIconName ?? defaultIconName;
    return iconName ?? defaultIconName;
  }
}

class _IdentityPicker extends StatelessWidget {
  final String title;
  final String subtitle;
  final _IdentitySelection selection;
  final IconData fallbackIcon;
  final VoidCallback onChanged;

  const _IdentityPicker({
    required this.title,
    required this.subtitle,
    required this.selection,
    required this.fallbackIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final previewName = selection.pickedImage?.name ?? title;
    final previewImageUrl = selection.effectiveImageUrl;
    final previewIconName = selection.useInherited
        ? selection.inheritedIconName
        : selection.iconName;

    return AppGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EntityAvatar(
                name: previewName,
                imageUrl: previewImageUrl,
                iconName:
                    selection.pickedImage != null ? null : previewIconName,
                fallbackIcon: fallbackIcon,
                size: 48,
                color: AppGlassColors.aqua,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppGlassColors.ink,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppGlassColors.inkMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (selection.inheritedLabel != null) ...[
            const SizedBox(height: 12),
            GlassChoiceChip(
              icon: Icons.check,
              label: selection.inheritedLabel!,
              selected: selection.useInherited,
              onTap: () {
                selection.useInherited = !selection.useInherited;
                if (selection.useInherited) selection.pickedImage = null;
                onChanged();
              },
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entityIconOptions.entries.map((entry) {
              final selected = !selection.useInherited &&
                  selection.pickedImage == null &&
                  selection.iconName == entry.key;
              return GlassChoiceChip(
                icon: entry.value,
                label: _iconLabel(entry.key),
                selected: selected,
                onTap: () {
                  selection.useInherited = false;
                  selection.pickedImage = null;
                  selection.imageUrl = null;
                  selection.iconName = entry.key;
                  onChanged();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          GlassChoiceChip(
            icon: Icons.image_outlined,
            label: selection.pickedImage == null
                ? 'Upload image'
                : selection.pickedImage!.name,
            selected: selection.pickedImage != null,
            onTap: () async {
              final picked = await pickImageBytes();
              if (picked == null) return;
              selection.useInherited = false;
              selection.imageUrl = null;
              selection.pickedImage = picked;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

String _iconLabel(String key) {
  switch (key) {
    case 'league':
      return 'League';
    case 'hub':
      return 'Hub';
    case 'team':
      return 'Team';
    case 'calendar':
      return 'Event';
    case 'trophy':
      return 'Trophy';
    case 'shield':
      return 'Shield';
  }
  return key;
}

Future<String?> _uploadIdentityLogo({
  required String orgId,
  required String entityType,
  required String entityId,
  required String currentUserId,
  required PickedFileBytes? pickedFile,
}) async {
  if (pickedFile == null) return null;

  final extension = pickedFile.name.split('.').last.toLowerCase();
  final contentType = switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/png',
  };
  final safeName = pickedFile.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final path =
      'orgs/$orgId/logos/$entityType/$entityId/$currentUserId/${DateTime.now().microsecondsSinceEpoch}_$safeName';

  return StorageService().uploadBytes(
    bytes: pickedFile.bytes,
    path: path,
    contentType: contentType,
  );
}
