export type UserRole = "platformOwner" | "superAdmin" | "managerAdmin" | "staff";
export type InvitationStatus = "pending" | "accepted" | "expired";
export type AnnouncementScope = "league" | "hub" | "team";
export type ChatRoomType = "league" | "event" | "direct";

export type AppUser = {
  id: string;
  email: string;
  displayName: string;
  title?: string | null;
  phone?: string | null;
  avatarUrl?: string | null;
  role: UserRole;
  orgId?: string | null;
  hubIds: string[];
  leagueIds: string[];
  teamIds: string[];
  createdAt?: unknown;
  isActive: boolean;
};

export type Organization = {
  id: string;
  name: string;
  logoUrl?: string | null;
  primaryColor?: string;
  secondaryColor?: string;
  accentColor?: string;
  ownerId?: string;
  createdAt?: unknown;
  scheduleIntegration?: ScheduleIntegration | null;
};

export type ScheduleIntegration = {
  provider: "ramp";
  enabled: boolean;
  autoDiscoverSeason: boolean;
  baseUrl: string;
  associationId: string;
  seasonId: string;
  timezone: string;
  divisionIds: Record<string, string>;
};

export type League = {
  id: string;
  orgId: string;
  name: string;
  abbreviation: string;
  description?: string | null;
  logoUrl?: string | null;
  iconName?: string | null;
  websiteUrl?: string | null;
  instagramUrl?: string | null;
  xUrl?: string | null;
  createdAt?: unknown;
};

export type Hub = {
  id: string;
  orgId: string;
  leagueId: string;
  name: string;
  location?: string | null;
  logoUrl?: string | null;
  iconName?: string | null;
  createdAt?: unknown;
};

export type Team = {
  id: string;
  orgId: string;
  leagueId: string;
  hubId: string;
  name: string;
  ageGroup?: string | null;
  division?: string | null;
  chatRoomId?: string | null;
  logoUrl?: string | null;
  iconName?: string | null;
  memberIds: string[];
  createdAt?: unknown;
};

export type Invitation = {
  id: string;
  orgId: string;
  email: string;
  displayName?: string | null;
  title?: string | null;
  role: UserRole;
  leagueIds: string[];
  hubIds: string[];
  teamIds: string[];
  invitedBy: string;
  invitedByName: string;
  createdAt?: unknown;
  expiresAt?: unknown;
  status: InvitationStatus;
  token?: string;
  emailDeliveryStatus?: "pending" | "retrying" | "delivered" | "failed";
  emailDeliveredAt?: unknown;
};

export type Announcement = {
  id: string;
  orgId: string;
  scope: AnnouncementScope;
  leagueId?: string | null;
  hubId?: string | null;
  teamId?: string | null;
  title: string;
  body: string;
  authorId: string;
  authorName: string;
  authorRole: string;
  attachments: Array<Record<string, unknown>>;
  isPinned: boolean;
  createdAt?: unknown;
};

export type Policy = {
  id: string;
  orgId: string;
  leagueId?: string | null;
  hubId?: string | null;
  teamId?: string | null;
  name: string;
  fileUrl: string;
  fileType: string;
  fileSize: number;
  category: string;
  uploadedBy: string;
  uploadedByName: string;
  versions: Array<Record<string, unknown>>;
  createdAt?: unknown;
  updatedAt?: unknown;
};

export type ChatRoom = {
  id: string;
  orgId: string;
  name: string;
  type: ChatRoomType;
  roomPurpose?: "group" | "event" | null;
  leagueId?: string | null;
  hubId?: string | null;
  teamId?: string | null;
  hubIds?: string[];
  teamIds?: string[];
  participants: string[];
  createdAt?: unknown;
  isArchived: boolean;
  lastMessage?: string | null;
  lastMessageAt?: unknown;
  lastMessageBy?: string | null;
  roomIconName?: string | null;
  roomImageUrl?: string | null;
};

export type ChatMessage = {
  id: string;
  chatRoomId: string;
  senderId: string;
  senderName: string;
  text?: string | null;
  mediaUrl?: string | null;
  mediaType?: string | null;
  createdAt?: unknown;
  editedAt?: unknown;
  deleted: boolean;
  readBy: string[];
};

export type AuditLog = {
  id: string;
  action: string;
  actorId: string;
  actorName?: string;
  actorRole?: string;
  createdAt?: unknown;
  request?: Record<string, unknown>;
  result?: Record<string, unknown>;
};

export type NotificationEvent = {
  id: string;
  type: string;
  title: string;
  body: string;
  requestedTokens: number;
  successCount: number;
  failureCount: number;
  staleTokenCount: number;
  createdAt?: unknown;
};

export type ScheduleEvent = {
  id: string;
  sourceUid: string;
  sourceSeasonId?: string;
  teamIds: string[];
  hubIds: string[];
  leagueIds: string[];
  division?: string | null;
  title: string;
  firstTeamName: string;
  secondTeamName: string;
  startsAt: unknown;
  endsAt: unknown;
  timezone: string;
  localDate?: string | null;
  localStartTime?: string | null;
  localEndTime?: string | null;
  location?: string | null;
  status: "scheduled" | "final" | "removed";
  firstScore?: number | null;
  secondScore?: number | null;
  isActive: boolean;
};

export type ScheduleSyncState = {
  status: "ok" | "warning" | "error" | "running";
  message: string;
  sourceSeasonId?: string;
  seasonDiscoveryStatus?: "disabled" | "matched" | "warning";
  seasonDiscoveryMessage?: string;
  discoveredSeasonId?: string;
  seasonAutoUpdated?: boolean;
  lastAttemptAt?: unknown;
  lastSuccessAt?: unknown;
  teamFeedsTotal?: number;
  teamFeedsSucceeded?: number;
  teamFeedsFailed?: number;
  eventCount?: number;
  added?: number;
  updated?: number;
  replaced?: number;
  removed?: number;
  removalsSkipped?: boolean;
};

export type AdminMetrics = {
  users: number;
  activeUsers: number;
  pendingInvites: number;
  leagues: number;
  hubs: number;
  teams: number;
  policies: number;
  announcements: number;
  chatRooms: number;
  orphanedTeamAssignments: number;
};

export type AdminData = {
  orgs: Organization[];
  selectedOrg?: Organization;
  users: AppUser[];
  invitations: Invitation[];
  leagues: League[];
  hubs: Hub[];
  teams: Team[];
  announcements: Announcement[];
  policies: Policy[];
  chatRooms: ChatRoom[];
  auditLogs: AuditLog[];
  notificationEvents: NotificationEvent[];
  scheduleEvents: ScheduleEvent[];
  scheduleSync?: ScheduleSyncState;
};

export type HealthCheck = {
  id: string;
  label: string;
  severity: "good" | "warning" | "danger";
  value: string;
};
