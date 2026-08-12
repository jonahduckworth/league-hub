import type { AdminData, AppUser } from "./types";

export const demoUser: AppUser = {
  id: "demo-owner",
  email: "owner@leaguehub.local",
  displayName: "Jordan Owner",
  role: "platformOwner",
  orgId: "org-demo",
  hubIds: [],
  leagueIds: [],
  teamIds: [],
  createdAt: new Date().toISOString(),
  isActive: true
};

export const demoData: AdminData = {
  orgs: [
    {
      id: "org-demo",
      name: "Prairie Hockey League",
      primaryColor: "#087E8B",
      secondaryColor: "#35A67B",
      accentColor: "#C58220",
      ownerId: "demo-owner",
      scheduleIntegration: {
        provider: "ramp",
        enabled: true,
        autoDiscoverSeason: true,
        baseUrl: "https://juniorprospectshockeyleague.com",
        associationId: "2888",
        seasonId: "12322",
        timezone: "America/Edmonton",
        divisionIds: { "14U": "16624", "15U": "16623", "17U": "23859", "18U": "16622" }
      }
    }
  ],
  selectedOrg: {
    id: "org-demo",
    name: "Prairie Hockey League",
    primaryColor: "#087E8B",
    secondaryColor: "#35A67B",
    accentColor: "#C58220",
    ownerId: "demo-owner",
    scheduleIntegration: {
      provider: "ramp",
      enabled: true,
      autoDiscoverSeason: true,
      baseUrl: "https://juniorprospectshockeyleague.com",
      associationId: "2888",
      seasonId: "12322",
      timezone: "America/Edmonton",
      divisionIds: { "14U": "16624", "15U": "16623", "17U": "23859", "18U": "16622" }
    }
  },
  users: [
    demoUser,
    {
      id: "admin-1",
      email: "admin@prairie.example",
      displayName: "Avery Admin",
      role: "superAdmin",
      orgId: "org-demo",
      hubIds: ["hub-calgary", "hub-reddeer"],
      leagueIds: ["league-winter"],
      teamIds: ["team-u11-aa"],
      isActive: true
    },
    {
      id: "manager-1",
      email: "manager@prairie.example",
      displayName: "Morgan Manager",
      role: "managerAdmin",
      orgId: "org-demo",
      hubIds: ["hub-calgary"],
      leagueIds: ["league-winter"],
      teamIds: ["team-u11-aa"],
      isActive: true
    },
    {
      id: "staff-1",
      email: "staff@prairie.example",
      displayName: "Sam Staff",
      role: "staff",
      orgId: "org-demo",
      hubIds: ["hub-reddeer"],
      leagueIds: ["league-winter"],
      teamIds: ["team-u13-a"],
      isActive: false
    }
  ],
  invitations: [
    {
      id: "invite-1",
      orgId: "org-demo",
      email: "coach@example.com",
      displayName: "Coach New",
      role: "managerAdmin",
      leagueIds: ["league-winter"],
      hubIds: ["hub-calgary"],
      teamIds: [],
      invitedBy: "demo-owner",
      invitedByName: "Jordan Owner",
      createdAt: new Date().toISOString(),
      status: "pending",
      token: "demo-token"
    }
  ],
  leagues: [
    {
      id: "league-winter",
      orgId: "org-demo",
      name: "Winter Hockey",
      abbreviation: "WHL",
      logoUrl: "https://cdn.example.com/winter-hockey.png",
      iconName: "league",
      createdAt: new Date().toISOString()
    }
  ],
  hubs: [
    {
      id: "hub-calgary",
      orgId: "org-demo",
      leagueId: "league-winter",
      name: "Calgary",
      location: "Calgary, AB",
      logoUrl: "https://cdn.example.com/calgary.png",
      iconName: "hub"
    },
    {
      id: "hub-reddeer",
      orgId: "org-demo",
      leagueId: "league-winter",
      name: "Red Deer",
      location: "Red Deer, AB",
      iconName: "hub"
    }
  ],
  teams: [
    {
      id: "team-u11-aa",
      orgId: "org-demo",
      leagueId: "league-winter",
      hubId: "hub-calgary",
      name: "Calgary U11 AA",
      ageGroup: "U11",
      division: "AA",
      logoUrl: "https://cdn.example.com/calgary.png",
      iconName: "team",
      memberIds: ["manager-1"]
    },
    {
      id: "team-u13-a",
      orgId: "org-demo",
      leagueId: "league-winter",
      hubId: "hub-reddeer",
      name: "Red Deer U13 A",
      ageGroup: "U13",
      division: "A",
      memberIds: ["staff-1"]
    }
  ],
  announcements: [
    {
      id: "announcement-1",
      orgId: "org-demo",
      scope: "league",
      leagueId: "league-winter",
      title: "Schedule window posted",
      body: "The next scheduling window is ready.",
      authorId: "admin-1",
      authorName: "Avery Admin",
      authorRole: "superAdmin",
      attachments: [],
      isPinned: true,
      createdAt: new Date().toISOString()
    }
  ],
  policies: [
    {
      id: "policy-1",
      orgId: "org-demo",
      name: "Concussion Protocol",
      fileUrl: "https://example.com/protocol.pdf",
      fileType: "application/pdf",
      fileSize: 184000,
      category: "Safety",
      uploadedBy: "admin-1",
      uploadedByName: "Avery Admin",
      versions: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }
  ],
  chatRooms: [
    {
      id: "room-1",
      orgId: "org-demo",
      name: "Winter Hockey - General",
      type: "league",
      leagueId: "league-winter",
      participants: [],
      isArchived: false,
      lastMessage: "Welcome to the season.",
      lastMessageAt: new Date().toISOString()
    }
  ],
  scheduleEvents: [
    {
      id: "game-upcoming",
      sourceUid: "leaguegame-demo-1@rampinteractive.com",
      sourceSeasonId: "12322",
      teamIds: ["team-u11-aa"],
      hubIds: ["hub-calgary"],
      leagueIds: ["league-winter"],
      division: "17U AAA",
      title: "Wolves HC vs Calgary Rockies",
      firstTeamName: "17U AAA - Wolves HC",
      secondTeamName: "17U AAA - Calgary Rockies",
      startsAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
      endsAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000).toISOString(),
      timezone: "America/Edmonton",
      localDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10),
      localStartTime: "18:30",
      localEndTime: "20:30",
      location: "Great Plains Arena 1, Calgary, AB",
      status: "scheduled",
      isActive: true
    },
    {
      id: "game-final",
      sourceUid: "leaguegame-demo-2@rampinteractive.com",
      sourceSeasonId: "previous-season",
      teamIds: ["team-u13-a"],
      hubIds: ["hub-reddeer"],
      leagueIds: ["league-winter"],
      division: "17U AAA",
      title: "Island HC vs Okanagan HC",
      firstTeamName: "17U AAA - Island HC",
      secondTeamName: "17U AAA - Okanagan HC",
      startsAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
      endsAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000).toISOString(),
      timezone: "America/Edmonton",
      localDate: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10),
      localStartTime: "19:00",
      localEndTime: "21:00",
      location: "Silent Ice Center, Nisku, AB",
      status: "final",
      firstScore: 4,
      secondScore: 2,
      isActive: true
    }
  ],
  scheduleSync: {
    status: "ok",
    message: "RAMP game schedules are up to date.",
    sourceSeasonId: "12322",
    seasonDiscoveryStatus: "matched",
    seasonDiscoveryMessage: "Matched all 48 League Hub teams to JPHL season 12322.",
    discoveredSeasonId: "12322",
    seasonAutoUpdated: false,
    lastAttemptAt: new Date().toISOString(),
    lastSuccessAt: new Date().toISOString(),
    teamFeedsTotal: 48,
    teamFeedsSucceeded: 48,
    teamFeedsFailed: 0,
    eventCount: 320,
    added: 2,
    updated: 318,
    replaced: 1,
    removed: 0,
    removalsSkipped: false
  },
  auditLogs: [
    {
      id: "audit-1",
      action: "adminCreateInvitation",
      actorId: "demo-owner",
      actorName: "Jordan Owner",
      actorRole: "platformOwner",
      createdAt: new Date().toISOString()
    }
  ],
  notificationEvents: [
    {
      id: "notify-1",
      type: "announcement",
      title: "Schedule window posted",
      body: "Avery Admin posted a new announcement",
      requestedTokens: 42,
      successCount: 41,
      failureCount: 1,
      staleTokenCount: 1,
      createdAt: new Date().toISOString()
    }
  ]
};
