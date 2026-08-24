import { createHash } from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { structureRoomTeamLinkId } from "./adminLogic";
import { db } from "./helpers";

type StructureRoomScope = "hub" | "team";
type StructureData = Record<string, unknown>;

type StructureRoomInput = {
  orgId: string;
  leagueId: string;
  hubId: string;
  teamId?: string | null;
  scope: StructureRoomScope;
  structureRef: FirebaseFirestore.DocumentReference;
  restoreArchived?: boolean;
};

const now = () => admin.firestore.FieldValue.serverTimestamp();

function optionalString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

export function managedStructureRoomDocumentId(
  scope: StructureRoomScope,
  leagueId: string,
  hubId: string,
  teamId?: string | null,
): string {
  const key = `${scope}:${leagueId}:${hubId}:${teamId ?? ""}`;
  const digest = createHash("sha256").update(key).digest("hex").slice(0, 24);
  return `managed_${scope}_${digest}`;
}

function managedRoomQuery({
  orgId,
  leagueId,
  hubId,
  teamId,
}: Pick<StructureRoomInput, "orgId" | "leagueId" | "hubId" | "teamId">) {
  return db.collection("organizations")
    .doc(orgId)
    .collection("chatRooms")
    .where("type", "==", "league")
    .where("leagueId", "==", leagueId)
    .where("hubId", "==", hubId)
    .where("teamId", "==", teamId ?? null);
}

function expectedRoomFields(input: StructureRoomInput, data: StructureData) {
  const name = optionalString(data.name);
  if (!name) throw new Error(`${input.scope} ${input.structureRef.path} has no valid name`);
  return {
    orgId: input.orgId,
    name: `${name} - General`,
    type: "league",
    leagueId: input.leagueId,
    hubId: input.hubId,
    teamId: input.teamId ?? null,
    roomIconName: optionalString(data.iconName) ?? input.scope,
    roomImageUrl: optionalString(data.logoUrl),
    managedScope: input.scope,
  };
}

function roomNeedsSync(
  room: FirebaseFirestore.DocumentData,
  expected: ReturnType<typeof expectedRoomFields>,
  restoreArchived: boolean,
): boolean {
  return room.orgId !== expected.orgId ||
    room.name !== expected.name ||
    room.type !== expected.type ||
    room.leagueId !== expected.leagueId ||
    room.hubId !== expected.hubId ||
    (room.teamId ?? null) !== expected.teamId ||
    (room.roomIconName ?? null) !== expected.roomIconName ||
    (room.roomImageUrl ?? null) !== expected.roomImageUrl ||
    room.managedScope !== expected.managedScope ||
    (restoreArchived && room.isArchived === true);
}

export async function syncStructureChatRoom(input: StructureRoomInput): Promise<string | null> {
  return db.runTransaction(async (transaction) => {
    const structure = await transaction.get(input.structureRef);
    if (!structure.exists) return null;
    const expected = expectedRoomFields(input, structure.data() ?? {});

    const rooms = await transaction.get(managedRoomQuery(input));
    const sortedRooms = [...rooms.docs].sort((left, right) => left.id.localeCompare(right.id));
    const existing = sortedRooms.find((room) => room.data().isArchived !== true) ?? sortedRooms[0];
    const roomRef = existing?.ref ?? db.collection("organizations")
      .doc(input.orgId)
      .collection("chatRooms")
      .doc(managedStructureRoomDocumentId(
        input.scope,
        input.leagueId,
        input.hubId,
        input.teamId,
      ));

    if (!existing) {
      transaction.set(roomRef, {
        ...expected,
        participants: [],
        isArchived: false,
        createdAt: now(),
        lastMessage: null,
        lastMessageAt: now(),
        lastMessageBy: null,
      });
    } else if (roomNeedsSync(existing.data(), expected, input.restoreArchived === true)) {
      transaction.set(roomRef, {
        ...expected,
        ...(input.restoreArchived ? { isArchived: false } : {}),
      }, { merge: true });
    }

    if (input.scope === "team") {
      const teamLinkId = structureRoomTeamLinkId(
        roomRef.id,
        existing?.data().isArchived === true,
        input.restoreArchived === true,
      );
      if (structure.data()?.chatRoomId !== teamLinkId) {
        transaction.update(input.structureRef, { chatRoomId: teamLinkId });
      }
    }
    return roomRef.id;
  });
}

async function archiveStructureChatRooms(
  input: Pick<StructureRoomInput, "orgId" | "leagueId" | "hubId" | "teamId">,
): Promise<void> {
  const rooms = await managedRoomQuery(input).get();
  const activeRooms = rooms.docs.filter((room) => room.data().isArchived !== true);
  if (activeRooms.length === 0) return;
  const batch = db.batch();
  for (const room of activeRooms) batch.update(room.ref, { isArchived: true });
  await batch.commit();
}

export const onHubStructureWritten = onDocumentWritten(
  "organizations/{orgId}/leagues/{leagueId}/hubs/{hubId}",
  async (event) => {
    const input = {
      orgId: event.params.orgId,
      leagueId: event.params.leagueId,
      hubId: event.params.hubId,
      teamId: null,
    };
    const after = event.data?.after;
    if (!after?.exists) {
      await archiveStructureChatRooms(input);
      return;
    }
    await syncStructureChatRoom({
      ...input,
      scope: "hub",
      structureRef: after.ref,
      restoreArchived: event.data?.before.exists !== true,
    });
    logger.info("Synchronized hub General chat room", input);
  },
);

export const onTeamStructureWritten = onDocumentWritten(
  "organizations/{orgId}/leagues/{leagueId}/hubs/{hubId}/teams/{teamId}",
  async (event) => {
    const input = {
      orgId: event.params.orgId,
      leagueId: event.params.leagueId,
      hubId: event.params.hubId,
      teamId: event.params.teamId,
    };
    const after = event.data?.after;
    if (!after?.exists) {
      await archiveStructureChatRooms(input);
      return;
    }
    await syncStructureChatRoom({
      ...input,
      scope: "team",
      structureRef: after.ref,
      restoreArchived: event.data?.before.exists !== true,
    });
    logger.info("Synchronized team General chat room", input);
  },
);
