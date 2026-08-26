import * as admin from "firebase-admin";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {db} from "./helpers";
import {
  MultiTeamTarget,
  belongsToMultiTeamEventRoomAudience,
  canCreateMultiTeamEventRoom,
  maximumMultiTeamEventRoomTeams,
} from "./multiTeamEventRoomLogic";

type RequestRecord = Record<string, unknown>;

const runtime = {
  timeoutSeconds: 60,
  memory: "256MiB" as const,
};

function requiredString(value: unknown, field: string, maximumLength = 200): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maximumLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be between 1 and ${maximumLength} characters.`,
    );
  }
  return trimmed;
}

function parseTargets(value: unknown): MultiTeamTarget[] {
  if (!Array.isArray(value) || value.length === 0 ||
      value.length > maximumMultiTeamEventRoomTeams) {
    throw new HttpsError(
      "invalid-argument",
      `Select between 1 and ${maximumMultiTeamEventRoomTeams} teams.`,
    );
  }
  const targets = value.map((item, index) => {
    if (item == null || typeof item !== "object" || Array.isArray(item)) {
      throw new HttpsError("invalid-argument", `teams[${index}] is invalid.`);
    }
    const record = item as RequestRecord;
    const keys = Object.keys(record).sort();
    if (keys.length !== 2 || keys[0] !== "hubId" || keys[1] !== "teamId") {
      throw new HttpsError(
        "invalid-argument",
        `teams[${index}] must contain only hubId and teamId.`,
      );
    }
    return {
      hubId: requiredString(record.hubId, `teams[${index}].hubId`),
      teamId: requiredString(record.teamId, `teams[${index}].teamId`),
    };
  });
  if (new Set(targets.map((target) => target.teamId)).size !== targets.length) {
    throw new HttpsError("invalid-argument", "Each selected team must be unique.");
  }
  return targets;
}

export const createMultiTeamEventRoom = onCall(runtime, async (request: CallableRequest) => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
  if (request.data == null || typeof request.data !== "object" || Array.isArray(request.data)) {
    throw new HttpsError("invalid-argument", "Room details are required.");
  }

  const data = request.data as RequestRecord;
  const supportedFields = new Set([
    "orgId", "name", "leagueId", "teams", "roomIconName",
  ]);
  if (Object.keys(data).some((field) => !supportedFields.has(field))) {
    throw new HttpsError("invalid-argument", "Room details include unsupported fields.");
  }
  const orgId = requiredString(data.orgId, "orgId");
  const leagueId = requiredString(data.leagueId, "leagueId");
  const name = requiredString(data.name, "name", 120);
  const roomIconName = requiredString(data.roomIconName, "roomIconName", 40);
  const targets = parseTargets(data.teams);

  const actorSnapshot = await db.collection("users").doc(userId).get();
  const actor = actorSnapshot.data();
  if (!actorSnapshot.exists || actor?.isActive !== true ||
      (actor.role !== "platformOwner" && actor.orgId !== orgId)) {
    throw new HttpsError("permission-denied", "You cannot create a room for this organization.");
  }

  const teamRefs = targets.map((target) => db
    .collection("organizations").doc(orgId)
    .collection("leagues").doc(leagueId)
    .collection("hubs").doc(target.hubId)
    .collection("teams").doc(target.teamId));
  const teamSnapshots = await db.getAll(...teamRefs);
  for (let index = 0; index < teamSnapshots.length; index += 1) {
    const team = teamSnapshots[index].data();
    const target = targets[index];
    if (!teamSnapshots[index].exists || team?.orgId !== orgId ||
        team?.leagueId !== leagueId || team?.hubId !== target.hubId) {
      throw new HttpsError(
        "invalid-argument",
        `Team ${target.teamId} is not in the selected Hub and league.`,
      );
    }
  }
  if (!canCreateMultiTeamEventRoom(actor ?? {}, targets)) {
    throw new HttpsError(
      "permission-denied",
      "Every selected team must be within your assigned Team or Hub scope.",
    );
  }

  const usersSnapshot = await db.collection("users")
    .where("orgId", "==", orgId)
    .where("isActive", "==", true)
    .get();
  const participantIds = usersSnapshot.docs
    .filter((snapshot) => belongsToMultiTeamEventRoomAudience(
      {...snapshot.data(), id: snapshot.id},
      orgId,
      targets,
    ))
    .map((snapshot) => snapshot.id);
  if (!participantIds.includes(userId)) participantIds.push(userId);

  const hubIds = [...new Set(targets.map((target) => target.hubId))];
  const teamIds = targets.map((target) => target.teamId);
  const roomRef = db.collection("organizations").doc(orgId)
    .collection("chatRooms").doc();
  await roomRef.set({
    orgId,
    name,
    type: "event",
    roomPurpose: "event",
    leagueId,
    hubId: targets[0].hubId,
    teamId: targets[0].teamId,
    hubIds,
    teamIds,
    participants: participantIds,
    isArchived: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: userId,
    lastMessage: null,
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageBy: null,
    roomIconName,
    roomImageUrl: null,
  });

  return {roomId: roomRef.id};
});
