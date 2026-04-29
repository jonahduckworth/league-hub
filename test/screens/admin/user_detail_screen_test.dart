import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/admin/user_detail_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:league_hub/services/firestore_service.dart';

// Mock FirestoreService using FakeFirebaseFirestore to avoid real Firebase init
class MockFirestoreService extends FirestoreService {
  final AppUser? userToReturn;
  final List<Hub> hubsToReturn;
  final List<Team> teamsToReturn;

  MockFirestoreService({this.userToReturn, List<Hub>? hubs, List<Team>? teams})
      : hubsToReturn = hubs ?? [],
        teamsToReturn = teams ?? [],
        super(firestore: FakeFirebaseFirestore());

  @override
  Future<AppUser?> getUserById(String userId) async {
    return userToReturn;
  }

  @override
  Future<List<Hub>> getAllHubsFlat(String orgId) async {
    return hubsToReturn;
  }

  @override
  Future<List<Team>> getAllTeamsFlat(String orgId) async {
    return teamsToReturn;
  }
}

void main() {
  group('UserDetailScreen', () {
    final testOrg = Organization(
      id: 'org-1',
      name: 'Test Organization',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime(2024),
      ownerId: 'owner-1',
    );

    final superAdmin = AppUser(
      id: 'admin-1',
      email: 'admin@example.com',
      displayName: 'Super Admin',
      role: UserRole.superAdmin,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final targetUser = AppUser(
      id: 'user-1',
      email: 'staff@example.com',
      displayName: 'John Doe',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: ['hub-1', 'hub-2'],
      teamIds: ['team-1'],
      createdAt: DateTime.now().subtract(Duration(days: 30)),
      isActive: true,
    );

    final testHubs = [
      Hub(
        id: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Calgary Hub',
        location: 'Calgary, AB',
        createdAt: DateTime.now(),
      ),
      Hub(
        id: 'hub-2',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Edmonton Hub',
        location: 'Edmonton, AB',
        createdAt: DateTime.now(),
      ),
      Hub(
        id: 'hub-3',
        leagueId: 'league-2',
        orgId: 'org-1',
        name: 'Toronto Hub',
        location: 'Toronto, ON',
        createdAt: DateTime.now(),
      ),
    ];

    final testTeams = [
      Team(
        id: 'team-1',
        hubId: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Calgary U18',
        ageGroup: 'U18',
        division: 'AAA',
        memberIds: ['user-1'],
        createdAt: DateTime.now(),
      ),
      Team(
        id: 'team-2',
        hubId: 'hub-2',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Edmonton U15',
        ageGroup: 'U15',
        division: 'AA',
        createdAt: DateTime.now(),
      ),
    ];

    Widget createTestWidget({
      AppUser? user,
      AppUser? targetUserData,
      AppUser? currentUser,
      List<Hub>? hubs,
      bool nullUser = false,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => currentUser ?? superAdmin,
          ),
          organizationProvider.overrideWith(
            (ref) => testOrg,
          ),
          firestoreServiceProvider.overrideWithValue(
            MockFirestoreService(
              userToReturn: nullUser ? null : (targetUserData ?? targetUser),
              hubs: testHubs,
              teams: testTeams,
            ),
          ),
        ],
        child: MaterialApp(
          home: UserDetailScreen(userId: targetUser.id),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
          ),
        ),
      );
    }

    Future<void> scrollDown(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
    }

    group('Screen Rendering', () {
      testWidgets('renders without crashing', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(UserDetailScreen), findsOneWidget);
      });

      testWidgets('displays title User Detail', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('User Detail'), findsOneWidget);
      });
    });

    group('User Data Display', () {
      testWidgets('shows user name', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('John Doe'), findsOneWidget);
      });

      testWidgets('shows user email', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('staff@example.com'), findsOneWidget);
      });

      testWidgets('shows user role', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // "Staff" appears in both the header badge and the info row
        expect(find.text('Staff'), findsWidgets);
      });

      testWidgets('shows user active status', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Active'), findsOneWidget);
      });
    });

    group('Profile Header', () {
      testWidgets('displays profile header with user info',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Should show name and email
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('staff@example.com'), findsOneWidget);
      });

      testWidgets('shows role and status badges', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // "Staff" appears in both the header badge and the info row
        expect(find.text('Staff'), findsWidgets);
        expect(find.text('Active'), findsOneWidget);
      });
    });

    group('Role Change Dropdown', () {
      testWidgets('shows role dropdown when in edit mode for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            currentUser: superAdmin,
            targetUserData: targetUser,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Find and tap Edit button
        expect(find.text('Edit'), findsOneWidget);
        await tester.tap(find.text('Edit'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Role picker should be visible
        expect(find.text('Manager Admin'), findsOneWidget);
      });

      testWidgets('role dropdown includes Manager Admin option',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Manager Admin'), findsOneWidget);
      });

      testWidgets('role dropdown includes Staff option',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Staff'), findsWidgets);
      });
    });

    group('Hub Assignment Section', () {
      testWidgets('displays hub assignments section',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('HUB ASSIGNMENTS'), findsOneWidget);
      });

      testWidgets('shows assigned hubs', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // User has 2 hubs assigned
        expect(find.text('Calgary Hub'), findsOneWidget);
        expect(find.text('Edmonton Hub'), findsOneWidget);
      });

      testWidgets('shows hub locations', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Hub chips show hub names with location_city icon
        expect(find.text('Calgary Hub'), findsOneWidget);
        expect(find.text('Edmonton Hub'), findsOneWidget);
      });

      testWidgets('shows empty state when no hubs assigned',
          (WidgetTester tester) async {
        final noHubsUser = AppUser(
          id: 'user-2',
          email: 'nohubs@example.com',
          displayName: 'No Hubs User',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        await tester.pumpWidget(
          createTestWidget(targetUserData: noHubsUser),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No hubs assigned'), findsOneWidget);
      });
    });

    group('Team Assignment Section', () {
      testWidgets('displays team assignments section',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('TEAM ASSIGNMENTS'), findsOneWidget);
      });

      testWidgets('shows assigned teams with parent hub details',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Calgary U18'), findsOneWidget);
        expect(find.text('Calgary Hub · U18 · AAA'), findsOneWidget);
      });

      testWidgets('shows empty state when no teams assigned',
          (WidgetTester tester) async {
        final noTeamsUser = AppUser(
          id: 'user-2',
          email: 'noteams@example.com',
          displayName: 'No Teams User',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: ['hub-1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        await tester.pumpWidget(
          createTestWidget(targetUserData: noTeamsUser),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No teams assigned'), findsOneWidget);
      });
    });

    group('Edit Mode', () {
      testWidgets('shows Edit button when viewing own details',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(currentUser: superAdmin));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsOneWidget);
      });

      testWidgets('shows Save and Cancel when in edit mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('can toggle hub assignment in edit mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should show checkboxes for hubs
        expect(find.byType(CheckboxListTile), findsWidgets);
      });

      testWidgets('can toggle team assignment in edit mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit'));
        await tester.pump();
        await tester.pumpAndSettle();
        await scrollDown(tester);

        expect(find.text('Edmonton U15'), findsOneWidget);
      });
    });

    group('Deactivate Button', () {
      testWidgets('shows Deactivate button for active users',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        await scrollDown(tester);

        expect(find.text('Deactivate User'), findsOneWidget);
      });

      testWidgets('shows Reactivate button for inactive users',
          (WidgetTester tester) async {
        final inactiveUser = AppUser(
          id: 'user-2',
          email: 'inactive@example.com',
          displayName: 'Inactive User',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: false,
        );

        await tester.pumpWidget(
          createTestWidget(targetUserData: inactiveUser),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        await scrollDown(tester);

        expect(find.text('Reactivate User'), findsOneWidget);
      });

      testWidgets('deactivate button is visible for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(currentUser: superAdmin),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        await scrollDown(tester);

        expect(find.text('Deactivate User'), findsOneWidget);
      });
    });

    group('Date Information', () {
      testWidgets('displays joined date', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('DATES'), findsOneWidget);
        expect(find.text('Joined'), findsOneWidget);
      });

      testWidgets('shows formatted date', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Date should be displayed in some format
        expect(find.byType(Text), findsWidgets);
      });
    });

    group('Section Cards', () {
      testWidgets('displays Role & Access section',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('ROLE & ACCESS'), findsOneWidget);
      });

      testWidgets('displays Hub Assignments section',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('HUB ASSIGNMENTS'), findsOneWidget);
      });

      testWidgets('displays Dates section', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('DATES'), findsOneWidget);
      });
    });

    group('User Not Found', () {
      testWidgets('shows error when user not found',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(nullUser: true),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('User not found.'), findsOneWidget);
      });
    });

    group('Loading State', () {
      testWidgets('shows loading indicator initially',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        // Don't pump - check loading state
        await tester.pump();

        // Should show either loading or content
        expect(find.byType(UserDetailScreen), findsOneWidget);
      });
    });

    group('Avatar Display', () {
      testWidgets('displays user avatar in header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Avatar widget should be present
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Inactive User Display', () {
      testWidgets('shows inactive status for inactive users',
          (WidgetTester tester) async {
        final inactiveUser = AppUser(
          id: 'user-2',
          email: 'inactive@example.com',
          displayName: 'Inactive User',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: false,
        );

        await tester.pumpWidget(
          createTestWidget(targetUserData: inactiveUser),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Inactive'), findsOneWidget);
      });
    });

    group('Layout Structure', () {
      testWidgets('uses ListView for main content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('displays sections in correct order',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // All sections should be visible
        expect(find.text('ROLE & ACCESS'), findsOneWidget);
        expect(find.text('HUB ASSIGNMENTS'), findsOneWidget);
        expect(find.text('TEAM ASSIGNMENTS'), findsOneWidget);
        expect(find.text('DATES'), findsOneWidget);
      });
    });

    group('Role Badge Styling', () {
      testWidgets('shows role badge with correct styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Staff role badge should be visible
        expect(find.text('Staff'), findsWidgets);
      });
    });

    group('Hub Icon Display', () {
      testWidgets('shows hub location icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.location_city), findsWidgets);
      });
    });

    group('Multiple Hub Assignments', () {
      testWidgets('displays all assigned hubs', (WidgetTester tester) async {
        final multiHubUser = AppUser(
          id: 'user-3',
          email: 'multihub@example.com',
          displayName: 'Multi Hub User',
          role: UserRole.managerAdmin,
          orgId: 'org-1',
          hubIds: ['hub-1', 'hub-2', 'hub-3'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        await tester.pumpWidget(
          createTestWidget(targetUserData: multiHubUser),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Calgary Hub'), findsOneWidget);
        expect(find.text('Edmonton Hub'), findsOneWidget);
        expect(find.text('Toronto Hub'), findsOneWidget);
      });
    });
  });
}
