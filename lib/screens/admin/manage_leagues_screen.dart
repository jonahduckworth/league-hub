import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/league.dart';
import '../../models/hub.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/authorized_firestore_service.dart';

class ManageLeaguesScreen extends ConsumerWidget {
  const ManageLeaguesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final org = ref.watch(organizationProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Manage Leagues & Hubs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: org == null
            ? null
            : () => _showAddLeagueSheet(context, ref, org.id),
        icon: const Icon(Icons.add),
        label: const Text('Add League'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: leaguesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ),
        ),
        data: (leagues) {
          if (leagues.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 64,
                        color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text('No leagues yet',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap the button below to add your first league.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: leagues.length,
            itemBuilder: (_, i) =>
                _LeagueTile(league: leagues[i], orgId: org?.id ?? ''),
          );
        },
      ),
    );
  }

  static Future<void> _showAddLeagueSheet(
      BuildContext context, WidgetRef ref, String orgId) async {
    final nameCtrl = TextEditingController();
    final abbrevCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _AddLeagueSheet(
          nameCtrl: nameCtrl,
          abbrevCtrl: abbrevCtrl,
          orgId: orgId,
          ref: ref),
    );

    nameCtrl.dispose();
    abbrevCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Add League bottom sheet (stateful to handle loading)
// ---------------------------------------------------------------------------

class _AddLeagueSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController abbrevCtrl;
  final String orgId;
  final WidgetRef ref;
  const _AddLeagueSheet(
      {required this.nameCtrl,
      required this.abbrevCtrl,
      required this.orgId,
      required this.ref});

  @override
  State<_AddLeagueSheet> createState() => _AddLeagueSheetState();
}

class _AddLeagueSheetState extends State<_AddLeagueSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add League',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 20),
          TextField(
            controller: widget.nameCtrl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'League Name',
                hintText: 'e.g. Hockey Super League'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: widget.abbrevCtrl,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
                labelText: 'Abbreviation', hintText: 'HSL'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Add League'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = widget.nameCtrl.text.trim();
    final abbrev = widget.abbrevCtrl.text.trim();
    if (name.isEmpty || abbrev.isEmpty) return;
    setState(() => _saving = true);
    try {
      final rawDb = widget.ref.read(firestoreServiceProvider);
      final authDb = widget.ref.read(authorizedFirestoreServiceProvider);
      final currentUser = widget.ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      final id = rawDb.newLeagueId(widget.orgId);
      final league = League(
        id: id,
        orgId: widget.orgId,
        name: name,
        abbreviation: abbrev,
        createdAt: DateTime.now(),
      );
      await authDb.createLeague(currentUser, widget.orgId, league);
      if (mounted) Navigator.pop(context);
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to create leagues'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(league.abbreviation,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          title: Text(league.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.text)),
          subtitle: hubsAsync.maybeWhen(
            data: (hubs) => Text(
              '${hubs.length} hub${hubs.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_location_alt_outlined,
                    color: AppColors.primaryLight, size: 20),
                tooltip: 'Add Hub',
                onPressed: () =>
                    _showAddHubSheet(context, ref, orgId, league.id),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.danger, size: 20),
                tooltip: 'Delete League',
                onPressed: () =>
                    _confirmDelete(context, ref, orgId, league),
              ),
            ],
          ),
          children: [
            hubsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e',
                      style:
                          const TextStyle(color: AppColors.danger))),
              data: (hubs) {
                if (hubs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No hubs yet. Tap + to add one.',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontStyle: FontStyle.italic,
                              fontSize: 13),
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return Column(
                    children: hubs
                        .map((hub) => _HubTile(
                            hub: hub,
                            leagueId: league.id,
                            orgId: orgId))
                        .toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String orgId, League league) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete League'),
        content: Text(
            'Delete "${league.name}"? This will also remove all its hubs and teams.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete')),
        ],
      ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to delete leagues'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  static Future<void> _showAddHubSheet(BuildContext context, WidgetRef ref,
      String orgId, String leagueId) async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _AddHubSheet(
          nameCtrl: nameCtrl,
          locationCtrl: locationCtrl,
          orgId: orgId,
          leagueId: leagueId,
          ref: ref),
    );
    nameCtrl.dispose();
    locationCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Add Hub bottom sheet
// ---------------------------------------------------------------------------

class _AddHubSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController locationCtrl;
  final String orgId;
  final String leagueId;
  final WidgetRef ref;
  const _AddHubSheet(
      {required this.nameCtrl,
      required this.locationCtrl,
      required this.orgId,
      required this.leagueId,
      required this.ref});

  @override
  State<_AddHubSheet> createState() => _AddHubSheetState();
}

