import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/picked_file.dart';
import '../core/utils.dart';
import '../services/storage_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/auth_flow_widgets.dart';
import '../widgets/entity_avatar.dart';
import '../widgets/glass_form_widgets.dart';

// ---------------------------------------------------------------------------
// Local data classes used only during the wizard (not persisted to Firestore
// until the final step).
// ---------------------------------------------------------------------------

class _LeagueEntry {
  final String name;
  final String abbreviation;
  final _LogoChoice logoChoice;
  _LeagueEntry({
    required this.name,
    required this.abbreviation,
    required this.logoChoice,
  });
}

class _HubEntry {
  final String name;
  final String location;
  final _LogoChoice logoChoice;
  _HubEntry({
    required this.name,
    required this.location,
    required this.logoChoice,
  });
}

class _TeamEntry {
  final String name;
  final String ageGroup;
  final String division;
  final _LogoChoice logoChoice;
  _TeamEntry({
    required this.name,
    required this.ageGroup,
    required this.division,
    required this.logoChoice,
  });
}

class _LogoChoice {
  final String? iconName;
  final PickedFileBytes? image;
  final bool useInherited;

  const _LogoChoice({
    this.iconName,
    this.image,
    this.useInherited = false,
  });
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
  String _leagueIconName = 'league';
  PickedFileBytes? _leagueLogoImage;

  // --- Step 2: Hubs (keyed by league index) ---
  int _selectedLeagueIdx = 0;
  final _hubNameCtrl = TextEditingController();
  final _hubLocationCtrl = TextEditingController();
  final Map<int, List<_HubEntry>> _hubsByLeague = {};
  String _hubIconName = 'hub';
  PickedFileBytes? _hubLogoImage;
  bool _hubUseLeagueLogo = true;

