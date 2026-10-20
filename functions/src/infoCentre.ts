import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {db} from "./helpers";
import {
  InfoActor, InfoRecord, InfoScope, InfoStructure, canManageInfo, canReadInfo,
  canRevealInfo, containsScope, elevated, readableScope, sameOrganization, validateScope,
} from "./infoCentreLogic";

const runtime = {timeoutSeconds: 60, memory: "256MiB" as const};
const error = (message: string): never => { throw new HttpsError("invalid-argument", message); };
function text(value: unknown, field: string, maximum = 200, optional = false): string {
  if (optional && (value == null || value === "")) return "";
  if (typeof value !== "string" || !value.trim() || value.trim().length > maximum) return error(`Invalid ${field}.`);
  return value.trim();
}
function id(value: unknown, field: string): string {
  const result = text(value, field, 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(result)) return error(`Invalid ${field}.`);
  return result;
}
function input(request: CallableRequest): Record<string, unknown> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to use Info Centre.");
  if (!request.data || typeof request.data !== "object" || Array.isArray(request.data)) return error("Details are required.");
  return request.data;
}
async function actorFor(uid: string, orgId: string): Promise<InfoActor> {
  const snapshot = await db.collection("users").doc(uid).get();
  const user = {...snapshot.data(), id: uid} as InfoActor;
  if (!snapshot.exists || !sameOrganization(user, orgId)) throw new HttpsError("permission-denied", "Info Centre access is unavailable.");
  return user;
}
async function structureFor(orgId: string, transaction?: FirebaseFirestore.Transaction): Promise<InfoStructure> {
  const root = db.collection("organizations").doc(orgId);
  if (!(await (transaction ? transaction.get(root) : root.get())).exists) throw new HttpsError("not-found", "Organization not found.");
  const leagueQuery = root.collection("leagues").limit(101);
  const leagues = await (transaction ? transaction.get(leagueQuery) : leagueQuery.get());
  if (leagues.size > 100) throw new HttpsError("resource-exhausted", "Organization structure is too large.");
  const structure: InfoStructure = {leagues: [], hubs: [], teams: []};
  await Promise.all(leagues.docs.map(async (league) => {
    structure.leagues.push({id: league.id, name: league.data().name || league.id});
    const hubQuery = league.ref.collection("hubs").limit(201);
    const hubs = await (transaction ? transaction.get(hubQuery) : hubQuery.get());
    if (hubs.size > 200) throw new HttpsError("resource-exhausted", "League structure is too large.");
    await Promise.all(hubs.docs.map(async (hub) => {
      structure.hubs.push({id: hub.id, name: hub.data().name || hub.id, leagueId: league.id});
      const teamQuery = hub.ref.collection("teams").limit(201);
      const teams = await (transaction ? transaction.get(teamQuery) : teamQuery.get());
      if (teams.size > 200) throw new HttpsError("resource-exhausted", "Hub structure is too large.");
      teams.docs.forEach((team) => structure.teams.push({
        id: team.id, name: team.data().name || team.id, hubId: hub.id, leagueId: league.id,
      }));
    }));
  }));
  return structure;
}
function scopedStructure(user: InfoActor, structure: InfoStructure): InfoStructure {
  if (elevated(user)) return structure;
  const teams = structure.teams.filter((team) => user.teamIds?.includes(team.id) ||
    (user.role === "managerAdmin" && user.hubIds?.includes(team.hubId)));
  const hubIds = new Set([...(user.hubIds || []), ...teams.map((team) => team.hubId)]);
  const hubs = structure.hubs.filter((hub) => hubIds.has(hub.id));
  const leagueIds = new Set([...(user.leagueIds || []), ...hubs.map((hub) => hub.leagueId)]);
  return {teams, hubs, leagues: structure.leagues.filter((league) => leagueIds.has(league.id))};
}
const records = (orgId: string, type: "section" | "entry") => db.collection("organizations").doc(orgId)
  .collection(type === "section" ? "infoCentreSections" : "infoCentreEntries");

