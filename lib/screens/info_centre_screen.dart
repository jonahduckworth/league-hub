import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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
                      DropdownButtonFormField<String>(
                          key: ValueKey(selectedHub),
                          initialValue: selectedHub ?? '',
                          decoration: const InputDecoration(labelText: 'Hub'),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('All my hubs')),
                            ...data.hubs.map((hub) => DropdownMenuItem(
                                value: hub['id'] as String,
                                child: Text(hub['name'] as String)))
                          ],
                          onChanged: (value) => setState(
                              () => _hubId = value == '' ? null : value)),
                      const SizedBox(height: 16),
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
                            Icon(Icons.menu_book_outlined, size: 42),
                            SizedBox(height: 16),
                            Text('No resources yet',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w700)),
                            SizedBox(height: 8),
                            Text(
                                'Published resources for your hubs and teams will appear here.',
                                textAlign: TextAlign.center),
                          ])),
                    for (final section in sections) ...[
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(section.title,
                              style: const TextStyle(
                                  color: AppGlassColors.ink,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800))),
                      for (final item in data.entries.where((entry) =>
                          entry.sectionId == section.id &&
                          data.visibleInHub(entry, selectedHub)))
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppGlassSurface(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.title,
                                          style: const TextStyle(
                                              color: AppGlassColors.ink,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(data.scopeLabel(item),
                                          style: const TextStyle(
                                              color: AppGlassColors.aqua)),
                                      if (item.notes?.isNotEmpty ?? false)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 10),
                                            child: Text(item.notes!,
                                                style: const TextStyle(
                                                    color: AppGlassColors
                                                        .inkSecondary))),
                                      if (item.inviteCode?.isNotEmpty ?? false)
                                        Row(children: [
                                          Expanded(
                                              child: Text(
                                                  'Invite code: ${item.inviteCode}',
                                                  style: const TextStyle(
                                                      color:
                                                          AppGlassColors.ink))),
                                          IconButton(
                                              tooltip: 'Copy invite code',
                                              onPressed: () =>
                                                  _copy(item.inviteCode!),
                                              icon: const Icon(Icons.copy)),
                                        ]),
                                      if (item.hasPassword && item.canReveal)
                                        TextButton.icon(
                                            onPressed: _revealing == null
                                                ? () => _reveal(item)
                                                : null,
                                            icon:
                                                const Icon(Icons.lock_outline),
                                            label: Text(_revealing == item.id
                                                ? 'Checking access…'
                                                : 'Reveal password')),
                                      if (item.hasPassword && !item.canReveal)
                                        const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text(
                                                'Password available to managers and admins',
                                                style: TextStyle(
                                                    color: AppGlassColors
                                                        .inkMuted))),
                                      if (item.policyId?.isNotEmpty ?? false)
                                        TextButton.icon(
                                            onPressed: () => context.push(
                                                '/policy/${item.policyId}'),
                                            icon: const Icon(
                                                Icons.description_outlined),
                                            label: const Text('Open policy')),
                                      if (item.url?.isNotEmpty ?? false)
                                        TextButton.icon(
                                            onPressed: () => _open(item.url!),
                                            icon: const Icon(Icons.open_in_new),
                                            label:
                                                Text(item.kind == 'registration'
                                                    ? 'Open registration'
                                                    : item.kind == 'document'
                                                        ? 'Open document'
                                                        : 'Visit website')),
                                    ]))),
                    ],
                  ]));
        },
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
