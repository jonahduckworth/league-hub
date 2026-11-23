import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/design_system.dart';
import '../core/league_branding.dart';
import '../models/info_centre.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/info_centre_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/bottom_sheet_handle.dart';
import '../widgets/glass_form_widgets.dart';

final infoCentreServiceProvider = Provider((ref) => InfoCentreService());
final infoCentreProvider =
    FutureProvider.autoDispose<InfoCentreData>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (user == null || !user.isActive || orgId == null) {
    return const InfoCentreData();
  }
  return ref.watch(infoCentreServiceProvider).load(orgId);
});

class InfoCentreScreen extends ConsumerStatefulWidget {
  const InfoCentreScreen({super.key});
  @override
  ConsumerState<InfoCentreScreen> createState() => _InfoCentreScreenState();
}

class _InfoCentreScreenState extends ConsumerState<InfoCentreScreen> {
  String? _hubId;
  String? _scopeKey;
  String? _revealing;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (mounted) _message('Could not open this link. Please try again.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _message('Copied');
  }

  Future<void> _reveal(InfoCentreItem item) async {
    if (_revealing != null) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    if (user == null || orgId == null) return;
    setState(() => _revealing = item.id);
    try {
      final password =
          await ref.read(infoCentreServiceProvider).reveal(orgId, item.id);
      if (!mounted ||
          ref.read(currentUserProvider).valueOrNull?.id != user.id ||
          ref.read(organizationProvider).valueOrNull?.id != orgId) {
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(item.title),
                content: _PasswordContent(
                    password: password,
                    userId: user.id,
                    orgId: orgId,
                    accessKey: _accessKey(user)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ],
              ));
    } catch (_) {
      if (mounted) {
        _message(
            'This password is unavailable or your access changed. Refresh and try again.');
      }
    } finally {
      if (mounted) setState(() => _revealing = null);
    }
  }

  Future<void> _chooseHub(InfoCentreData data, String? selectedHub) async {
    final scopeKey = _scopeKey;
    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.64),
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      builder: (_) => _HubPickerSheet(data: data, selectedHub: selectedHub),
    );
    if (!mounted || result == null || _scopeKey != scopeKey) return;
    final currentData = ref.read(infoCentreProvider).valueOrNull;
    if (result.isNotEmpty &&
        currentData?.hubs.any((hub) => hub['id'] == result) != true) {
      return;
    }
    setState(() => _hubId = result.isEmpty ? null : result);
  }

  Widget _buildSection(
      InfoCentreData data, InfoCentreItem section, String? selectedHub) {
    final entries = data.entries
        .where((entry) =>
            entry.sectionId == section.id &&
            data.visibleInHub(entry, selectedHub))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(section.title,
                style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.2)),
          ),
          const SizedBox(height: 4),
          Text(data.scopeLabel(section),
              style: const TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const AppGlassSurface(
              width: double.infinity,
              quality: appGlassListSurfaceQuality,
              child: Text('No published resources in this section.',
                  style: TextStyle(
                      color: AppGlassColors.inkSecondary,
                      fontSize: 15,
                      height: 1.5)),
            ),
          for (final item in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildResource(data, item),
            ),
        ],
      ),
    );
  }

  Widget _buildResource(InfoCentreData data, InfoCentreItem item) {
    return AppGlassSurface(
      width: double.infinity,
      quality: appGlassListSurfaceQuality,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title,
              style: const TextStyle(
                  color: AppGlassColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(data.scopeLabel(item),
              style: const TextStyle(color: AppGlassColors.aqua, fontSize: 13)),
          if (item.notes?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(item.notes!,
                  style: const TextStyle(
                      color: AppGlassColors.inkSecondary,
                      fontSize: 15,
                      height: 1.5)),
            ),
          if (item.inviteCode?.isNotEmpty ?? false)
            Row(children: [
              Expanded(
                child: Text('Invite code: ${item.inviteCode}',
                    style: const TextStyle(color: AppGlassColors.ink)),
              ),
              IconButton(
                  tooltip: 'Copy invite code',
                  onPressed: () => _copy(item.inviteCode!),
                  icon: const Icon(Icons.copy, color: AppGlassColors.aqua)),
            ]),
          if (item.hasPassword && item.canReveal)
            TextButton.icon(
                onPressed: _revealing == null ? () => _reveal(item) : null,
                icon: const Icon(Icons.lock_outline),
                label: Text(_revealing == item.id
                    ? 'Checking access…'
                    : 'Reveal password')),
          if (item.hasPassword && !item.canReveal)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Password available to managers and admins',
                    style: TextStyle(color: AppGlassColors.inkMuted))),
          if (item.policyId?.isNotEmpty ?? false)
            TextButton.icon(
                onPressed: () => context.push('/policy/${item.policyId}'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Open policy')),
          if (item.url?.isNotEmpty ?? false)
            TextButton.icon(
                onPressed: () => _open(item.url!),
                icon: const Icon(Icons.open_in_new),
                label: Text(item.kind == 'registration'
                    ? 'Open registration'
                    : item.kind == 'document'
                        ? 'Open document'
                        : 'Visit website')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(infoCentreProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final orgId = ref.watch(organizationProvider).valueOrNull?.id;
    final scopeKey = '${user?.id}:$orgId';
    if (_scopeKey != scopeKey) {
      _scopeKey = scopeKey;
      _hubId = null;
    }
    final data = state.valueOrNull;
    final selectedHub = data?.hubs.any((hub) => hub['id'] == _hubId) == true
        ? _hubId
        : data?.hubs.length == 1
            ? data!.hubs.first['id'] as String
            : null;
    final selectedHubName = data?.hubs
        .where((hub) => hub['id'] == selectedHub)
        .firstOrNull?['name'] as String?;
    final selectedLeagueId = data?.hubs
        .where((hub) => hub['id'] == selectedHub)
        .firstOrNull?['leagueId'] as String?;
    final headerLeague = resolveHeaderLeague(
        ref.watch(leaguesProvider).valueOrNull ?? [], selectedLeagueId);
    return AppShellScaffold(
      header: AppShellHeader(
          title: 'Info Centre',
          leadingIcon: Icons.menu_book_outlined,
          leadingImageUrl: headerLeague?.logoUrl,
          leadingLabel: headerLeague?.name ?? 'League Hub'),
      child: state.when(
        loading: () => const AppLoadingState(label: 'Loading resources…'),
        error: (_, __) => AppErrorState(
            title: 'Unable to load Info Centre',
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(infoCentreProvider)),
        data: (data) {
          final sections = data.sections
              .where((item) => data.visibleInHub(item, selectedHub))
              .toList();
          return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(infoCentreProvider);
                await ref.read(infoCentreProvider.future);
              },
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, appShellTopPadding(context),
                      16, appShellBottomPadding(context)),
                  children: [
                    if (data.hubs.length > 1) ...[
                      AppGlassSurface(
                        key: const ValueKey('info-hub-filter'),
                        radius: 22,
                        semanticLabel:
                            'Hub, ${selectedHubName ?? 'All my hubs'}. Choose hub',
                        onTap: () => _chooseHub(data, selectedHub),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                color: AppGlassColors.aqua),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Hub',
                                      style: TextStyle(
                                          color: AppGlassColors.inkMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedHubName ?? 'All my hubs',
                                    style: const TextStyle(
                                        color: AppGlassColors.ink,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.expand_more,
                                color: AppGlassColors.inkSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (user != null &&
                        ref
                            .read(permissionServiceProvider)
                            .canManageInfoCentre(user))
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                              onPressed: () =>
                                  _open('https://jdb-league-hub.web.app/#info'),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Manage in portal'))),
                    if (sections.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(children: [
                            Icon(Icons.menu_book_outlined,
                                size: 42, color: AppGlassColors.inkMuted),
                            SizedBox(height: 16),
                            Text('No resources yet',
                                style: TextStyle(
                                    color: AppGlassColors.ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 8),
                            Text(
                                'Published resources for your hubs and teams will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppGlassColors.inkSecondary,
                                    height: 1.5)),
                          ])),
                    for (final section in sections)
                      _buildSection(data, section, selectedHub),
                  ]));
        },
      ),
    );
  }
}

class _HubPickerSheet extends StatefulWidget {
  final InfoCentreData data;
  final String? selectedHub;

  const _HubPickerSheet({required this.data, required this.selectedHub});

  @override
  State<_HubPickerSheet> createState() => _HubPickerSheetState();
}

class _HubPickerSheetState extends State<_HubPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _leagueName(Map<String, dynamic> hub) =>
      widget.data.leagues
          .where((league) => league['id'] == hub['leagueId'])
          .firstOrNull?['name'] as String? ??
      '';

  @override
  Widget build(BuildContext context) {
    final hubs = widget.data.hubs.where((hub) {
      final text = '${hub['name']} ${_leagueName(hub)}'.toLowerCase();
      return text.contains(_query);
    }).toList()
      ..sort((a, b) => (a['name'] as String)
          .toLowerCase()
          .compareTo((b['name'] as String).toLowerCase()));
    return SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
          final availableHeight = (constraints.maxHeight - keyboardInset - 16)
              .clamp(0.0, constraints.maxHeight);
          return Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, keyboardInset + 8),
            child: SizedBox(
              height: availableHeight * 0.78,
              width: 600,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppGlassColors.pageMid,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: AppGlassSurface(
                  key: const ValueKey('info-hub-picker'),
                  radius: 28,
                  padding: EdgeInsets.zero,
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                          child: Column(
                            children: [
                              const BottomSheetHandle(),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Choose hub',
                                        style: TextStyle(
                                            color: AppGlassColors.ink,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel',
                                        style: TextStyle(
                                            color: AppGlassColors.aqua)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GlassTextFormField(
                                key: const ValueKey('info-hub-search'),
                                controller: _searchController,
                                labelText: 'Search hubs',
                                leadingIcon: Icons.search,
                                autocorrect: false,
                                textInputAction: TextInputAction.search,
                                onChanged: (value) => setState(
                                    () => _query = value.trim().toLowerCase()),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.close,
                                            color: AppGlassColors.inkSecondary),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _hubOption(
                            id: '',
                            title: 'All my hubs',
                            selected: widget.selectedHub == null),
                      ),
                      const SliverToBoxAdapter(
                          child: Divider(
                              height: 16, color: AppGlassColors.border)),
                      if (hubs.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(18, 8, 18, 24),
                            child: Text('No hubs match your search.',
                                style: TextStyle(
                                    color: AppGlassColors.inkSecondary,
                                    fontSize: 15)),
                          ),
                        ),
                      SliverList.builder(
                        itemCount: hubs.length,
                        itemBuilder: (context, index) {
                          final hub = hubs[index];
                          return _hubOption(
                              id: hub['id'] as String,
                              title: hub['name'] as String,
                              subtitle: _leagueName(hub),
                              selected: widget.selectedHub == hub['id']);
                        },
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }));
  }

  Widget _hubOption({
    required String id,
    required String title,
    String? subtitle,
    required bool selected,
  }) {
    return Semantics(
      selected: selected,
      child: Material(
        color: selected
            ? AppGlassColors.aqua.withValues(alpha: 0.1)
            : Colors.transparent,
        child: InkWell(
          key: ValueKey('info-hub-option-$id'),
          onTap: () => Navigator.pop(context, id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppGlassColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.35)),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                color: AppGlassColors.inkMuted,
                                fontSize: 13,
                                height: 1.35)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 22,
                    color: selected
                        ? AppGlassColors.aqua
                        : AppGlassColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _accessKey(AppUser user) =>
    '${user.role}:${user.hubIds.join(',')}:${user.teamIds.join(',')}:${user.leagueIds.join(',')}';

class _PasswordContent extends ConsumerStatefulWidget {
  final String password, userId, orgId, accessKey;
  const _PasswordContent(
      {required this.password,
      required this.userId,
      required this.orgId,
      required this.accessKey});
  @override
  ConsumerState<_PasswordContent> createState() => _PasswordContentState();
}

class _PasswordContentState extends ConsumerState<_PasswordContent> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentUserProvider);
    final user = actor.valueOrNull;
    if (actor.isLoading ||
        user == null ||
        !user.isActive ||
        user.id != widget.userId ||
        _accessKey(user) != widget.accessKey ||
        ref.watch(organizationProvider).valueOrNull?.id != widget.orgId) {
      return const Text(
          'Your access changed. Close this dialog and open the resource again.');
    }
    return Row(children: [
      Expanded(child: Text(_visible ? widget.password : '••••••••')),
      IconButton(
          tooltip: _visible ? 'Hide password' : 'Show password',
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _visible = !_visible)),
      IconButton(
          tooltip: 'Copy password',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.password));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password copied')));
            }
          }),
    ]);
  }
}