export const infoCentreList = onCall(runtime, async (request) => {
  const data = input(request);
  const orgId = id(data.orgId, "organization");
  const actor = await actorFor(request.auth!.uid, orgId);
  const structure = await structureFor(orgId);
  const snapshots = await Promise.all([records(orgId, "section").where("status", "in", ["draft", "published"]).limit(1001).get(), records(orgId, "entry").where("status", "in", ["draft", "published"]).limit(1001).get()]);
  if (snapshots.some((snapshot) => snapshot.size > 1000)) throw new HttpsError("resource-exhausted", "Archive old Info Centre resources before adding more.");
  const preview = data.preview === true;
  const convert = (snapshot: FirebaseFirestore.QuerySnapshot): InfoRecord[] => snapshot.docs
    .map((doc) => ({...doc.data(), id: doc.id}) as InfoRecord)
    .filter((item) => validateScope(item, structure) && canReadInfo(actor, item, structure, preview))
    .sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder) || a.title.localeCompare(b.title));
  const sections = convert(snapshots[0]);
  const policySnapshot = await db.collection('organizations').doc(orgId).collection('policies').limit(1001).get();
  const policies = policySnapshot.docs.filter((doc) => {
    const policy = doc.data();
    return elevated(actor) || (policy.teamId ? actor.teamIds?.includes(policy.teamId) || actor.hubIds?.includes(policy.hubId) :
      policy.hubId ? actor.hubIds?.includes(policy.hubId) : true);
  }).slice(0, 1000).map((doc) => ({id: doc.id, name: String(doc.data().name || 'Policy')}));
  const sectionIds = new Set(sections.map((section) => section.id));
  const entries = convert(snapshots[1]).filter((entry) => sectionIds.has(entry.sectionId!));
  // Only an explicit metadata whitelist crosses the callable boundary.
  const fields = ["id", "orgId", "leagueId", "hubId", "teamId", "sectionId", "title", "kind", "status", "audience", "passwordAudience", "hasPassword", "sortOrder", "notes", "url", "inviteCode", "policyId", "revision", "updatedAt"];
  const visible = (item: InfoRecord) => ({
    ...Object.fromEntries(fields.filter((field) => field in item).map((field) => [field, item[field]])),
    canManage: canManageInfo(actor, item),
    canReveal: canRevealInfo(actor, item, structure),
  });
  // Revalidate identity/assignments after asynchronous reads; never return a stale scope.
  const current = await actorFor(request.auth!.uid, orgId);
  if (JSON.stringify(current) !== JSON.stringify(actor)) throw new HttpsError("aborted", "Your access changed. Refresh Info Centre.");
  return {structure: scopedStructure(actor, structure), policies, policyOptionsLimited: policySnapshot.size > 1000, sections: sections.map(visible), entries: entries.map(visible)};
});

