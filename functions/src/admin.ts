import { randomBytes } from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { db } from "./helpers";
import {
  ActorLike,
  UserRole,
  assignableRoles,
  canAccessOrg,
  canCreateLeague,
  canManageInvitationRole,
  canManageTarget,
  isAdminRole,
  isManagedChatRoomType,
  isValidAnnouncementTarget,
  isValidPolicyCategory,
  isUserRole,
  normalizeStringArray,
  teamMemberRecordsMatchOrg,
} from "./adminLogic";
import { synchronizeOrganizationSchedule } from "./schedule/rampSync";

type DocumentData = FirebaseFirestore.DocumentData;
type FieldValue = FirebaseFirestore.FieldValue;

type Actor = ActorLike & {
  id: string;
  email?: string;
  displayName?: string;
  role: UserRole;
  isActive: true;
};

type RequestRecord = Record<string, unknown>;

const adminRuntime = {
  timeoutSeconds: 60,
  memory: "256MiB" as const,
};

const usersRef = () => db.collection("users");
const orgsRef = () => db.collection("organizations");
const orgRef = (orgId: string) => orgsRef().doc(orgId);
const now = () => admin.firestore.FieldValue.serverTimestamp();
const arrayUnion = (...values: string[]): FieldValue =>
  admin.firestore.FieldValue.arrayUnion(...values);
const arrayRemove = (...values: string[]): FieldValue =>
  admin.firestore.FieldValue.arrayRemove(...values);

function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  return uid;
}

async function loadActor(uid: string): Promise<Actor> {
  const snap = await usersRef().doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "No League Hub user profile exists for this account.");
  }

  const data = snap.data() ?? {};
  const role = data.role;
  if (!isUserRole(role) || !isAdminRole(role)) {
    throw new HttpsError("permission-denied", "Only platform owners and admins can use the admin dashboard.");
  }
  if (data.isActive !== true) {
    throw new HttpsError("permission-denied", "Inactive users cannot use the admin dashboard.");
  }

  return {
    id: snap.id,
    email: data.email as string | undefined,
    displayName: (data.displayName as string | undefined) ?? "Admin",
    orgId: data.orgId as string | undefined,
    role,
    isActive: true,
  };
}

function dataOf(request: CallableRequest): RequestRecord {
  if (request.data == null || typeof request.data !== "object" || Array.isArray(request.data)) {
    return {};
  }
  return request.data as RequestRecord;
}

function optionalString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function requiredString(value: unknown, field: string): string {
  const result = optionalString(value);
  if (!result) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return result;
}

function parseAnnouncementTarget(data: RequestRecord) {
  if (!isValidAnnouncementTarget(data)) {
    throw new HttpsError(
      "invalid-argument",
      "Announcements must target a league, hub, or team with the required parent IDs.",
    );
  }
  const scope = requiredString(data.scope, "scope");
  return {
    scope,
    leagueId: requiredString(data.leagueId, "leagueId"),
    hubId: scope === "league" ? null : requiredString(data.hubId, "hubId"),
    teamId: scope === "team" ? requiredString(data.teamId, "teamId") : null,
  };
}

async function validatedAnnouncementTarget(orgId: string, data: RequestRecord) {
  const target = parseAnnouncementTarget(data);
  const leagueRef = orgRef(orgId).collection("leagues").doc(target.leagueId);
  if (!(await leagueRef.get()).exists) {
    throw new HttpsError("invalid-argument", "The selected announcement league does not exist.");
  }
  if (target.scope === "league") return target;

  const hubRef = leagueRef.collection("hubs").doc(target.hubId!);
  if (!(await hubRef.get()).exists) {
    throw new HttpsError("invalid-argument", "The selected announcement hub is not in that league.");
  }
  if (target.scope === "hub") return target;

  if (!(await hubRef.collection("teams").doc(target.teamId!).get()).exists) {
    throw new HttpsError("invalid-argument", "The selected announcement team is not in that hub.");
  }
  return target;
}

function optionalBoolean(value: unknown): boolean | undefined {
  return typeof value === "boolean" ? value : undefined;
}

