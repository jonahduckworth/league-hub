const test = require("node:test");
const assert = require("node:assert/strict");

const { canReceiveAnnouncementNotification } = require("../lib/notifications/announcementLogic");

const staff = {
  role: "staff",
  leagueIds: ["league-a"],
  hubIds: ["hub-a"],
  teamIds: ["team-a"],
};

test("announcement notifications follow league, hub, and team membership", () => {
  assert.equal(canReceiveAnnouncementNotification(staff, {
    scope: "league", leagueId: "league-a", hubId: null, teamId: null,
  }), true);
  assert.equal(canReceiveAnnouncementNotification(staff, {
    scope: "hub", leagueId: "league-a", hubId: "hub-a", teamId: null,
  }), true);
  assert.equal(canReceiveAnnouncementNotification(staff, {
    scope: "team", leagueId: "league-a", hubId: "hub-a", teamId: "team-a",
  }), true);
  assert.equal(canReceiveAnnouncementNotification(staff, {
    scope: "league", leagueId: "league-b", hubId: null, teamId: null,
  }), false);
  assert.equal(canReceiveAnnouncementNotification(staff, {
    scope: "hub", leagueId: "league-a", hubId: "hub-b", teamId: null,
  }), false);
  assert.equal(canReceiveAnnouncementNotification(staff, {
    scope: "team", leagueId: "league-a", hubId: "hub-b", teamId: "team-b",
  }), false);
});

test("hub managers receive team announcements in their hub", () => {
  assert.equal(canReceiveAnnouncementNotification({
    role: "managerAdmin", leagueIds: ["league-a"], hubIds: ["hub-a"], teamIds: [],
  }, {
    scope: "team", leagueId: "league-a", hubId: "hub-a", teamId: "team-a",
  }), true);
});

test("elevated admins receive valid scoped announcements but obsolete scopes notify nobody", () => {
  const owner = { role: "platformOwner" };
  assert.equal(canReceiveAnnouncementNotification(owner, {
    scope: "league", leagueId: "league-a", hubId: null, teamId: null,
  }), true);
  assert.equal(canReceiveAnnouncementNotification(owner, {
    scope: "orgWide", leagueId: null, hubId: null, teamId: null,
  }), false);
});
