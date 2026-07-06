import { httpsCallable } from "firebase/functions";
import { functions } from "./firebase";

export type CallableName =
  | "adminGetOverview"
  | "adminCreateInvitation"
  | "adminExpireInvitation"
  | "adminUpdateUserAccess"
  | "adminUpsertLeague"
  | "adminDeleteLeague"
  | "adminUpsertHub"
  | "adminDeleteHub"
  | "adminUpsertTeam"
  | "adminDeleteTeam"
  | "adminCreateAnnouncement"
  | "adminUpdateAnnouncement"
  | "adminDeleteAnnouncement"
  | "adminCreatePolicy"
  | "adminAddPolicyVersion"
  | "adminDeletePolicy"
  | "adminUpdateChatRoom"
  | "adminArchiveChatRoom"
  | "adminDeleteMessage";

export async function callAdmin<T = unknown>(name: CallableName, data: Record<string, unknown>): Promise<T> {
  if (!functions) {
    throw new Error("Firebase Functions are not configured for this environment.");
  }
  const callable = httpsCallable<Record<string, unknown>, T>(functions, name);
  const result = await callable(data);
  return result.data;
}