function objectValue(value: unknown, field: string): RequestRecord {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${field} must be an object.`);
  }
  return value as RequestRecord;
}

function allowedPatch(value: unknown, field: string, allowedFields: string[]): RequestRecord {
  const patch = objectValue(value, field);
  const allowed = new Set(allowedFields);
  const disallowed = Object.keys(patch).filter((key) => !allowed.has(key));
  if (disallowed.length > 0) {
    throw new HttpsError("invalid-argument", `${field} includes unsupported fields: ${disallowed.join(", ")}.`);
  }
  if (Object.keys(patch).length === 0) {
    throw new HttpsError("invalid-argument", `${field} must include at least one field.`);
  }
  return patch;
}

function requestedOrgId(data: RequestRecord): string {
  return requiredString(data.orgId, "orgId");
}

function assertOrgAccess(actor: Actor, orgId: string): void {
  if (!canAccessOrg(actor, orgId)) {
    throw new HttpsError("permission-denied", "You cannot manage this organization.");
  }
}

function assertScheduleAdmin(actor: Actor): void {
  if (actor.role !== "platformOwner" && actor.role !== "superAdmin") {
    throw new HttpsError(
      "permission-denied",
      "Only platform owners and super admins can configure or refresh the schedule integration.",
    );
  }
}

function docData(snapshot: FirebaseFirestore.DocumentSnapshot): DocumentData {
  return snapshot.data() ?? {};
}

function scrubAuditData(data: RequestRecord): RequestRecord {
  const hiddenKeys = new Set(["token", "password", "secret"]);
  const scrubbed: RequestRecord = {};
  for (const [key, value] of Object.entries(data)) {
    if (hiddenKeys.has(key)) {
      scrubbed[key] = "[redacted]";
    } else if (Array.isArray(value)) {
      scrubbed[key] = value.length <= 12 ? value : { count: value.length };
    } else if (value != null && typeof value === "object") {
      scrubbed[key] = scrubAuditData(value as RequestRecord);
    } else {
      scrubbed[key] = value;
    }
  }
  return scrubbed;
}

async function writeAudit(
  orgId: string,
  actor: Actor,
  action: string,
  data: RequestRecord,
  result: RequestRecord = {},
): Promise<void> {
  await orgRef(orgId).collection("auditLogs").add({
    action,
    actorId: actor.id,
    actorName: actor.displayName ?? actor.email ?? actor.id,
    actorEmail: actor.email ?? null,
    actorRole: actor.role,
    request: scrubAuditData(data),
    result: scrubAuditData(result),
    createdAt: now(),
  });
}

async function withAdmin<T>(
  request: CallableRequest,
  action: string,
  handler: (actor: Actor, data: RequestRecord, orgId: string) => Promise<T>,
): Promise<T> {
  const actor = await loadActor(requireAuth(request));
  const data = dataOf(request);
  const orgId = requestedOrgId(data);
  assertOrgAccess(actor, orgId);
  const result = await handler(actor, data, orgId);
  await writeAudit(orgId, actor, action, data, result && typeof result === "object" ? result as RequestRecord : {});
  return result;
}

async function getStructure(orgId: string) {
  const leaguesSnap = await orgRef(orgId).collection("leagues").orderBy("createdAt").get();
  const leagues = leaguesSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const hubs: DocumentData[] = [];
  const teams: DocumentData[] = [];

  for (const leagueDoc of leaguesSnap.docs) {
    const hubsSnap = await leagueDoc.ref.collection("hubs").orderBy("createdAt").get();
    for (const hubDoc of hubsSnap.docs) {
      hubs.push({ id: hubDoc.id, ...hubDoc.data() });
      const teamsSnap = await hubDoc.ref.collection("teams").orderBy("createdAt").get();
      for (const teamDoc of teamsSnap.docs) {
        teams.push({ id: teamDoc.id, ...teamDoc.data() });
      }
    }
  }

  return { leagues, hubs, teams };
}

async function validateAssignments(
  orgId: string,
  hubIds: string[],
  teamIds: string[],
): Promise<string[]> {
  const structure = await getStructure(orgId);
  const hubById = new Map(structure.hubs.map((hub) => [hub.id as string, hub]));
  const teamById = new Map(structure.teams.map((team) => [team.id as string, team]));

  for (const hubId of hubIds) {
    if (!hubById.has(hubId)) {
      throw new HttpsError("invalid-argument", `Hub ${hubId} is not in this organization.`);
    }
  }
  for (const teamId of teamIds) {
    const team = teamById.get(teamId);
    if (!team) {
      throw new HttpsError("invalid-argument", `Team ${teamId} is not in this organization.`);
    }
    if (!hubIds.includes(team.hubId as string)) {
      throw new HttpsError(
        "invalid-argument",
        `Team ${teamId} must be assigned with its parent hub.`,
      );
    }
  }

  return [...new Set(hubIds
    .map((hubId) => hubById.get(hubId)?.leagueId as string | undefined)
    .filter((leagueId): leagueId is string => Boolean(leagueId)))];
}

async function ensureLeagueRoom(orgId: string, leagueId: string, league: RequestRecord): Promise<void> {
  const rooms = orgRef(orgId).collection("chatRooms");
  const existing = await rooms
    .where("type", "==", "league")
    .where("leagueId", "==", leagueId)
    .where("hubId", "==", null)
    .limit(1)
    .get();
  if (!existing.empty) return;

  await rooms.add({
    orgId,
    name: `${requiredString(league.name, "league.name")} - General`,
    type: "league",
    leagueId,
    hubId: null,
    teamId: null,
    participants: [],
    isArchived: false,
    createdAt: now(),
    lastMessage: null,
    lastMessageAt: now(),
    lastMessageBy: null,
    roomIconName: optionalString(league.iconName) ?? null,
    roomImageUrl: optionalString(league.logoUrl) ?? null,
  });
}

async function ensureHubRoom(
  orgId: string,
  leagueId: string,
  hubId: string,
  hub: RequestRecord,
): Promise<void> {
  const rooms = orgRef(orgId).collection("chatRooms");
  const existing = await rooms
    .where("type", "==", "league")
    .where("leagueId", "==", leagueId)
    .where("hubId", "==", hubId)
    .limit(1)
    .get();
  if (!existing.empty) return;

  await rooms.add({
    orgId,
    name: `${requiredString(hub.name, "hub.name")} - General`,
    type: "league",
    leagueId,
    hubId,
    teamId: null,
    participants: [],
    isArchived: false,
    createdAt: now(),
    lastMessage: null,
    lastMessageAt: now(),
    lastMessageBy: null,
    roomIconName: optionalString(hub.iconName) ?? null,
    roomImageUrl: optionalString(hub.logoUrl) ?? null,
  });
}

async function deleteCollection(query: FirebaseFirestore.Query): Promise<number> {
  const snap = await query.get();
  let deleted = 0;
  let batch = db.batch();
  let pending = 0;
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    pending++;
    deleted++;
    if (pending >= 450) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return deleted;
}

async function addTeamMembershipMutations(
  batch: FirebaseFirestore.WriteBatch,
  orgId: string,
  teamId: string,
  beforeIds: string[],
  afterIds: string[],
): Promise<void> {
  const before = new Set(beforeIds);
  const after = new Set(afterIds);
  const added = [...after].filter((id) => !before.has(id));
  const removed = [...before].filter((id) => !after.has(id));

  for (const userId of added) {
    batch.update(usersRef().doc(userId), { teamIds: arrayUnion(teamId) });
  }
  if (removed.length > 0) {
    const removedSnaps = await db.getAll(...removed.map((userId) => usersRef().doc(userId)));
    for (const snap of removedSnaps) {
      if (snap.exists && snap.data()?.orgId === orgId) {
        batch.update(snap.ref, { teamIds: arrayRemove(teamId) });
      }
    }
  }
}

async function assertTeamMembersBelongToOrg(
  orgId: string,
  memberIds: string[],
): Promise<void> {
  if (memberIds.length === 0) return;
  const snaps = await db.getAll(...memberIds.map((userId) => usersRef().doc(userId)));
  const records = snaps
    .filter((snap) => snap.exists)
    .map((snap) => ({ id: snap.id, orgId: snap.data()?.orgId }));
  if (!teamMemberRecordsMatchOrg(memberIds, orgId, records)) {
    throw new HttpsError(
      "invalid-argument",
      "Every team member must be an existing user in this organization.",
    );
  }
}

async function syncUserTeamAssignments(
  orgId: string,
  userId: string,
  beforeTeamIds: string[],
  afterTeamIds: string[],
): Promise<void> {
  const before = new Set(beforeTeamIds);
  const after = new Set(afterTeamIds);
  const touchedTeamIds = new Set([
    ...beforeTeamIds.filter((teamId) => !after.has(teamId)),
    ...afterTeamIds.filter((teamId) => !before.has(teamId)),
  ]);
  if (touchedTeamIds.size === 0) return;

  const leaguesSnap = await orgRef(orgId).collection("leagues").get();
  let batch = db.batch();
  let pending = 0;

  for (const leagueDoc of leaguesSnap.docs) {
    const hubsSnap = await leagueDoc.ref.collection("hubs").get();
    for (const hubDoc of hubsSnap.docs) {
      const teamsSnap = await hubDoc.ref.collection("teams").get();
      for (const teamDoc of teamsSnap.docs) {
        if (!touchedTeamIds.has(teamDoc.id)) continue;
        batch.update(teamDoc.ref, {
          memberIds: after.has(teamDoc.id) ? arrayUnion(userId) : arrayRemove(userId),
        });
        pending++;
        if (pending >= 450) {
          await batch.commit();
          batch = db.batch();
          pending = 0;
        }
      }
    }
  }

  if (pending > 0) {
    await batch.commit();
  }
}

export const adminGetOverview = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminGetOverview", async (_actor, _data, orgId) => {
    const [
      orgSnap,
      usersSnap,
      invitationsSnap,
      policiesSnap,
      announcementsSnap,
      chatRoomsSnap,
      auditSnap,
      notificationSnap,
    ] = await Promise.all([
      orgRef(orgId).get(),
      usersRef().where("orgId", "==", orgId).get(),
      orgRef(orgId).collection("invitations").orderBy("createdAt", "desc").limit(50).get(),
      orgRef(orgId).collection("policies").orderBy("updatedAt", "desc").limit(20).get(),
      orgRef(orgId).collection("announcements").orderBy("createdAt", "desc").limit(20).get(),
      orgRef(orgId).collection("chatRooms").where("isArchived", "==", false).get(),
      orgRef(orgId).collection("auditLogs").orderBy("createdAt", "desc").limit(20).get(),
      orgRef(orgId).collection("notificationEvents").orderBy("createdAt", "desc").limit(20).get(),
    ]);
    if (!orgSnap.exists) {
      throw new HttpsError("not-found", "Organization was not found.");
    }

    const structure = await getStructure(orgId);
    const users: DocumentData[] = usersSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    const activeUsers = users.filter((user) => user.isActive === true);
    const activeUserEmails = new Set(activeUsers
      .map((user) => typeof user.email === "string" ? user.email.trim().toLowerCase() : "")
      .filter(Boolean));
    const pendingInvites = invitationsSnap.docs.filter((doc) => {
      const invite = doc.data();
      if (invite.status !== "pending") return false;
      const inviteEmail = typeof invite.email === "string" ? invite.email.trim().toLowerCase() : "";
      return inviteEmail.length === 0 || !activeUserEmails.has(inviteEmail);
    });
    const orphanedTeamAssignments = users.reduce((count, user) => {
      const teamIds = normalizeStringArray(user.teamIds);
      return count + teamIds.filter((teamId) => !structure.teams.some((team) => team.id === teamId)).length;
    }, 0);

    return {
      org: { id: orgSnap.id, ...orgSnap.data() },
      metrics: {
        users: users.length,
        activeUsers: activeUsers.length,
        pendingInvites: pendingInvites.length,
        leagues: structure.leagues.length,
        hubs: structure.hubs.length,
        teams: structure.teams.length,
        policies: policiesSnap.size,
        announcements: announcementsSnap.size,
        chatRooms: chatRoomsSnap.size,
        orphanedTeamAssignments,
      },
      recent: {
        invitations: invitationsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
        policies: policiesSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
        announcements: announcementsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
        auditLogs: auditSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
        notificationEvents: notificationSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
      },
      structure,
    };
  });
});

export const adminUpdateScheduleIntegration = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminUpdateScheduleIntegration", async (actor, data, orgId) => {
    assertScheduleAdmin(actor);
    const integration = objectValue(data.integration, "integration");
    const baseUrl = optionalString(integration.baseUrl) ??
      "https://juniorprospectshockeyleague.com";
    let parsedBaseUrl: URL;
    try {
      parsedBaseUrl = new URL(baseUrl);
    } catch {
      throw new HttpsError("invalid-argument", "integration.baseUrl must be a valid URL.");
    }
    if (parsedBaseUrl.protocol !== "https:" ||
        parsedBaseUrl.hostname !== "juniorprospectshockeyleague.com") {
      throw new HttpsError(
        "invalid-argument",
        "The schedule source must use the official JPHL HTTPS website.",
      );
    }
    const timezone = requiredString(integration.timezone, "integration.timezone");
    try {
      new Intl.DateTimeFormat("en-CA", { timeZone: timezone }).format();
    } catch {
      throw new HttpsError("invalid-argument", "integration.timezone is not valid.");
    }
    const rawDivisionIds = objectValue(integration.divisionIds, "integration.divisionIds");
    const divisionIds: Record<string, string> = {};
    for (const [ageGroup, value] of Object.entries(rawDivisionIds)) {
      divisionIds[ageGroup.trim()] = requiredString(value, `integration.divisionIds.${ageGroup}`);
    }
    if (Object.keys(divisionIds).length === 0) {
      throw new HttpsError("invalid-argument", "At least one RAMP division ID is required.");
    }

    const existingOrganization = await orgRef(orgId).get();
    const existingIntegration = existingOrganization.data()?.scheduleIntegration;
    const requestedSeasonId = requiredString(integration.seasonId, "integration.seasonId");
    const legacySourceSeasonId = optionalString(existingIntegration?.legacySourceSeasonId) ??
      optionalString(existingIntegration?.seasonId) ?? requestedSeasonId;
    const scheduleIntegration = {
      provider: "ramp",
      enabled: optionalBoolean(integration.enabled) ?? true,
      autoDiscoverSeason: optionalBoolean(integration.autoDiscoverSeason) ?? true,
      baseUrl: parsedBaseUrl.origin,
      associationId: requiredString(integration.associationId, "integration.associationId"),
      seasonId: requestedSeasonId,
      legacySourceSeasonId,
      timezone,
      divisionIds,
    };
    await orgRef(orgId).set({
      scheduleIntegration: {
        ...scheduleIntegration,
        updatedAt: now(),
        updatedBy: actor.id,
      },
    }, { merge: true });
    return { scheduleIntegration };
  });
});

export const adminSyncSchedule = onCall({
  timeoutSeconds: 540,
  memory: "512MiB",
}, async (request) => {
  return withAdmin(request, "adminSyncSchedule", async (actor, _data, orgId) => {
    assertScheduleAdmin(actor);
    return synchronizeOrganizationSchedule(orgId);
  });
});

export const adminCreateInvitation = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminCreateInvitation", async (actor, data, orgId) => {
    const email = requiredString(data.email, "email").toLowerCase();
    const role = requiredString(data.role, "role") as UserRole;
    if (!assignableRoles(actor.role).includes(role)) {
      throw new HttpsError("permission-denied", "You cannot invite users with that role.");
    }

    const invitationRef = orgRef(orgId).collection("invitations").doc();
    const token = randomBytes(16).toString("hex");
    const hubIds = normalizeStringArray(data.hubIds);
    const teamIds = normalizeStringArray(data.teamIds);
    const leagueIds = await validateAssignments(orgId, hubIds, teamIds);
    const invitationData = {
      orgId,
      email,
      displayName: optionalString(data.displayName) ?? null,
      role,
      leagueIds,
      hubIds,
      teamIds,
      invitedBy: actor.id,
      invitedByName: actor.displayName ?? actor.email ?? "Admin",
      createdAt: now(),
      status: "pending",
      token,
    };
    await db.batch()
      .set(invitationRef, invitationData)
      .set(db.collection("invitationLookups").doc(token), {
        token,
        orgId,
        invitationId: invitationRef.id,
        email,
        status: "pending",
        createdAt: new Date().toISOString(),
      })
      .commit();
    return { invitationId: invitationRef.id, token };
  });
});

export const adminExpireInvitation = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminExpireInvitation", async (actor, data, orgId) => {
    const invitationId = requiredString(data.invitationId, "invitationId");
    const invitationRef = orgRef(orgId).collection("invitations").doc(invitationId);
    const snap = await invitationRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Invitation was not found.");
    if (!canManageInvitationRole(actor.role, snap.data()?.role)) {
      throw new HttpsError("permission-denied", "You cannot manage an invitation for this role.");
    }
    const token = optionalString(snap.data()?.token);
    const batch = db.batch();
    batch.update(invitationRef, { status: "expired" });
    if (token) {
      batch.set(db.collection("invitationLookups").doc(token), { status: "expired" }, { merge: true });
    }
    await batch.commit();
    return { invitationId, status: "expired" };
  });
});

export const adminUpdateUserAccess = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminUpdateUserAccess", async (actor, data, orgId) => {
    const targetUserId = requiredString(data.targetUserId, "targetUserId");
    const targetRef = usersRef().doc(targetUserId);
    const targetSnap = await targetRef.get();
    if (!targetSnap.exists) throw new HttpsError("not-found", "User was not found.");
    const targetData = docData(targetSnap);
    if (!canManageTarget(actor, { id: targetSnap.id, orgId: targetData.orgId, role: targetData.role })) {
      throw new HttpsError("permission-denied", "You cannot manage this user.");
    }

    const updates: DocumentData = {};
    const nextRole = optionalString(data.role);
    if (nextRole) {
      if (!isUserRole(nextRole) || !assignableRoles(actor.role).includes(nextRole)) {
        throw new HttpsError("permission-denied", "You cannot assign that role.");
      }
      updates.role = nextRole;
    }
    const hubIds = data.hubIds === undefined ? undefined : normalizeStringArray(data.hubIds);
    const teamIds = data.teamIds === undefined ? undefined : normalizeStringArray(data.teamIds);
    const nextHubIds = hubIds ?? normalizeStringArray(targetData.hubIds);
    const nextTeamIds = teamIds ?? normalizeStringArray(targetData.teamIds);
    const leagueIds = await validateAssignments(orgId, nextHubIds, nextTeamIds);
    if (hubIds) updates.hubIds = hubIds;
    if (teamIds) updates.teamIds = teamIds;
    const isActive = optionalBoolean(data.isActive);
    if (isActive !== undefined) updates.isActive = isActive;

    const profilePatch = data.profilePatch === undefined ? undefined : objectValue(data.profilePatch, "profilePatch");
    if (profilePatch) {
      for (const field of ["title", "phone", "address"] as const) {
        if (field in profilePatch) {
          updates[field] = optionalString(profilePatch[field]) ?? admin.firestore.FieldValue.delete();
        }
      }
    }

    if (hubIds || teamIds) updates.leagueIds = leagueIds;

    if (teamIds) {
      const beforeTeamIds = normalizeStringArray(targetData.teamIds);
      await syncUserTeamAssignments(orgId, targetUserId, beforeTeamIds, teamIds);
    }

    await targetRef.update(updates);
    return { targetUserId, updatedFields: Object.keys(updates) };
  });
});

export const adminUpsertLeague = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminUpsertLeague", async (actor, data, orgId) => {
    const league = objectValue(data.league, "league");
    const leagueId = optionalString(league.id) ?? orgRef(orgId).collection("leagues").doc().id;
    const leagueRef = orgRef(orgId).collection("leagues").doc(leagueId);
    const exists = (await leagueRef.get()).exists;
    if (!exists && !canCreateLeague(actor)) {
      throw new HttpsError("permission-denied", "Only platform owners can create leagues.");
    }
    const payload = {
      orgId,
      name: requiredString(league.name, "league.name"),
      abbreviation: requiredString(league.abbreviation, "league.abbreviation"),
      description: optionalString(league.description) ?? null,
      logoUrl: optionalString(league.logoUrl) ?? null,
      iconName: optionalString(league.iconName) ?? null,
      websiteUrl: optionalString(league.websiteUrl) ?? null,
      instagramUrl: optionalString(league.instagramUrl) ?? null,
      xUrl: optionalString(league.xUrl) ?? null,
      ...(exists ? {} : { createdAt: now() }),
    };
    await leagueRef.set(payload, { merge: true });
    if (!exists) await ensureLeagueRoom(orgId, leagueId, payload);
    return { leagueId, created: !exists };
  });
});

export const adminDeleteLeague = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminDeleteLeague", async (_actor, data, orgId) => {
    const leagueId = requiredString(data.leagueId, "leagueId");
    const leagueRef = orgRef(orgId).collection("leagues").doc(leagueId);
    const hubsSnap = await leagueRef.collection("hubs").get();
    let deletedTeams = 0;
    for (const hub of hubsSnap.docs) {
      deletedTeams += await deleteCollection(hub.ref.collection("teams"));
    }
    const deletedHubs = await deleteCollection(leagueRef.collection("hubs"));
    await leagueRef.delete();
    return { leagueId, deletedHubs, deletedTeams };
  });
});

export const adminUpsertHub = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminUpsertHub", async (_actor, data, orgId) => {
    const leagueId = requiredString(data.leagueId, "leagueId");
    const hub = objectValue(data.hub, "hub");
    const hubId = optionalString(hub.id) ?? orgRef(orgId).collection("leagues").doc(leagueId).collection("hubs").doc().id;
    const hubRef = orgRef(orgId).collection("leagues").doc(leagueId).collection("hubs").doc(hubId);
    const exists = (await hubRef.get()).exists;
    const payload = {
      orgId,
      leagueId,
      name: requiredString(hub.name, "hub.name"),
      location: optionalString(hub.location) ?? null,
      logoUrl: optionalString(hub.logoUrl) ?? null,
      iconName: optionalString(hub.iconName) ?? null,
      ...(exists ? {} : { createdAt: now() }),
    };
    await hubRef.set(payload, { merge: true });
    if (!exists) await ensureHubRoom(orgId, leagueId, hubId, payload);
    return { hubId, created: !exists };
  });
});

export const adminDeleteHub = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminDeleteHub", async (_actor, data, orgId) => {
    const leagueId = requiredString(data.leagueId, "leagueId");
    const hubId = requiredString(data.hubId, "hubId");
    const hubRef = orgRef(orgId).collection("leagues").doc(leagueId).collection("hubs").doc(hubId);
    const deletedTeams = await deleteCollection(hubRef.collection("teams"));
    await hubRef.delete();
    return { hubId, deletedTeams };
  });
});

export const adminUpsertTeam = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminUpsertTeam", async (_actor, data, orgId) => {
    const leagueId = requiredString(data.leagueId, "leagueId");
    const hubId = requiredString(data.hubId, "hubId");
    const team = objectValue(data.team, "team");
    const teamId = optionalString(team.id) ??
      orgRef(orgId).collection("leagues").doc(leagueId).collection("hubs").doc(hubId).collection("teams").doc().id;
    const teamRef = orgRef(orgId).collection("leagues").doc(leagueId).collection("hubs").doc(hubId).collection("teams").doc(teamId);
    const before = await teamRef.get();
    const memberIds = team.memberIds === undefined ?
      normalizeStringArray(before.data()?.memberIds) :
      normalizeStringArray(team.memberIds);
    await assertTeamMembersBelongToOrg(orgId, memberIds);
    const payload = {
      orgId,
      leagueId,
      hubId,
      name: requiredString(team.name, "team.name"),
      ageGroup: optionalString(team.ageGroup) ?? null,
      division: optionalString(team.division) ?? null,
      logoUrl: optionalString(team.logoUrl) ?? null,
      iconName: optionalString(team.iconName) ?? null,
      memberIds,
      ...(before.exists ? {} : { createdAt: now() }),
    };
    const batch = db.batch();
    batch.set(teamRef, payload, { merge: true });
    await addTeamMembershipMutations(
      batch,
      orgId,
      teamId,
      normalizeStringArray(before.data()?.memberIds),
      memberIds,
    );
    await batch.commit();
    return { teamId, created: !before.exists };
  });
});

export const adminDeleteTeam = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminDeleteTeam", async (_actor, data, orgId) => {
    const leagueId = requiredString(data.leagueId, "leagueId");
    const hubId = requiredString(data.hubId, "hubId");
    const teamId = requiredString(data.teamId, "teamId");
    const teamRef = orgRef(orgId).collection("leagues").doc(leagueId).collection("hubs").doc(hubId).collection("teams").doc(teamId);
    const before = await teamRef.get();
    const batch = db.batch();
    batch.delete(teamRef);
    await addTeamMembershipMutations(
      batch,
      orgId,
      teamId,
      normalizeStringArray(before.data()?.memberIds),
      [],
    );
    await batch.commit();
    return { teamId };
  });
});

export const adminCreateAnnouncement = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminCreateAnnouncement", async (actor, data, orgId) => {
    const ref = orgRef(orgId).collection("announcements").doc();
    const target = await validatedAnnouncementTarget(orgId, data);
    await ref.set({
      orgId,
      ...target,
      title: requiredString(data.title, "title"),
      body: requiredString(data.body, "body"),
      authorId: actor.id,
      authorName: actor.displayName ?? actor.email ?? "Admin",
      authorRole: actor.role,
      attachments: Array.isArray(data.attachments) ? data.attachments : [],
      isPinned: optionalBoolean(data.isPinned) ?? false,
      createdAt: now(),
    });
    return { announcementId: ref.id };
  });
});

export const adminUpdateAnnouncement = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminUpdateAnnouncement", async (_actor, data, orgId) => {
    const announcementId = requiredString(data.announcementId, "announcementId");
    const ref = orgRef(orgId).collection("announcements").doc(announcementId);
    const before = await ref.get();
    if (!before.exists) throw new HttpsError("not-found", "Announcement was not found.");
    const patch = allowedPatch(data.patch, "patch", [
      "scope",
      "leagueId",
      "hubId",
      "teamId",
      "title",
      "body",
      "attachments",
      "isPinned",
    ]);
    const target = await validatedAnnouncementTarget(orgId, { ...(before.data() ?? {}), ...patch });
    await ref.update({
      ...patch,
      ...target,
      updatedAt: now(),
    });
    return { announcementId, updatedFields: Object.keys(patch) };
  });
});

export const adminDeleteAnnouncement = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminDeleteAnnouncement", async (_actor, data, orgId) => {
    const announcementId = requiredString(data.announcementId, "announcementId");
    await orgRef(orgId).collection("announcements").doc(announcementId).delete();
    return { announcementId };
  });
});

export const adminCreatePolicy = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminCreatePolicy", async (actor, data, orgId) => {
    const requestedPolicyId = optionalString(data.policyId);
    const ref = requestedPolicyId ?
      orgRef(orgId).collection("policies").doc(requestedPolicyId) :
      orgRef(orgId).collection("policies").doc();
    const category = requiredString(data.category, "category");
    if (!isValidPolicyCategory(category)) {
      throw new HttpsError("invalid-argument", "Select a supported policy category.");
    }
    await ref.set({
      orgId,
      leagueId: optionalString(data.leagueId) ?? null,
      hubId: optionalString(data.hubId) ?? null,
      teamId: optionalString(data.teamId) ?? null,
      name: requiredString(data.name, "name"),
      fileUrl: requiredString(data.fileUrl, "fileUrl"),
      fileType: requiredString(data.fileType, "fileType"),
      fileSize: typeof data.fileSize === "number" ? data.fileSize : 0,
      category,
      uploadedBy: actor.id,
      uploadedByName: actor.displayName ?? actor.email ?? "Admin",
      versions: [],
      createdAt: now(),
      updatedAt: now(),
    });
    return { policyId: ref.id };
  });
});

export const adminAddPolicyVersion = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminAddPolicyVersion", async (actor, data, orgId) => {
    const policyId = requiredString(data.policyId, "policyId");
    const policyRef = orgRef(orgId).collection("policies").doc(policyId);
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(policyRef);
      if (!snap.exists) throw new HttpsError("not-found", "Policy was not found.");
      const versions = Array.isArray(snap.data()?.versions) ? snap.data()?.versions as DocumentData[] : [];
      const nextVersion = {
        url: requiredString(data.fileUrl, "fileUrl"),
        fileUrl: requiredString(data.fileUrl, "fileUrl"),
        version: versions.length + 1,
        uploadedAt: new Date().toISOString(),
        uploadedBy: actor.id,
        uploadedByName: actor.displayName ?? actor.email ?? "Admin",
        fileSize: typeof data.fileSize === "number" ? data.fileSize : 0,
      };
      transaction.update(policyRef, {
        versions: [...versions, nextVersion],
        fileUrl: nextVersion.fileUrl,
        fileSize: nextVersion.fileSize,
        updatedAt: now(),
      });
    });
    return { policyId };
  });
});

export const adminDeletePolicy = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminDeletePolicy", async (_actor, data, orgId) => {
    const policyId = requiredString(data.policyId, "policyId");
    await orgRef(orgId).collection("policies").doc(policyId).delete();
    return { policyId };
  });
});

export const adminUpdateChatRoom = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminUpdateChatRoom", async (_actor, data, orgId) => {
    const roomId = requiredString(data.roomId, "roomId");
    const roomRef = orgRef(orgId).collection("chatRooms").doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) throw new HttpsError("not-found", "Chat room was not found.");
    if (!isManagedChatRoomType(roomSnap.data()?.type)) {
      throw new HttpsError("permission-denied", "Direct-message rooms cannot be managed by administrators.");
    }
    const patch = allowedPatch(data.patch, "patch", [
      "name",
      "leagueId",
      "hubId",
      "teamId",
      "participants",
      "roomIconName",
      "roomImageUrl",
    ]);
    await roomRef.update(patch);
    return { roomId, updatedFields: Object.keys(patch) };
  });
});

export const adminArchiveChatRoom = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminArchiveChatRoom", async (_actor, data, orgId) => {
    const roomId = requiredString(data.roomId, "roomId");
    const roomRef = orgRef(orgId).collection("chatRooms").doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) throw new HttpsError("not-found", "Chat room was not found.");
    if (!isManagedChatRoomType(roomSnap.data()?.type)) {
      throw new HttpsError("permission-denied", "Direct-message rooms cannot be managed by administrators.");
    }
    await roomRef.update({ isArchived: true });
    return { roomId, isArchived: true };
  });
});

export const adminDeleteMessage = onCall(adminRuntime, async (request) => {
  return withAdmin(request, "adminDeleteMessage", async (_actor, data, orgId) => {
    const roomId = requiredString(data.roomId, "roomId");
    const messageId = requiredString(data.messageId, "messageId");
    await orgRef(orgId)
      .collection("chatRooms")
      .doc(roomId)
      .collection("messages")
      .doc(messageId)
      .update({
        text: null,
        mediaUrl: null,
        deleted: true,
        deletedAt: now(),
      });
    return { roomId, messageId };
  });
});

logger.info("League Hub admin callable functions loaded");
