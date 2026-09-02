/**
 * Cloud Functions for League Hub – Push Notifications
 *
 * Triggers on Firestore writes and sends FCM notifications to relevant users.
 * Each user stores their FCM tokens in /users/{uid}/fcmTokens.
 */

export { onAnnouncementCreated } from "./notifications/announcements";
export {
  onMessageCreated,
  onMessagePreviewCreated,
} from "./notifications/messages";
export { onPolicyCreated } from "./notifications/policies";
export { onTeamUpdated } from "./notifications/teams";
export {
  onInvitationCreated,
  onInvitationEmailCreated,
  onUserCreatedFromInvitation,
} from "./notifications/invitations";
export { onUserRoleChanged } from "./notifications/roleChanges";
export {
  adminGetOverview,
  adminCreateInvitation,
  adminExpireInvitation,
  adminUpdateUserAccess,
  adminUpsertLeague,
  adminDeleteLeague,
  adminUpsertHub,
  adminDeleteHub,
  adminUpsertTeam,
  adminDeleteTeam,
  adminCreateAnnouncement,
  adminUpdateAnnouncement,
  adminDeleteAnnouncement,
  adminCreatePolicy,
  adminFinalizePolicyUpload,
  adminUpdatePolicy,
  adminAddPolicyVersion,
  adminDeletePolicy,
  adminPreviewChatRoomSetup,
  adminProvisionChatRooms,
  adminUpdateChatRoom,
  adminArchiveChatRoom,
  adminDeleteMessage,
  adminSyncSchedule,
  adminUpdateScheduleIntegration,
} from "./admin";
export { syncRampSchedules } from "./schedule/rampSync";
export { syncRefBuddySchedules } from "./schedule/refBuddySync";
export { submitLandingContact } from "./landingContact";
export { deleteOwnAccount } from "./accountDeletion";
export { onMessageReportCreated } from "./messageReports";
export { createMultiTeamEventRoom } from "./multiTeamEventRooms";
export {
  onHubStructureWritten,
  onStructureChatRoomCreated,
  onTeamStructureWritten,
} from "./structureChatRooms";