export const infoCentreUpsert = onCall(runtime, async (request) => {
  const data = input(request);
  const orgId = id(data.orgId, "organization");
  await actorFor(request.auth!.uid, orgId);
  const structure = await structureFor(orgId);
  const type = data.type === "section" ? "section" : data.type === "entry" ? "entry" : error("Invalid resource type.");
  const itemId = data.id ? id(data.id, "resource") : records(orgId, type).doc().id;
  const scope: InfoScope = {leagueId: id(data.leagueId, "league"),
    hubId: data.hubId ? id(data.hubId, "hub") : null, teamId: data.teamId ? id(data.teamId, "team") : null};
  if (!validateScope(scope, structure)) return error("The selected team, hub and league must belong together.");
  const status = text(data.status, "status");
  if (!["draft", "published", "archived"].includes(status)) return error("Invalid publication status.");
  const audience = data.audience === "management" ? "management" : data.audience === "members" ? "members" : error("Choose an audience.");
  const sortOrder = data.sortOrder ?? 0;
  if (!Number.isInteger(sortOrder) || Number(sortOrder) < 0 || Number(sortOrder) > 10000) return error("Order must be a number between 0 and 10000.");
  const item: Record<string, unknown> = {orgId, ...scope, title: text(data.title, "title"), status, audience, sortOrder};
  let sectionId: string | undefined;
  if (type === "entry") {
    sectionId = id(data.sectionId, "section");
    const kind = text(data.kind, "kind");
    if (!["registration", "link", "document", "note", "policy"].includes(kind)) return error("Choose a resource kind.");
    const url = text(data.url, "URL", 2000, true);
    if (url) {
      let parsed: URL;
      try { parsed = new URL(url); } catch { return error("Enter a valid website URL."); }
      if (!["https:", "http:"].includes(parsed.protocol) || !parsed.hostname || parsed.username || parsed.password) return error("Use an HTTP or HTTPS website URL without embedded credentials.");
    }
    if (["registration", "link", "document"].includes(kind) && !url) return error("A link is required.");
    const passwordAudience = data.passwordAudience === "members" ? "members" : "management";
    Object.assign(item, {sectionId, kind, url, notes: text(data.notes, "notes", 10000, true),
      inviteCode: text(data.inviteCode, "invite code", 200, true), passwordAudience,
      policyId: kind === "policy" ? id(data.policyId, "policy") : null});
    if (data.password !== undefined && data.password !== null &&
        (typeof data.password !== "string" || data.password.length > 500)) return error("Invalid password.");
  }
  const reference = records(orgId, type).doc(itemId);
  const secret = db.collection("organizations").doc(orgId).collection("infoCentreSecrets").doc(itemId);
  return db.runTransaction(async (transaction) => {
    const [userSnapshot, existing, section] = await Promise.all([
      transaction.get(db.collection("users").doc(request.auth!.uid)), transaction.get(reference),
      sectionId ? transaction.get(records(orgId, "section").doc(sectionId)) : Promise.resolve(null),
    ]);
    const actor = {...userSnapshot.data(), id: userSnapshot.id} as InfoActor;
    if (!sameOrganization(actor, orgId) || !canManageInfo(actor, scope) ||
        (existing.exists && !canManageInfo(actor, existing.data() as InfoRecord))) {
      throw new HttpsError("permission-denied", "You can only manage your assigned Info Centre scope.");
    }
    const currentStructure = await structureFor(orgId, transaction);
    if (!validateScope(scope, currentStructure)) return error("The selected scope no longer exists.");
    const wasActive = existing.exists && ["draft", "published"].includes(existing.data()!.status);
    if (status !== "archived" && !wasActive) {
      const active = await transaction.get(records(orgId, type).where("status", "in", ["draft", "published"]).limit(1000));
      if (active.size >= 1000) throw new HttpsError("resource-exhausted", "Archive an existing resource before adding or republishing another.");
    }
    const revision = existing.exists ? Number(existing.data()!.revision) : 0;
    if ((existing.exists && data.expectedRevision !== revision) || (!existing.exists && data.expectedRevision != null && data.expectedRevision !== 0)) {
      throw new HttpsError("aborted", "This resource changed. Refresh before saving again.");
    }
    if (sectionId && (!section?.exists || section.data()!.status === "archived" ||
        !containsScope(section.data() as InfoScope, scope) ||
        !readableScope(actor, section.data() as InfoScope, currentStructure))) return error("Choose an available section containing this resource's scope.");
    if (item.policyId && !(await transaction.get(db.collection("organizations").doc(orgId).collection("policies").doc(String(item.policyId)))).exists) return error("Policy not found in this organization.");
    // Lock referenced hierarchy and actor documents against concurrent reassignments.
    const league = db.collection("organizations").doc(orgId).collection("leagues").doc(scope.leagueId);
    const refs = [league];
    if (scope.hubId) refs.push(league.collection("hubs").doc(scope.hubId));
    if (scope.teamId) refs.push(league.collection("hubs").doc(scope.hubId!).collection("teams").doc(scope.teamId));
    for (const ref of refs) if (!(await transaction.get(ref)).exists) return error("The selected scope no longer exists.");
    const hasPassword = type === "entry" && (data.password === undefined ? existing.data()?.hasPassword === true : Boolean(data.password));
    const now = new Date().toISOString();
    transaction.set(reference, {...item, hasPassword, revision: revision + 1,
      createdAt: existing.data()?.createdAt ?? now, createdBy: existing.data()?.createdBy ?? actor.id,
      updatedAt: now, updatedBy: actor.id});
    if (type === "entry" && data.password !== undefined) {
      if (data.password) transaction.set(secret, {password: data.password});
      else transaction.delete(secret);
    }
    return {id: itemId, revision: revision + 1};
  });
});

export const infoCentreReveal = onCall(runtime, async (request) => {
  const data = input(request);
  const orgId = id(data.orgId, "organization");
  const itemId = id(data.id, "resource");
  await actorFor(request.auth!.uid, orgId);
  return db.runTransaction(async (transaction) => {
    const [userSnapshot, entrySnapshot, secret] = await Promise.all([
      transaction.get(db.collection("users").doc(request.auth!.uid)),
      transaction.get(records(orgId, "entry").doc(itemId)),
      transaction.get(db.collection("organizations").doc(orgId).collection("infoCentreSecrets").doc(itemId)),
    ]);
    const structure = await structureFor(orgId, transaction);
    const actor = {...userSnapshot.data(), id: userSnapshot.id} as InfoActor;
    const entry = entrySnapshot.data() as InfoRecord | undefined;
    if (!entry || !validateScope(entry, structure) || !canRevealInfo(actor, entry, structure)) throw new HttpsError("permission-denied", "This password is restricted.");
    const section = await transaction.get(records(orgId, "section").doc(entry.sectionId!));
    if (!section.exists || !validateScope(section.data() as InfoScope, structure) ||
        !containsScope(section.data() as InfoScope, entry) ||
        !canReadInfo(actor, section.data() as InfoRecord, structure)) throw new HttpsError("permission-denied", "This resource is unavailable.");
    if (!secret.exists) throw new HttpsError("not-found", "No password is available.");
    return {password: secret.data()!.password};
  });
});
