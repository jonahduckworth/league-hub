import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

// ---------------------------------------------------------------------------
// Local data classes used only during the wizard (not persisted to Firestore
// until the final step).
// ---------------------------------------------------------------------------

class _LeagueEntry {
  final String name;
  final String abbreviation;
  _LeagueEntry({required this.name, required this.abbreviation});
}

class _HubEntry {
  final String name;
  final String location;
  _HubEntry({required this.name, required this.location});
}

class _TeamEntry {
  final String name;
  final String ageGroup;
  final String division;
  _TeamEntry(
      {required this.name, required this.ageGroup, required this.division});
}

// ---------------------------------------------------------------------------
// Wizard screen
// ---------------------------------------------------------------------------

class OrgCreationScreen extends StatefulWidget {
  const OrgCreationScreen({super.key});

  @override
  State<OrgCreationScreen> createState() => _OrgCreationScreenState();
}

class _OrgCreationScreenState extends State<OrgCreationScreen> {
  // Step index: 0 = Details, 1 = Leagues, 2 = Hubs, 3 = Teams
  int _step = 0;
  bool _isLoading = false;

  // --- Step 0 fields ---
  final _orgNameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // --- Step 1: Leagues ---
  final _leagueNameCtrl = TextEditingController();
  final _leagueAbbrevCtrl = TextEditingController();
  final List<_LeagueEntry> _leagues = [];

  // --- Step 2: Hubs (keyed by league index) ---
  int _selectedLeagueIdx = 0;
  final _hubNameCtrl = TextEditingController();
  final _hubLocationCtrl = TextEditingController();
  final Map<int, List<_HubEntry>> _hubsByLeague = {};

  // --- Step 3: Teams (keyed by "leagueIdx-hubIdx") ---
  int _selectedLeagueForTeams = 0;
  int _selectedHubForTeams = 0;
  final _teamNameCtrl = TextEditingController();
  final _teamAgeCtrl = TextEditingController();
  final _teamDivCtrl = TextEditingController();
  final Map<String, List<_TeamEntry>> _teamsByHub = {};

