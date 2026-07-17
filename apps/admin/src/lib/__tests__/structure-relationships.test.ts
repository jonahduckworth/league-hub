import { describe, expect, it } from "vitest";
import { demoData } from "../demo-data";
import { buildStructureRelationshipIndex } from "../structure-relationships";

describe("buildStructureRelationshipIndex", () => {
  it("connects people through both user assignments and team roster membership without duplicates", () => {
    const relationships = buildStructureRelationshipIndex(demoData);

    expect(relationships.peopleForTeam("team-u11-aa").map((person) => person.displayName)).toEqual([
      "Avery Admin",
      "Morgan Manager"
    ]);
    expect(relationships.peopleForHub("hub-calgary").map((person) => person.displayName)).toEqual([
      "Avery Admin",
      "Morgan Manager"
    ]);
    expect(relationships.peopleForLeague("league-winter").map((person) => person.displayName)).toEqual([
      "Avery Admin",
      "Morgan Manager",
      "Sam Staff"
    ]);
    expect(relationships.directPeopleForHub("hub-calgary").map((person) => person.displayName)).toEqual([
      "Avery Admin",
      "Morgan Manager"
    ]);
    expect(relationships.directPeopleForLeague("league-winter").map((person) => person.displayName)).toEqual([
      "Avery Admin",
      "Morgan Manager",
      "Sam Staff"
    ]);
  });

  it("includes direct hub assignments even when a person is not on a team roster", () => {
    const relationships = buildStructureRelationshipIndex({
      ...demoData,
      users: [
        ...demoData.users,
        {
          id: "hub-only-user",
          email: "hub-only@prairie.example",
          displayName: "Harper Hub",
          role: "staff",
          orgId: "org-demo",
          hubIds: ["hub-calgary"],
          leagueIds: [],
          teamIds: [],
          isActive: true
        }
      ]
    });

    expect(relationships.peopleForHub("hub-calgary").map((person) => person.displayName)).toContain("Harper Hub");
    expect(relationships.directPeopleForHub("hub-calgary").map((person) => person.displayName)).toContain("Harper Hub");
    expect(relationships.peopleForLeague("league-winter").map((person) => person.displayName)).toContain("Harper Hub");
    expect(relationships.directPeopleForLeague("league-winter").map((person) => person.displayName)).not.toContain("Harper Hub");
  });
});