class _AddHubSheetState extends State<_AddHubSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add Hub',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 20),
          TextField(
            controller: widget.nameCtrl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'Hub Name', hintText: 'e.g. Calgary'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: widget.locationCtrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
                labelText: 'Location', hintText: 'Calgary, AB'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Add Hub'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = widget.nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final rawDb = widget.ref.read(firestoreServiceProvider);
      final authDb = widget.ref.read(authorizedFirestoreServiceProvider);
      final currentUser = widget.ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      final id = rawDb.newHubId(widget.orgId, widget.leagueId);
      final hub = Hub(
        id: id,
        leagueId: widget.leagueId,
        orgId: widget.orgId,
        name: name,
        location: widget.locationCtrl.text.trim().isEmpty
            ? null
            : widget.locationCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await authDb.createHub(
          currentUser, widget.orgId, widget.leagueId, hub);
      if (mounted) Navigator.pop(context);
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to create hubs'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
  final String leagueId;
  final String orgId;
  const _HubTile(
      {required this.hub, required this.leagueId, required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync =
        ref.watch(teamsProvider((leagueId: leagueId, hubId: hub.id)));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: const Icon(Icons.location_on_outlined,
              color: AppColors.primaryLight, size: 20),
          title: Text(hub.name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          subtitle: hub.location != null
              ? Text(hub.location!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              teamsAsync.maybeWhen(
                data: (teams) => Text(
                  '${teams.length}t',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.group_add_outlined,
                    color: AppColors.accent, size: 18),
                tooltip: 'Add Team',
                onPressed: () =>
                    _showAddTeamSheet(context, ref, orgId, leagueId, hub.id),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.danger, size: 18),
                tooltip: 'Delete Hub',
                onPressed: () =>
                    _confirmDelete(context, ref, orgId, leagueId, hub),
              ),
            ],
          ),
          children: [
            teamsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error: $e',
                      style:
                          const TextStyle(color: AppColors.danger))),
              data: (teams) {
                if (teams.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Text('No teams yet. Tap + to add one.',
                        style: TextStyle(
                            color: AppColors.textMuted,
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
                                  final currentUser = ref.read(currentUserProvider).value;
                                  if (currentUser == null) return;
                                  await ref
                                      .read(authorizedFirestoreServiceProvider)
                                      .deleteTeam(
                                          currentUser, orgId, leagueId, hub.id, t.id);
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String orgId, String leagueId, Hub hub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Hub'),
        content: Text(
            'Delete "${hub.name}"? All its teams will also be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete')),
        ],
      ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to delete hubs'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  static Future<void> _showAddTeamSheet(BuildContext context, WidgetRef ref,
      String orgId, String leagueId, String hubId) async {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final divCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _AddTeamSheet(
          nameCtrl: nameCtrl,
          ageCtrl: ageCtrl,
          divCtrl: divCtrl,
          orgId: orgId,
          leagueId: leagueId,
          hubId: hubId,
          ref: ref),
    );
    nameCtrl.dispose();
    ageCtrl.dispose();
    divCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Add Team bottom sheet
// ---------------------------------------------------------------------------

class _AddTeamSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController ageCtrl;
  final TextEditingController divCtrl;
  final String orgId;
  final String leagueId;
  final String hubId;
  final WidgetRef ref;
  const _AddTeamSheet(
      {required this.nameCtrl,
      required this.ageCtrl,
      required this.divCtrl,
      required this.orgId,
      required this.leagueId,
      required this.hubId,
      required this.ref});

  @override
  State<_AddTeamSheet> createState() => _AddTeamSheetState();
}

class _AddTeamSheetState extends State<_AddTeamSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add Team',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 20),
          TextField(
            controller: widget.nameCtrl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'Team Name', hintText: 'e.g. Calgary U11 AA'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.ageCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Age Group', hintText: 'U11'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.divCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                      labelText: 'Division', hintText: 'AA'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Add Team'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = widget.nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final rawDb = widget.ref.read(firestoreServiceProvider);
      final authDb = widget.ref.read(authorizedFirestoreServiceProvider);
      final currentUser = widget.ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      final id =
          rawDb.newTeamId(widget.orgId, widget.leagueId, widget.hubId);
      final team = Team(
        id: id,
        hubId: widget.hubId,
        leagueId: widget.leagueId,
        orgId: widget.orgId,
        name: name,
        ageGroup: widget.ageCtrl.text.trim().isEmpty
            ? null
            : widget.ageCtrl.text.trim(),
        division: widget.divCtrl.text.trim().isEmpty
            ? null
            : widget.divCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await authDb.createTeam(
          currentUser, widget.orgId, widget.leagueId, widget.hubId, team);
      if (mounted) Navigator.pop(context);
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to create teams'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    return GestureDetector(
      onTap: () => context.push(
        '/teams/${team.id}?leagueId=${team.leagueId}&hubId=${team.hubId}',
      ),
      child: Dismissible(
      key: Key(team.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger.withValues(alpha: 0.1),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Team'),
          content: Text('Delete "${team.name}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger),
                child: const Text('Delete')),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            const Icon(Icons.groups_outlined,
                size: 16, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(team.name,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.text)),
            ),
            if (team.ageGroup != null || team.division != null)
              Text(
                [team.ageGroup, team.division]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(' · '),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