  @override
  void dispose() {
    _orgNameCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _leagueNameCtrl.dispose();
    _leagueAbbrevCtrl.dispose();
    _hubNameCtrl.dispose();
    _hubLocationCtrl.dispose();
    _teamNameCtrl.dispose();
    _teamAgeCtrl.dispose();
    _teamDivCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Validation helpers
  // -------------------------------------------------------------------------

  bool _validateStep0() {
    if (_orgNameCtrl.text.trim().isEmpty) {
      _showError('Please enter an organization name.');
      return false;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Please enter your name.');
      return false;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Please enter your email.');
      return false;
    }
    if (_passwordCtrl.text.length < 6) {
      _showError('Password must be at least 6 characters.');
      return false;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _showError('Passwords do not match.');
      return false;
    }
    return true;
  }

  bool _validateStep1() {
    if (_leagues.isEmpty) {
      _showError('Add at least one league to continue.');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  void _next() {
    if (_step == 0 && !_validateStep0()) return;
    if (_step == 1 && !_validateStep1()) return;
    if (_step == 3) {
      _finishSetup();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
  }

  // -------------------------------------------------------------------------
  // League helpers
  // -------------------------------------------------------------------------

  void _addLeague() {
    final name = _leagueNameCtrl.text.trim();
    final abbrev = _leagueAbbrevCtrl.text.trim();
    if (name.isEmpty || abbrev.isEmpty) {
      _showError('Enter league name and abbreviation.');
      return;
    }
    setState(() {
      _leagues.add(_LeagueEntry(name: name, abbreviation: abbrev));
      _leagueNameCtrl.clear();
      _leagueAbbrevCtrl.clear();
    });
  }

  void _removeLeague(int index) {
    setState(() {
      _leagues.removeAt(index);
      _hubsByLeague.remove(index);
      _selectedLeagueIdx = 0;
    });
  }

  // -------------------------------------------------------------------------
  // Hub helpers
  // -------------------------------------------------------------------------

  void _addHub() {
    final name = _hubNameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Enter a hub name.');
      return;
    }
    setState(() {
      _hubsByLeague.putIfAbsent(_selectedLeagueIdx, () => []);
      _hubsByLeague[_selectedLeagueIdx]!
          .add(_HubEntry(name: name, location: _hubLocationCtrl.text.trim()));
      _hubNameCtrl.clear();
      _hubLocationCtrl.clear();
    });
  }

  void _removeHub(int leagueIdx, int hubIdx) {
    setState(() {
      _hubsByLeague[leagueIdx]?.removeAt(hubIdx);
      _teamsByHub.remove('$leagueIdx-$hubIdx');
    });
  }

  // -------------------------------------------------------------------------
  // Team helpers
  // -------------------------------------------------------------------------

  void _addTeam() {
    final name = _teamNameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Enter a team name.');
      return;
    }
    final key = '$_selectedLeagueForTeams-$_selectedHubForTeams';
    setState(() {
      _teamsByHub.putIfAbsent(key, () => []);
      _teamsByHub[key]!.add(_TeamEntry(
        name: name,
        ageGroup: _teamAgeCtrl.text.trim(),
        division: _teamDivCtrl.text.trim(),
      ));
      _teamNameCtrl.clear();
      _teamAgeCtrl.clear();
      _teamDivCtrl.clear();
    });
  }

  void _removeTeam(String key, int teamIdx) {
    setState(() => _teamsByHub[key]?.removeAt(teamIdx));
  }

  // -------------------------------------------------------------------------
  // Finish: write everything to Firestore
  // -------------------------------------------------------------------------

  Future<void> _finishSetup() async {
    setState(() => _isLoading = true);
    try {
      // 1. Create Firebase Auth account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(_nameCtrl.text.trim());

      final db = FirebaseFirestore.instance;
      final now = DateTime.now().toIso8601String();

      // 2. Create organization document
      final orgRef = db.collection('organizations').doc();
      final orgId = orgRef.id;
      await orgRef.set({
        'id': orgId,
        'name': _orgNameCtrl.text.trim(),
        'logoUrl': null,
        'primaryColor': '#1A3A5C',
        'secondaryColor': '#2E75B6',
        'accentColor': '#4DA3FF',
        'ownerId': uid,
        'createdAt': now,
      });

      // 3. Create user document
      await db.collection('users').doc(uid).set({
        'id': uid,
        'email': _emailCtrl.text.trim(),
        'displayName': _nameCtrl.text.trim(),
        'role': 'superAdmin',
        'orgId': orgId,
        'isOwner': true,
        'hubIds': [],
        'teamIds': [],
        'createdAt': now,
        'isActive': true,
      });

      // 4. Create leagues → hubs → teams as subcollections
      final createdLeagues = <Map<String, String>>[];
      for (int li = 0; li < _leagues.length; li++) {
        final league = _leagues[li];
        final leagueRef = orgRef.collection('leagues').doc();
        final leagueId = leagueRef.id;
        await leagueRef.set({
          'id': leagueId,
          'orgId': orgId,
          'name': league.name,
          'abbreviation': league.abbreviation,
          'description': null,
          'createdAt': now,
        });
        createdLeagues.add({'id': leagueId, 'name': league.name});

        final hubs = _hubsByLeague[li] ?? [];
        for (int hi = 0; hi < hubs.length; hi++) {
          final hub = hubs[hi];
          final hubRef = leagueRef.collection('hubs').doc();
          final hubId = hubRef.id;
          await hubRef.set({
            'id': hubId,
            'leagueId': leagueId,
            'orgId': orgId,
            'name': hub.name,
            'location': hub.location.isEmpty ? null : hub.location,
            'createdAt': now,
          });

          final teams = _teamsByHub['$li-$hi'] ?? [];
          for (final team in teams) {
            final teamRef = hubRef.collection('teams').doc();
            await teamRef.set({
              'id': teamRef.id,
              'hubId': hubId,
              'leagueId': leagueId,
              'orgId': orgId,
              'name': team.name,
              'ageGroup': team.ageGroup.isEmpty ? null : team.ageGroup,
              'division': team.division.isEmpty ? null : team.division,
              'createdAt': now,
            });
          }
        }
      }

      // 5. Auto-create a General chat room for each league.
      for (final league in createdLeagues) {
        final chatRef = db.collection('organizations').doc(orgId).collection('chatRooms').doc();
        await chatRef.set({
          'orgId': orgId,
          'name': '${league['name']} – General',
          'type': 'league',
          'leagueId': league['id'],
          'participants': [],
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageBy': null,
        });
      }

      if (mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return 'Account creation failed. Please try again.';
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  static const _stepLabels = ['Details', 'Leagues', 'Hubs', 'Teams'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Organization'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : _back,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _StepIndicator(current: _step, labels: _stepLabels),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStep(),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildDetailsStep();
      case 1:
        return _buildLeaguesStep();
      case 2:
        return _buildHubsStep();
      case 3:
        return _buildTeamsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar() {
    final isLast = _step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _next,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                isLast ? 'Finish Setup' : 'Next',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 0 — Org Details
  // -------------------------------------------------------------------------

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
            icon: Icons.location_city_outlined, title: 'Organization'),
        const SizedBox(height: 12),
        _card(children: [
          TextField(
            controller: _orgNameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Organization Name',
              hintText: 'e.g. Metro Sports Alliance',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        _SectionHeader(icon: Icons.person_outlined, title: 'Your Account'),
        const SizedBox(height: 12),
        _card(children: [
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Step 1 — Leagues
  // -------------------------------------------------------------------------

  Widget _buildLeaguesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
            icon: Icons.emoji_events_outlined, title: 'Add Leagues'),
        const SizedBox(height: 4),
        const Text(
          'Add all the leagues in your organization.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _card(children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _leagueNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'League Name',
                    hintText: 'e.g. Hockey Super League',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _leagueAbbrevCtrl,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Abbrev.',
                    hintText: 'HSL',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: _addLeague,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    minimumSize: Size.zero,
                  ),
                  child: const Icon(Icons.add, size: 20),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 16),
        if (_leagues.isEmpty)
          const Center(
            child: Text(
              'No leagues added yet',
              style: TextStyle(
                  color: AppColors.textMuted, fontStyle: FontStyle.italic),
            ),
          )
        else
          ..._leagues.asMap().entries.map((e) => _LeagueChip(
                league: e.value,
                onDelete: () => _removeLeague(e.key),
              )),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Step 2 — Hubs
  // -------------------------------------------------------------------------

  Widget _buildHubsStep() {
    final hubs = _hubsByLeague[_selectedLeagueIdx] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(icon: Icons.location_on_outlined, title: 'Add Hubs'),
        const SizedBox(height: 4),
        const Text(
          'Hubs are physical locations (arenas, rinks, fields).',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (_leagues.length > 1) ...[
          const Text('League',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          _LeagueSelector(
            leagues: _leagues,
            selected: _selectedLeagueIdx,
            onChanged: (i) => setState(() {
              _selectedLeagueIdx = i;
              _hubNameCtrl.clear();
              _hubLocationCtrl.clear();
            }),
          ),
          const SizedBox(height: 16),
        ],
        _card(children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _hubNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Hub Name',
                    hintText: 'e.g. Calgary',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _hubLocationCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Calgary, AB',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: _addHub,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    minimumSize: Size.zero,
                  ),
                  child: const Icon(Icons.add, size: 20),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 16),
        if (hubs.isEmpty)
          Center(
            child: Text(
              'No hubs added for ${_leagues[_selectedLeagueIdx].name} yet',
              style: const TextStyle(
                  color: AppColors.textMuted, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...hubs.asMap().entries.map((e) => _HubChip(
                hub: e.value,
                onDelete: () => _removeHub(_selectedLeagueIdx, e.key),
              )),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Step 3 — Teams
  // -------------------------------------------------------------------------

  Widget _buildTeamsStep() {
    final hubs = _hubsByLeague[_selectedLeagueForTeams] ?? [];
    final teamKey = '$_selectedLeagueForTeams-$_selectedHubForTeams';
    final teams = _teamsByHub[teamKey] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(icon: Icons.groups_outlined, title: 'Add Teams'),
        const SizedBox(height: 4),
        const Text(
          'Add teams to each hub. Age group and division are optional.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (_leagues.length > 1) ...[
          const Text('League',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          _LeagueSelector(
            leagues: _leagues,
            selected: _selectedLeagueForTeams,
            onChanged: (i) => setState(() {
              _selectedLeagueForTeams = i;
              _selectedHubForTeams = 0;
              _teamNameCtrl.clear();
              _teamAgeCtrl.clear();
              _teamDivCtrl.clear();
            }),
          ),
          const SizedBox(height: 16),
        ],
        if (hubs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No hubs in this league. Go back to add hubs first, or skip this step.',
                    style: TextStyle(fontSize: 13, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          )
        else ...[
          const Text('Hub',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          _HubSelector(
            hubs: hubs,
            selected: _selectedHubForTeams,
            onChanged: (i) => setState(() {
              _selectedHubForTeams = i;
              _teamNameCtrl.clear();
              _teamAgeCtrl.clear();
              _teamDivCtrl.clear();
            }),
          ),
          const SizedBox(height: 16),
          _card(children: [
            TextField(
              controller: _teamNameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                hintText: 'e.g. Calgary U11 AA',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _teamAgeCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Age Group',
                      hintText: 'U11',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _teamDivCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Division',
                      hintText: 'AA',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _addTeam,
              icon: const Icon(Icons.add),
              label: const Text('Add Team'),
            ),
          ]),
          const SizedBox(height: 16),
          if (teams.isEmpty)
            const Center(
              child: Text(
                'No teams added yet',
                style: TextStyle(
                    color: AppColors.textMuted, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...teams.asMap().entries.map((e) => _TeamChip(
                  team: e.value,
                  onDelete: () => _removeTeam(teamKey, e.key),
                )),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

Widget _card({required List<Widget> children}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.text)),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;
  const _StepIndicator({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: labels.asMap().entries.map((e) {
          final i = e.key;
          final label = e.value;
          final isActive = i == current;
          final isDone = i < current;
          final color =
              isDone || isActive ? AppColors.accent : AppColors.border;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < labels.length - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LeagueSelector extends StatelessWidget {
  final List<_LeagueEntry> leagues;
  final int selected;
  final ValueChanged<int> onChanged;
  const _LeagueSelector(
      {required this.leagues,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: leagues.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                leagues[i].abbreviation,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HubSelector extends StatelessWidget {
  final List<_HubEntry> hubs;
  final int selected;
  final ValueChanged<int> onChanged;
  const _HubSelector(
      {required this.hubs, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hubs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.border),
              ),
              child: Text(
                hubs[i].name,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeagueChip extends StatelessWidget {
  final _LeagueEntry league;
  final VoidCallback onDelete;
  const _LeagueChip({required this.league, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(league.abbreviation,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(league.name,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.text))),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _HubChip extends StatelessWidget {
  final _HubEntry hub;
  final VoidCallback onDelete;
  const _HubChip({required this.hub, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hub.name,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: FontWeight.w500)),
                if (hub.location.isNotEmpty)
                  Text(hub.location,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final _TeamEntry team;
  final VoidCallback onDelete;
  const _TeamChip({required this.team, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: FontWeight.w500)),
                if (team.ageGroup.isNotEmpty || team.division.isNotEmpty)
                  Text(
                    [team.ageGroup, team.division]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