  // --- Step 3: Teams (keyed by "leagueIdx-hubIdx") ---
  int _selectedLeagueForTeams = 0;
  int _selectedHubForTeams = 0;
  final _teamNameCtrl = TextEditingController();
  final _teamAgeCtrl = TextEditingController();
  final _teamDivCtrl = TextEditingController();
  final Map<String, List<_TeamEntry>> _teamsByHub = {};
  String _teamIconName = 'team';
  PickedFileBytes? _teamLogoImage;
  bool _teamUseParentLogo = true;

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
      _showError('Please enter a league name.');
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
    AppUtils.showErrorSnackBar(context, message);
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
      _leagues.add(_LeagueEntry(
        name: name,
        abbreviation: abbrev,
        logoChoice: _LogoChoice(
          iconName: _leagueLogoImage == null ? _leagueIconName : null,
          image: _leagueLogoImage,
        ),
      ));
      _leagueNameCtrl.clear();
      _leagueAbbrevCtrl.clear();
      _leagueIconName = 'league';
      _leagueLogoImage = null;
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
      _hubsByLeague[_selectedLeagueIdx]!.add(_HubEntry(
        name: name,
        location: _hubLocationCtrl.text.trim(),
        logoChoice: _LogoChoice(
          iconName:
              _hubLogoImage == null && !_hubUseLeagueLogo ? _hubIconName : null,
          image: _hubLogoImage,
          useInherited: _hubLogoImage == null && _hubUseLeagueLogo,
        ),
      ));
      _hubNameCtrl.clear();
      _hubLocationCtrl.clear();
      _hubIconName = 'hub';
      _hubLogoImage = null;
      _hubUseLeagueLogo = true;
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
        logoChoice: _LogoChoice(
          iconName: _teamLogoImage == null && !_teamUseParentLogo
              ? _teamIconName
              : null,
          image: _teamLogoImage,
          useInherited: _teamLogoImage == null && _teamUseParentLogo,
        ),
      ));
      _teamNameCtrl.clear();
      _teamAgeCtrl.clear();
      _teamDivCtrl.clear();
      _teamIconName = 'team';
      _teamLogoImage = null;
      _teamUseParentLogo = true;
    });
  }

  void _removeTeam(String key, int teamIdx) {
    setState(() => _teamsByHub[key]?.removeAt(teamIdx));
  }

  String _parentLogoLabel() {
    final hubs = _hubsByLeague[_selectedLeagueForTeams] ?? [];
    if (hubs.isEmpty || _selectedHubForTeams >= hubs.length) {
      return 'Use league logo';
    }
    final hub = hubs[_selectedHubForTeams];
    return hub.logoChoice.useInherited
        ? 'Use league logo'
        : 'Use ${hub.name} logo';
  }

  // -------------------------------------------------------------------------
  // Finish: write everything to Firestore
  // -------------------------------------------------------------------------

  Future<void> _finishSetup() async {
    setState(() => _isLoading = true);
    try {
      // 1. Create Firebase Auth account
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
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
        'hubIds': [],
        'teamIds': [],
        'createdAt': now,
        'isActive': true,
      });

      // 4. Create leagues → hubs → teams as subcollections
      final createdLeagues = <Map<String, String?>>[];
      for (int li = 0; li < _leagues.length; li++) {
        final league = _leagues[li];
        final leagueRef = orgRef.collection('leagues').doc();
        final leagueId = leagueRef.id;
        final leagueLogoUrl = await _uploadSetupLogo(
          orgId: orgId,
          entityType: 'leagues',
          entityId: leagueId,
          currentUserId: uid,
          pickedFile: league.logoChoice.image,
        );
        final leagueIconName =
            leagueLogoUrl == null ? league.logoChoice.iconName : null;
        await leagueRef.set({
          'id': leagueId,
          'orgId': orgId,
          'name': league.name,
          'abbreviation': league.abbreviation,
          'description': null,
          'logoUrl': leagueLogoUrl,
          'iconName': leagueIconName,
          'createdAt': now,
        });
        createdLeagues.add({
          'id': leagueId,
          'name': league.name,
          'logoUrl': leagueLogoUrl,
          'iconName': leagueIconName,
        });

        final hubs = _hubsByLeague[li] ?? [];
        for (int hi = 0; hi < hubs.length; hi++) {
          final hub = hubs[hi];
          final hubRef = leagueRef.collection('hubs').doc();
          final hubId = hubRef.id;
          final uploadedHubLogoUrl = await _uploadSetupLogo(
            orgId: orgId,
            entityType: 'hubs',
            entityId: hubId,
            currentUserId: uid,
            pickedFile: hub.logoChoice.image,
          );
          final hubLogoUrl = uploadedHubLogoUrl ??
              (hub.logoChoice.useInherited ? leagueLogoUrl : null);
          final hubIconName = uploadedHubLogoUrl == null
              ? (hub.logoChoice.useInherited
                  ? leagueIconName
                  : hub.logoChoice.iconName)
              : null;
          await hubRef.set({
            'id': hubId,
            'leagueId': leagueId,
            'orgId': orgId,
            'name': hub.name,
            'location': hub.location.isEmpty ? null : hub.location,
            'logoUrl': hubLogoUrl,
            'iconName': hubIconName,
            'createdAt': now,
          });

          final hubChatRef = db
              .collection('organizations')
              .doc(orgId)
              .collection('chatRooms')
              .doc();
          await hubChatRef.set({
            'orgId': orgId,
            'name': '${hub.name} – General',
            'type': 'league',
            'leagueId': leagueId,
            'hubId': hubId,
            'participants': [],
            'isArchived': false,
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': null,
            'lastMessageAt': FieldValue.serverTimestamp(),
            'lastMessageBy': null,
            'roomIconName': hubIconName,
            'roomImageUrl': hubLogoUrl,
          });

          final teams = _teamsByHub['$li-$hi'] ?? [];
          for (final team in teams) {
            final teamRef = hubRef.collection('teams').doc();
            final teamId = teamRef.id;
            final uploadedTeamLogoUrl = await _uploadSetupLogo(
              orgId: orgId,
              entityType: 'teams',
              entityId: teamId,
              currentUserId: uid,
              pickedFile: team.logoChoice.image,
            );
            final teamLogoUrl = uploadedTeamLogoUrl ??
                (team.logoChoice.useInherited
                    ? (hubLogoUrl ?? leagueLogoUrl)
                    : null);
            final teamIconName = uploadedTeamLogoUrl == null
                ? (team.logoChoice.useInherited
                    ? (hubIconName ?? leagueIconName)
                    : team.logoChoice.iconName)
                : null;
            await teamRef.set({
              'id': teamId,
              'hubId': hubId,
              'leagueId': leagueId,
              'orgId': orgId,
              'name': team.name,
              'ageGroup': team.ageGroup.isEmpty ? null : team.ageGroup,
              'division': team.division.isEmpty ? null : team.division,
              'logoUrl': teamLogoUrl,
              'iconName': teamIconName,
              'createdAt': now,
            });
          }
        }
      }

      // 5. Auto-create a General chat room for each league.
      for (final league in createdLeagues) {
        final chatRef = db
            .collection('organizations')
            .doc(orgId)
            .collection('chatRooms')
            .doc();
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
          'hubId': null,
          'roomIconName': league['iconName'],
          'roomImageUrl': league['logoUrl'],
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

  static const _stepLabels = ['Account', 'League', 'Hubs', 'Teams'];

  @override
  Widget build(BuildContext context) {
    return AppGlassRouteBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            AuthTopBar(
              title: 'Create League',
              icon: Icons.emoji_events_outlined,
              onBack: _isLoading ? () {} : _back,
            ),
            _StepIndicator(current: _step, labels: _stepLabels),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  22 + MediaQuery.paddingOf(context).bottom,
                ),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: GlassSubmitButton(
        label: isLast ? 'Create League' : 'Next',
        isLoading: _isLoading,
        onTap: _isLoading ? null : _next,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 0 — League Details
  // -------------------------------------------------------------------------

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(icon: Icons.emoji_events_outlined, title: 'League'),
        const SizedBox(height: 12),
        _card(children: [
          GlassTextFormField(
            controller: _orgNameCtrl,
            textInputAction: TextInputAction.next,
            labelText: 'League Name',
            hintText: 'e.g. Junior Prospects Hockey League',
            leadingIcon: Icons.emoji_events_outlined,
          ),
        ]),
        const SizedBox(height: 24),
        _SectionHeader(icon: Icons.person_outlined, title: 'Your Account'),
        const SizedBox(height: 12),
        _card(children: [
          GlassTextFormField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            labelText: 'Your Name',
            leadingIcon: Icons.person_outlined,
          ),
          const SizedBox(height: 14),
          GlassTextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            labelText: 'Email',
            leadingIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 14),
          GlassTextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            labelText: 'Password',
            leadingIcon: Icons.lock_outlined,
            suffixIcon: glassPasswordToggle(
              obscure: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 14),
          GlassTextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            labelText: 'Confirm Password',
            leadingIcon: Icons.lock_outlined,
            suffixIcon: glassPasswordToggle(
              obscure: _obscureConfirm,
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
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
        _SectionHeader(icon: Icons.emoji_events_outlined, title: 'Add Leagues'),
        const SizedBox(height: 4),
        const Text(
          'Create your first league. You can add more leagues later.',
          style: TextStyle(
            fontSize: 13,
            color: AppGlassColors.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _card(children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: GlassTextFormField(
                  controller: _leagueNameCtrl,
                  textInputAction: TextInputAction.next,
                  labelText: 'League Name',
                  hintText: 'e.g. Hockey Super League',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: GlassTextFormField(
                  controller: _leagueAbbrevCtrl,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  labelText: 'Abbrev.',
                  hintText: 'HSL',
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _AddIconButton(
                  tooltip: 'Add league',
                  onTap: _addLeague,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LogoPicker(
            title: 'League logo',
            subtitle: 'Choose an icon or upload a league logo.',
            iconName: _leagueIconName,
            pickedImage: _leagueLogoImage,
            fallbackIcon: Icons.emoji_events_outlined,
            onIconSelected: (iconName) => setState(() {
              _leagueIconName = iconName;
              _leagueLogoImage = null;
            }),
            onImagePicked: (image) => setState(() {
              _leagueLogoImage = image;
            }),
          ),
        ]),
        const SizedBox(height: 16),
        if (_leagues.isEmpty)
          const Center(
            child: Text(
              'No leagues added yet',
              style: TextStyle(
                color: AppGlassColors.inkMuted,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
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
          style: TextStyle(
            fontSize: 13,
            color: AppGlassColors.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (_leagues.length > 1) ...[
          const Text('League',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppGlassColors.inkMuted,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          _LeagueSelector(
            leagues: _leagues,
            selected: _selectedLeagueIdx,
            onChanged: (i) => setState(() {
              _selectedLeagueIdx = i;
              _hubNameCtrl.clear();
              _hubLocationCtrl.clear();
              _hubIconName = 'hub';
              _hubLogoImage = null;
              _hubUseLeagueLogo = true;
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
                child: GlassTextFormField(
                  controller: _hubNameCtrl,
                  textInputAction: TextInputAction.next,
                  labelText: 'Hub Name',
                  hintText: 'e.g. Calgary',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: GlassTextFormField(
                  controller: _hubLocationCtrl,
                  textInputAction: TextInputAction.done,
                  labelText: 'Location',
                  hintText: 'Calgary, AB',
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _AddIconButton(
                  tooltip: 'Add hub',
                  onTap: _addHub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LogoPicker(
            title: 'Hub logo',
            subtitle:
                'Use the league logo, choose an icon, or upload a hub logo.',
            iconName: _hubIconName,
            pickedImage: _hubLogoImage,
            fallbackIcon: Icons.location_on_outlined,
            inheritedLabel:
                'Use ${_leagues[_selectedLeagueIdx].abbreviation} logo',
            useInherited: _hubUseLeagueLogo,
            onInheritedChanged: (value) => setState(() {
              _hubUseLeagueLogo = value;
              if (value) _hubLogoImage = null;
            }),
            onIconSelected: (iconName) => setState(() {
              _hubUseLeagueLogo = false;
              _hubIconName = iconName;
              _hubLogoImage = null;
            }),
            onImagePicked: (image) => setState(() {
              _hubUseLeagueLogo = false;
              _hubLogoImage = image;
            }),
          ),
        ]),
        const SizedBox(height: 16),
        if (hubs.isEmpty)
          Center(
            child: Text(
              'No hubs added for ${_leagues[_selectedLeagueIdx].name} yet',
              style: const TextStyle(
                color: AppGlassColors.inkMuted,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
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
          style: TextStyle(
            fontSize: 13,
            color: AppGlassColors.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (_leagues.length > 1) ...[
          const Text('League',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppGlassColors.inkMuted,
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
              _teamIconName = 'team';
              _teamLogoImage = null;
              _teamUseParentLogo = true;
            }),
          ),
          const SizedBox(height: 16),
        ],
        if (hubs.isEmpty)
          AppGlassSurface(
            padding: const EdgeInsets.all(16),
            radius: 22,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppGlassColors.gold, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No hubs in this league. Go back to add hubs first, or skip this step.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppGlassColors.inkSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
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
                  color: AppGlassColors.inkMuted,
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
              _teamIconName = 'team';
              _teamLogoImage = null;
              _teamUseParentLogo = true;
            }),
          ),
          const SizedBox(height: 16),
          _card(children: [
            GlassTextFormField(
              controller: _teamNameCtrl,
              textInputAction: TextInputAction.next,
              labelText: 'Team Name',
              hintText: 'e.g. Calgary U11 AA',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GlassTextFormField(
                    controller: _teamAgeCtrl,
                    textInputAction: TextInputAction.next,
                    labelText: 'Age Group',
                    hintText: 'U11',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassTextFormField(
                    controller: _teamDivCtrl,
                    textInputAction: TextInputAction.done,
                    labelText: 'Division',
                    hintText: 'AA',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LogoPicker(
              title: 'Team logo',
              subtitle:
                  'Use the hub or league logo, choose an icon, or upload a team logo.',
              iconName: _teamIconName,
              pickedImage: _teamLogoImage,
              fallbackIcon: Icons.groups_outlined,
              inheritedLabel: _parentLogoLabel(),
              useInherited: _teamUseParentLogo,
              onInheritedChanged: (value) => setState(() {
                _teamUseParentLogo = value;
                if (value) _teamLogoImage = null;
              }),
              onIconSelected: (iconName) => setState(() {
                _teamUseParentLogo = false;
                _teamIconName = iconName;
                _teamLogoImage = null;
              }),
              onImagePicked: (image) => setState(() {
                _teamUseParentLogo = false;
                _teamLogoImage = image;
              }),
            ),
            const SizedBox(height: 14),
            AuthSecondaryButton(
              label: 'Add Team',
              icon: Icons.add,
              onTap: _addTeam,
            ),
          ]),
          const SizedBox(height: 16),
          if (teams.isEmpty)
            const Center(
              child: Text(
                'No teams added yet',
                style: TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
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
  return GlassFormCard(children: children);
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppGlassColors.aqua),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppGlassColors.ink)),
      ],
    );
  }
}

class _AddIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _AddIconButton({
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppGlassSurface(
        width: 52,
        height: 52,
        padding: EdgeInsets.zero,
        radius: 18,
        onTap: onTap,
        child: const Icon(
          Icons.add,
          color: AppGlassColors.aqua,
          size: 22,
        ),
      ),
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
              isDone || isActive ? AppGlassColors.aqua : AppGlassColors.border;
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
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive
                              ? AppGlassColors.aqua
                              : AppGlassColors.inkMuted,
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
      {required this.leagues, required this.selected, required this.onChanged});

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
          return GlassChoiceChip(
            label: leagues[i].abbreviation,
            selected: isSelected,
            height: 38,
            onTap: () => onChanged(i),
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
          return GlassChoiceChip(
            label: hubs[i].name,
            selected: isSelected,
            height: 38,
            onTap: () => onChanged(i),
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
    return AppGlassSurface(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 20,
      child: Row(
        children: [
          EntityAvatar(
            name: league.abbreviation,
            iconName: league.logoChoice.iconName,
            fallbackIcon: Icons.emoji_events_outlined,
            textFallback: league.abbreviation,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              league.name,
              style: const TextStyle(
                fontSize: 14,
                color: AppGlassColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                size: 18, color: AppGlassColors.inkMuted),
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
    return AppGlassSurface(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 20,
      child: Row(
        children: [
          EntityAvatar(
            name: hub.name,
            iconName: hub.logoChoice.iconName,
            fallbackIcon: Icons.location_on_outlined,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hub.name,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppGlassColors.ink,
                        fontWeight: FontWeight.w700)),
                if (hub.location.isNotEmpty)
                  Text(hub.location,
                      style: const TextStyle(
                          fontSize: 12, color: AppGlassColors.inkMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                size: 18, color: AppGlassColors.inkMuted),
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
    return AppGlassSurface(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 20,
      child: Row(
        children: [
          EntityAvatar(
            name: team.name,
            iconName: team.logoChoice.iconName,
            fallbackIcon: Icons.groups_outlined,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppGlassColors.ink,
                        fontWeight: FontWeight.w700)),
                if (team.ageGroup.isNotEmpty || team.division.isNotEmpty)
                  Text(
                    [team.ageGroup, team.division]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: AppGlassColors.inkMuted),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                size: 18, color: AppGlassColors.inkMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconName;
  final PickedFileBytes? pickedImage;
  final IconData fallbackIcon;
  final String? inheritedLabel;
  final bool useInherited;
  final ValueChanged<bool>? onInheritedChanged;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<PickedFileBytes> onImagePicked;

  const _LogoPicker({
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.pickedImage,
    required this.fallbackIcon,
    required this.onIconSelected,
    required this.onImagePicked,
    this.inheritedLabel,
    this.useInherited = false,
    this.onInheritedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final previewName = pickedImage?.name ?? title;
    return AppGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EntityAvatar(
                name: previewName,
                iconName:
                    pickedImage == null && !useInherited ? iconName : null,
                fallbackIcon: fallbackIcon,
                size: 46,
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
                          color: AppGlassColors.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ],
          ),
          if (inheritedLabel != null && onInheritedChanged != null) ...[
            const SizedBox(height: 12),
            GlassChoiceChip(
              label: inheritedLabel!,
              selected: useInherited,
              icon: Icons.check,
              onTap: () => onInheritedChanged!(!useInherited),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _setupLogoIcons.entries.map((entry) {
              final selected =
                  pickedImage == null && !useInherited && iconName == entry.key;
              return GlassChoiceChip(
                label: _setupIconLabel(entry.key),
                icon: entry.value,
                selected: selected,
                onTap: () => onIconSelected(entry.key),
                height: 44,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            label: pickedImage == null ? 'Upload image' : pickedImage!.name,
            icon: Icons.image_outlined,
            onTap: () async {
              final picked = await pickImageBytes();
              if (picked == null) return;
              onImagePicked(picked);
            },
          ),
        ],
      ),
    );
  }
}

const _setupLogoIcons = {
  'league': Icons.emoji_events_outlined,
  'hub': Icons.location_on_outlined,
  'team': Icons.groups_2_outlined,
  'calendar': Icons.event_outlined,
  'trophy': Icons.emoji_events_outlined,
  'shield': Icons.shield_outlined,
};

String _setupIconLabel(String key) {
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

Future<String?> _uploadSetupLogo({
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
